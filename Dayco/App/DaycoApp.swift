import Foundation
import SwiftData
import SwiftUI

@main
struct DaycoApp: App {
    @UIApplicationDelegateAdaptor(DaycoCloudShareAcceptor.self) private var cloudShareAcceptor
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.system.rawValue
    @AppStorage("appLanguage") private var appLanguageRawValue = DaycoLanguage.korean.rawValue

    var sharedModelContainer: ModelContainer = {
        if let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        }

        let schema = Schema([
            DDayItem.self,
        ])
        let isICloudBackupEnabled = UserDefaults.standard.bool(forKey: "isICloudBackupEnabled")
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: isICloudBackupEnabled ? .private("iCloud.com.seunghwabaek.dayco") : .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            DDayListView()
                .preferredColorScheme(appAppearance.colorScheme)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        }
        .modelContainer(sharedModelContainer)
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .system
    }

    private var appLanguage: DaycoLanguage {
        DaycoLanguage(rawValue: appLanguageRawValue) ?? .korean
    }
}
