import Foundation
import UserNotifications

struct NotificationScheduler {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func rescheduleNotifications(for item: DDayItem) async {
        let identifiers = item.notificationRules.map { "\(item.id.uuidString)-rule-\($0.rawValue)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

        for rule in item.notificationRules {
            guard let triggerDate = triggerDate(for: rule, item: item) else { continue }
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.notificationTitle(for: rule)
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(item.id.uuidString)-rule-\(rule.rawValue)", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

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
        }

        guard let date = calendar.date(byAdding: .day, value: offset, to: baseDate) else { return nil }
        return calendar.date(bySettingHour: rule.hour, minute: rule.minute, second: 0, of: date)
    }
}
