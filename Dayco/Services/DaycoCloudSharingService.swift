import CloudKit
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct DaycoSharePayload: Sendable {
    let id: UUID
    let title: String
    let date: Date
    let typeRawValue: String
    let repeatRuleRawValue: String?
    let milestoneDayRawValue: Int?
    let countStartAsDayOne: Bool
    let displayUnitRawValue: String
    let notificationRuleRawValues: [String]
    let cardColorRawValue: String?
    let updatedAt: Date

    init(item: DDayItem) {
        id = item.id
        title = item.title
        date = item.date
        typeRawValue = item.typeRawValue
        repeatRuleRawValue = item.repeatRuleRawValue
        milestoneDayRawValue = item.milestoneDayRawValue
        countStartAsDayOne = item.countStartAsDayOne
        displayUnitRawValue = item.displayUnitRawValue
        notificationRuleRawValues = item.notificationRuleRawValues
        cardColorRawValue = item.cardColorRawValue
        updatedAt = item.updatedAt
    }

    var shareMessage: String {
        if DaycoText.language == .english {
            return "I shared \"\(title)\" with you on Dayco. Open this invitation in the Dayco app."
        }
        return "Dayco에서 \"\(title)\" 디데이를 공유했어요. Dayco 앱에서 초대를 열어 확인해 주세요."
    }
}

struct PreparedDaycoCloudShare: Identifiable {
    let id = UUID()
    let payload: DaycoSharePayload
    let share: CKShare
    let container: CKContainer

