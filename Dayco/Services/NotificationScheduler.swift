import Foundation
import UserNotifications

struct NotificationScheduler {
    @MainActor
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    @MainActor
    func rescheduleNotifications(for item: DDayItem) async {
        await removePendingNotifications(for: item)

        guard !item.notificationRules.isEmpty else { return }
        let isAuthorized = (try? await requestAuthorization()) ?? false
        guard isAuthorized else { return }

        for rule in item.notificationRules {
            guard let triggerDate = triggerDate(for: rule, item: item) else { continue }
            guard triggerDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.notificationTitle(for: rule)
            content.sound = .default
            content.userInfo = [
                "daycoItemID": item.id.uuidString,
                "daycoNotificationRule": rule.rawValue
            ]

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: Self.notificationIdentifier(for: item, rule: rule), content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    @MainActor
    func removePendingNotifications(for item: DDayItem) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(item.id.uuidString)-rule-"
        let pendingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
    }

    @MainActor
    func removeNotifications(for item: DDayItem) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(item.id.uuidString)-rule-"
        let pendingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        let deliveredIdentifiers = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix(prefix) }

        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
    }

    @MainActor
    func removeDeliveredDaycoNotifications(for items: [DDayItem]) async {
        let validIdentifiers = Set(items.flatMap { item in
            item.notificationRules.map { rule in
                Self.notificationIdentifier(for: item, rule: rule)
            }
        })
        let deliveredIdentifiers = await UNUserNotificationCenter.current().deliveredNotifications()
            .map(\.request.identifier)
            .filter { validIdentifiers.contains($0) }

        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
    }

    static func notificationIdentifier(for item: DDayItem, rule: NotificationRule) -> String {
        "\(item.id.uuidString)-rule-\(rule.rawValue)"
    }

    @MainActor
    private func triggerDate(for rule: NotificationRule, item: DDayItem) -> Date? {
        let calendar = Calendar.current
        let baseDate: Date
        let offset: Int

        switch item.type {
        case .countUp:
            baseDate = calendar.startOfDay(for: item.date)
            offset = max(rule.day - (item.countStartAsDayOne ? 1 : 0), 0)
        case .countDown:
            baseDate = calendar.startOfDay(for: item.date)
            offset = -rule.day
        case .recurring:
            baseDate = calendar.startOfDay(for: DDayCalculator(calendar: calendar).resolvedTargetDate(for: item))
            offset = -rule.day
        case .milestone:
            baseDate = calendar.startOfDay(for: DDayCalculator(calendar: calendar).resolvedTargetDate(for: item))
            offset = -rule.day
        }

        guard let date = calendar.date(byAdding: .day, value: offset, to: baseDate) else { return nil }
        return calendar.date(bySettingHour: rule.hour, minute: rule.minute, second: 0, of: date)
    }
}
