import Foundation

enum DaycoWidgetConstants {
    static let appGroupIdentifier = "group.com.seunghwabaek.dayco"
    static let snapshotKey = "dayco.widget.snapshots"
    static let languageKey = "appLanguage"
    static let kind = "DaycoWidget"
}

enum DaycoWidgetLanguage: String, Codable {
    case korean = "ko"
    case english = "en"

    var localeIdentifier: String {
        switch self {
        case .korean: "ko_KR"
        case .english: "en_US"
        }
    }

    func text(_ korean: String, _ english: String) -> String {
        self == .english ? english : korean
    }

    func day(_ value: Int) -> String {
        self == .english ? "\(max(value, 1).formatted()) days" : "\(max(value, 1).formatted())일"
    }
}

struct DaycoWidgetSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var date: Date
    var typeRawValue: String
    var repeatRuleRawValue: String?
    var milestoneDayRawValue: Int?
    var countStartAsDayOne: Bool
    var displayUnitRawValue: String
    var isPinned: Bool
    var isShared: Bool
    var cardColorRawValue: String?
    var sortIndex: Double?
    var listRank: Int?
    var updatedAt: Date
}

struct DaycoWidgetCalculation: Hashable {
    var valueText: String
    var caption: String
    var dayDelta: Int
}

struct DaycoWidgetCalculator {
    var calendar: Calendar = .current
    var language: DaycoWidgetLanguage = .korean

    func calculate(snapshot: DaycoWidgetSnapshot, now: Date = .now) -> DaycoWidgetCalculation {
        let startOfNow = calendar.startOfDay(for: now)
        let targetDate = resolvedTargetDate(for: snapshot, now: startOfNow)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let rawDayDelta = calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0

        switch snapshot.typeRawValue {
        case "countUp":
            let elapsedDays = -rawDayDelta + (snapshot.countStartAsDayOne ? 1 : 0)
            return DaycoWidgetCalculation(
                valueText: format(abs(elapsedDays), unitRawValue: snapshot.displayUnitRawValue, suffix: language.text("째", ""), from: startOfTarget, to: startOfNow),
                caption: language.text("\(formattedDate(startOfTarget))부터", "Since \(formattedDate(startOfTarget))"),
                dayDelta: elapsedDays
            )
        case "recurring":
            return DaycoWidgetCalculation(
                valueText: rawDayDelta == 0 ? language.text("오늘", "Today") : "D-\(rawDayDelta)",
                caption: language.text("다음 \(repeatRuleTitle(snapshot.repeatRuleRawValue))", "Next \(repeatRuleTitle(snapshot.repeatRuleRawValue))"),
                dayDelta: rawDayDelta
            )
        case "milestone":
            let milestoneDay = max(snapshot.milestoneDayRawValue ?? 100, 1)
            return DaycoWidgetCalculation(
                valueText: milestoneValueText(for: rawDayDelta),
                caption: language.text("\(milestoneDay.formatted())일 기념일", "\(milestoneDay.formatted())-day anniversary"),
                dayDelta: rawDayDelta
            )
        default:
            return DaycoWidgetCalculation(
                valueText: rawDayDelta == 0 ? "D-Day" : "D-\(max(rawDayDelta, 0))",
                caption: language.text("\(formattedDate(startOfTarget))까지", "Until \(formattedDate(startOfTarget))"),
                dayDelta: rawDayDelta
            )
        }
    }

    private func resolvedTargetDate(for snapshot: DaycoWidgetSnapshot, now: Date) -> Date {
        if snapshot.typeRawValue == "milestone" {
            return milestoneDate(from: snapshot.date, milestoneDay: max(snapshot.milestoneDayRawValue ?? 100, 1), countStartAsDayOne: snapshot.countStartAsDayOne)
        }

        guard snapshot.typeRawValue == "recurring" else {
            return snapshot.date
        }

        if snapshot.repeatRuleRawValue == "monthly" {
            return nextMonthlyDate(dayFrom: snapshot.date, now: now)
        }
        return nextYearlyDate(monthAndDayFrom: snapshot.date, now: now)
    }

    private func milestoneDate(from date: Date, milestoneDay: Int, countStartAsDayOne: Bool) -> Date {
        let startDate = calendar.startOfDay(for: date)
        let offset = max(milestoneDay, 1) - (countStartAsDayOne ? 1 : 0)
        return calendar.date(byAdding: .day, value: max(offset, 0), to: startDate) ?? startDate
    }

    private func milestoneValueText(for rawDayDelta: Int) -> String {
        if rawDayDelta == 0 {
            return language.text("오늘", "Today")
        }

        if rawDayDelta < 0 {
            return "D+\((-rawDayDelta).formatted())"
        }

        return "D-\(rawDayDelta.formatted())"
    }