    var inviteText: String {
        [payload.shareMessage, share.url?.absoluteString]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

private final class CloudSharePreparationCompletion: @unchecked Sendable {
    private let completion: (CKShare?, CKContainer?, Error?) -> Void

    init(_ completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        self.completion = completion
    }

    func finish(share: CKShare?, container: CKContainer?, error: Error?) {
        completion(share, container, error)
    }
}

enum DaycoCloudSharingService {
    static let containerIdentifier = "iCloud.com.seunghwabaek.dayco"
    static let recordType = "SharedDDay"

    static var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    static func prepareShare(
        payload: DaycoSharePayload,
        permission: SharePermission,
        completion: @escaping @Sendable (CKShare?, CKContainer?, Error?) -> Void
    ) {
        let completionBox = CloudSharePreparationCompletion(completion)
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: payload.id.uuidString)

        database.fetch(withRecordID: recordID) { record, error in
            if let ckError = error as? CKError, ckError.code != .unknownItem {
                completionBox.finish(share: nil, container: nil, error: error)
                return
            }

            let rootRecord = record ?? CKRecord(recordType: recordType, recordID: recordID)
            apply(payload, to: rootRecord)

            let share = CKShare(rootRecord: rootRecord)
            share[CKShare.SystemFieldKey.title] = payload.title as CKRecordValue
            share.publicPermission = permission == .editable ? .readWrite : .readOnly

            let operation = CKModifyRecordsOperation(recordsToSave: [rootRecord, share])
            operation.savePolicy = .changedKeys
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    completionBox.finish(share: share, container: container, error: nil)
                case .failure(let error):
                    completionBox.finish(share: nil, container: nil, error: error)
                }
            }
            database.add(operation)
        }
    }

    private static func apply(_ payload: DaycoSharePayload, to record: CKRecord) {
        record["daycoID"] = payload.id.uuidString as CKRecordValue
        record["title"] = payload.title as CKRecordValue
        record["date"] = payload.date as CKRecordValue
        record["typeRawValue"] = payload.typeRawValue as CKRecordValue
        record["repeatRuleRawValue"] = payload.repeatRuleRawValue as CKRecordValue?
        record["milestoneDayRawValue"] = payload.milestoneDayRawValue as CKRecordValue?
        record["countStartAsDayOne"] = payload.countStartAsDayOne ? 1 as CKRecordValue : 0 as CKRecordValue
        record["displayUnitRawValue"] = payload.displayUnitRawValue as CKRecordValue
        record["notificationRuleRawValues"] = payload.notificationRuleRawValues as CKRecordValue
        record["cardColorRawValue"] = payload.cardColorRawValue as CKRecordValue?
        record["updatedAt"] = payload.updatedAt as CKRecordValue
    }

    @MainActor
    static func importSharedDDays(into modelContext: ModelContext) async {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            let response = try await container.sharedCloudDatabase.records(matching: query)
            let records = response.matchResults.compactMap { _, result in
                try? result.get()
            }
            guard !records.isEmpty else { return }

            let existingItems = (try? modelContext.fetch(FetchDescriptor<DDayItem>())) ?? []

            for record in records {
                guard let importedItem = item(from: record) else { continue }

                if let existingItem = existingItems.first(where: { $0.id == importedItem.id }) {
                    applySharedValues(from: importedItem, to: existingItem)
                } else {
                    modelContext.insert(importedItem)
                }
            }

            try? modelContext.save()
        } catch {
            print("Failed to import shared Dayco records: \(error)")
        }
    }

    private static func item(from record: CKRecord) -> DDayItem? {
        guard
            let idText = record["daycoID"] as? String,
            let id = UUID(uuidString: idText),
            let title = record["title"] as? String,
            let date = record["date"] as? Date,
            let typeRawValue = record["typeRawValue"] as? String,
            let type = DDayType(rawValue: typeRawValue)
        else {
            return nil
        }

        let repeatRule = (record["repeatRuleRawValue"] as? String).flatMap(RepeatRule.init(rawValue:))
        let milestoneDayRawValue = record["milestoneDayRawValue"] as? Int
        let displayUnit = (record["displayUnitRawValue"] as? String).flatMap(DisplayUnit.init(rawValue:)) ?? .days
        let notificationRules = record["notificationRuleRawValues"] as? [String] ?? []
        let cardColor = (record["cardColorRawValue"] as? String).flatMap(DDayCardColor.init(rawValue:)) ?? .typeDefault
        let countStartAsDayOne = ((record["countStartAsDayOne"] as? Int) ?? 0) == 1
        let updatedAt = (record["updatedAt"] as? Date) ?? .now

        let item = DDayItem(
            id: id,
            title: title,
            date: date,
            type: type,
            repeatRule: repeatRule,
            customMilestoneDay: milestoneDayRawValue,
            countStartAsDayOne: countStartAsDayOne,
            displayUnit: displayUnit,
            notificationDays: [],
            isPinned: false,
            isShared: true,
            sharePermission: .readOnly,
            cardColor: cardColor,
            updatedAt: updatedAt
        )
        item.notificationRuleRawValues = notificationRules
        return item
    }

    private static func applySharedValues(from source: DDayItem, to destination: DDayItem) {
        guard source.updatedAt >= destination.updatedAt else { return }

        destination.title = source.title
        destination.date = source.date
        destination.typeRawValue = source.typeRawValue
        destination.repeatRuleRawValue = source.repeatRuleRawValue
        destination.milestoneDayRawValue = source.milestoneDayRawValue
        destination.countStartAsDayOne = source.countStartAsDayOne
        destination.displayUnitRawValue = source.displayUnitRawValue
        destination.notificationRuleRawValues = source.notificationRuleRawValues
        destination.isShared = true
        destination.sharePermission = source.sharePermission
        destination.cardColorRawValue = source.cardColorRawValue
        destination.updatedAt = source.updatedAt
    }
}

struct DaycoCloudSharingView: UIViewControllerRepresentable {
    let preparedShare: PreparedDaycoCloudShare
    let onSave: () -> Void
    let onStopSharing: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [preparedShare.inviteText],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, error in
            if let error {
                onError(error)
            } else if completed {
                onSave()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        let parent: DaycoCloudSharingView

        init(parent: DaycoCloudSharingView) {
            self.parent = parent
        }
    }
}

enum DaycoCloudSharingError: LocalizedError {
    case missingShare
    case missingShareURL

    var errorDescription: String? {
        switch self {
        case .missingShare:
            DaycoText.t("iCloud 공유 정보를 준비하지 못했습니다.")
        case .missingShareURL:
            DaycoText.t("iCloud 공유 링크를 준비하지 못했습니다.")
        }
    }
}

final class DaycoCloudShareAcceptor: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        DaycoCloudSharingService.container.accept(cloudKitShareMetadata) { _, error in
            if let error {
                print("Failed to accept Dayco CloudKit share: \(error)")
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
