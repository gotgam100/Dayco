import Foundation
import SwiftData

struct NotificationRule: Hashable, Identifiable, Codable {
    var day: Int
    var hour: Int
    var minute: Int

    var id: String { rawValue }

    var rawValue: String {
        "\(day):\(hour):\(minute)"
    }

    init(day: Int, hour: Int = 9, minute: Int = 0) {
        self.day = max(0, day)
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":")
        if parts.count == 3,
           let day = Int(parts[0]),
           let hour = Int(parts[1]),
           let minute = Int(parts[2]) {
            self.init(day: day, hour: hour, minute: minute)
            return
        }

        if parts.count == 2,
           let day = Int(parts[0]),
           let hour = Int(parts[1]) {
            self.init(day: day, hour: hour, minute: 0)
            return
        }

        if let day = Self.legacyDay(from: rawValue) {
            self.init(day: day, hour: 9)
            return
        }

        return nil
    }

    private static func legacyDay(from rawValue: String) -> Int? {
        if let value = Int(rawValue) {
            return value
        }

        switch rawValue {
        case "before100": return 100
        case "before30": return 30
        case "before7": return 7
        case "before3": return 3
        case "before1": return 1
        case "sameDay": return 0
        case "after100": return 100
        case "after200": return 200
        case "after300": return 300
        case "afterOneYear": return 365
        case "after500": return 500
        case "after1000": return 1000
        default: return nil
        }
    }
}

@Model
final class DDayItem {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date.now
    var typeRawValue: String = DDayType.countDown.rawValue
    var repeatRuleRawValue: String?
    var countStartAsDayOne: Bool = false
    var displayUnitRawValue: String = DisplayUnit.days.rawValue
    var notificationRuleRawValues: [String] = []
    var isPinned: Bool = false
    var isShared: Bool = false
    var sharePermissionRawValue: String?
    var cardColorRawValue: String?
    var sortIndex: Double?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        type: DDayType,
        repeatRule: RepeatRule? = nil,
        countStartAsDayOne: Bool = false,
        displayUnit: DisplayUnit = .days,
        notificationDays: [Int] = [],
        isPinned: Bool = false,
        isShared: Bool = false,
        sharePermission: SharePermission? = nil,
        cardColor: DDayCardColor = .typeDefault,
        sortIndex: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.typeRawValue = type.rawValue
        self.repeatRuleRawValue = repeatRule?.rawValue
        self.countStartAsDayOne = countStartAsDayOne
        self.displayUnitRawValue = displayUnit.rawValue
        self.notificationRuleRawValues = notificationDays.map(String.init)
        self.isPinned = isPinned
        self.isShared = isShared
        self.sharePermissionRawValue = sharePermission?.rawValue
        self.cardColorRawValue = cardColor == .typeDefault ? nil : cardColor.rawValue
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension DDayItem {
    var type: DDayType {
        get { DDayType(rawValue: typeRawValue) ?? .countDown }
        set { typeRawValue = newValue.rawValue }
    }

    var repeatRule: RepeatRule? {
        get {
            guard let repeatRuleRawValue else { return nil }
            return RepeatRule(rawValue: repeatRuleRawValue)
        }
        set { repeatRuleRawValue = newValue?.rawValue }
    }

    var displayUnit: DisplayUnit {
        get { DisplayUnit(rawValue: displayUnitRawValue) ?? .days }
        set { displayUnitRawValue = newValue.rawValue }
    }

    var notificationDays: [Int] {
        get {
            notificationRules.map(\.day).uniqued().sorted()
        }
        set {
            notificationRules = newValue.map { NotificationRule(day: $0) }
        }
    }

    var notificationRules: [NotificationRule] {
        get {
            notificationRuleRawValues
                .compactMap(NotificationRule.init(rawValue:))
                .uniqued()
                .sorted {
                    if $0.day != $1.day {
                        return $0.day < $1.day
                    }
                    if $0.hour != $1.hour {
                        return $0.hour < $1.hour
                    }
                    return $0.minute < $1.minute
                }
        }
        set {
            notificationRuleRawValues = newValue
                .uniqued()
                .sorted {
                    if $0.day != $1.day {
                        return $0.day < $1.day
                    }
                    if $0.hour != $1.hour {
                        return $0.hour < $1.hour
                    }
                    return $0.minute < $1.minute
                }
                .map(\.rawValue)
        }
    }

    var sharePermission: SharePermission? {
        get {
            guard let sharePermissionRawValue else { return nil }
            return SharePermission(rawValue: sharePermissionRawValue)
        }
        set { sharePermissionRawValue = newValue?.rawValue }
    }

    var cardColor: DDayCardColor {
        get {
            guard let cardColorRawValue else { return .typeDefault }
            return DDayCardColor(rawValue: cardColorRawValue) ?? .typeDefault
        }
        set {
            cardColorRawValue = newValue == .typeDefault ? nil : newValue.rawValue
        }
    }

    func notificationTitle(for day: Int) -> String {
        notificationTitle(for: NotificationRule(day: day))
    }

    func notificationTitle(for rule: NotificationRule) -> String {
        let timeText = rule.minute == 0 ? "\(rule.hour)시" : "\(rule.hour)시 \(rule.minute)분"
        switch type {
        case .countUp:
            return "\(rule.day)일째 \(timeText)"
        case .countDown, .recurring:
            return rule.day == 0 ? "당일 \(timeText)" : "\(rule.day)일 전 \(timeText)"
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