    private func format(_ days: Int, unitRawValue: String, suffix: String, from start: Date, to end: Date) -> String {
        switch unitRawValue {
        case "hours":
            return language.text("\((days * 24).formatted())시간\(suffix)", "\((days * 24).formatted()) hours")
        case "minutes":
            return language.text("\((days * 24 * 60).formatted())분\(suffix)", "\((days * 24 * 60).formatted()) minutes")
        case "daysAndHours":
            return language.text("\(days.formatted())일 0시간\(suffix)", "\(days.formatted()) days 0 hours")
        case "yearsMonthsDays":
            let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
            return language.text(
                "\(components.year ?? 0)년 \(components.month ?? 0)개월 \(components.day ?? 0)일\(suffix)",
                "\(components.year ?? 0)y \(components.month ?? 0)m \(components.day ?? 0)d"
            )
        default:
            return language.text("\(days.formatted())일\(suffix)", "\(days.formatted()) days")
        }
    }

    private func nextYearlyDate(monthAndDayFrom source: Date, now: Date) -> Date {
        let sourceComponents = calendar.dateComponents([.month, .day], from: source)
        let currentYear = calendar.component(.year, from: now)
        var components = DateComponents()
        components.year = currentYear
        components.month = sourceComponents.month
        components.day = sourceComponents.day

        let candidate = calendar.date(from: components) ?? source
        if calendar.startOfDay(for: candidate) >= calendar.startOfDay(for: now) {
            return candidate
        }

        components.year = currentYear + 1
        return calendar.date(from: components) ?? candidate
    }

    private func nextMonthlyDate(dayFrom source: Date, now: Date) -> Date {
        let sourceDay = calendar.component(.day, from: source)
        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        let candidate = dateClampedToMonth(year: nowComponents.year, month: nowComponents.month, day: sourceDay) ?? source

        if calendar.startOfDay(for: candidate) >= calendar.startOfDay(for: now) {
            return candidate
        }

        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        let nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        return dateClampedToMonth(year: nextComponents.year, month: nextComponents.month, day: sourceDay) ?? candidate
    }

    private func dateClampedToMonth(year: Int?, month: Int?, day: Int) -> Date? {
        guard let year, let month else { return nil }
        let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month)) ?? .now)
        return calendar.date(from: DateComponents(year: year, month: month, day: min(day, range?.count ?? day)))
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: language.localeIdentifier)))
    }

    private func repeatRuleTitle(_ rawValue: String?) -> String {
        if rawValue == "monthly" {
            return language.text("매월", "Monthly")
        }
        return language.text("매년", "Yearly")
    }
}

enum DaycoWidgetSnapshotStore {
    static func loadSnapshots() -> [DaycoWidgetSnapshot] {
        guard let data = userDefaults.data(forKey: DaycoWidgetConstants.snapshotKey),
              let snapshots = try? JSONDecoder().decode([DaycoWidgetSnapshot].self, from: data) else {
            return []
        }
        return snapshots.sortedForWidgetDisplay()
    }

    static func saveSnapshots(_ snapshots: [DaycoWidgetSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }
        userDefaults.set(data, forKey: DaycoWidgetConstants.snapshotKey)
    }

    static func loadLanguage() -> DaycoWidgetLanguage {
        DaycoWidgetLanguage(rawValue: userDefaults.string(forKey: DaycoWidgetConstants.languageKey) ?? "") ?? .korean
    }

    static func saveLanguage(_ languageRawValue: String) {
        userDefaults.set(languageRawValue, forKey: DaycoWidgetConstants.languageKey)
    }

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: DaycoWidgetConstants.appGroupIdentifier) ?? .standard
    }
}

private extension Array where Element == DaycoWidgetSnapshot {
    func sortedForWidgetDisplay() -> [DaycoWidgetSnapshot] {
        enumerated()
            .sorted { lhs, rhs in
                let leftRank = lhs.element.listRank ?? lhs.offset
                let rightRank = rhs.element.listRank ?? rhs.offset
                if leftRank != rightRank {
                    return leftRank < rightRank
                }

                if lhs.element.isPinned != rhs.element.isPinned {
                    return lhs.element.isPinned && !rhs.element.isPinned
                }

                let leftSortIndex = lhs.element.sortIndex ?? Double(lhs.offset)
                let rightSortIndex = rhs.element.sortIndex ?? Double(rhs.offset)
                if leftSortIndex != rightSortIndex {
                    return leftSortIndex < rightSortIndex
                }

                return lhs.element.updatedAt > rhs.element.updatedAt
            }
            .map(\.element)
    }
}
