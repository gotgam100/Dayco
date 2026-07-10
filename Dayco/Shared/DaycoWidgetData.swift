import Foundation

enum DaycoWidgetConstants {
    static let appGroupIdentifier = "group.com.seunghwabaek.dayco"
    static let snapshotKey = "dayco.widget.snapshots"
    static let kind = "DaycoWidget"
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

    func calculate(snapshot: DaycoWidgetSnapshot, now: Date = .now) -> DaycoWidgetCalculation {
        let startOfNow = calendar.startOfDay(for: now)
        let targetDate = resolvedTargetDate(for: snapshot, now: startOfNow)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let rawDayDelta = calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0

        switch snapshot.typeRawValue {
        case "countUp":
            let elapsedDays = -rawDayDelta + (snapshot.countStartAsDayOne ? 1 : 0)
            return DaycoWidgetCalculation(
                valueText: format(abs(elapsedDays), unitRawValue: snapshot.displayUnitRawValue, suffix: "째", from: startOfTarget, to: startOfNow),
                caption: "\(formattedDate(startOfTarget))부터",
                dayDelta: elapsedDays
            )
        case "recurring":
            return DaycoWidgetCalculation(
                valueText: rawDayDelta == 0 ? "오늘" : "D-\(rawDayDelta)",
                caption: "다음 \(repeatRuleTitle(snapshot.repeatRuleRawValue))",
                dayDelta: rawDayDelta
            )
        case "milestone":
            let milestoneDay = max(snapshot.milestoneDayRawValue ?? 100, 1)
            return DaycoWidgetCalculation(
                valueText: milestoneValueText(for: rawDayDelta),
                caption: "\(milestoneDay.formatted())일 기념일",
                dayDelta: rawDayDelta
            )
        default:
            return DaycoWidgetCalculation(
                valueText: rawDayDelta == 0 ? "D-Day" : "D-\(max(rawDayDelta, 0))",
                caption: "\(formattedDate(startOfTarget))까지",
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
            return "오늘"
        }

        if rawDayDelta < 0 {
            return "D+\((-rawDayDelta).formatted())"
        }

        return "D-\(rawDayDelta.formatted())"
    }

    private func format(_ days: Int, unitRawValue: String, suffix: String, from start: Date, to end: Date) -> String {
        switch unitRawValue {
        case "hours":
            return "\((days * 24).formatted())시간\(suffix)"
        case "minutes":
            return "\((days * 24 * 60).formatted())분\(suffix)"
        case "daysAndHours":
            return "\(days.formatted())일 0시간\(suffix)"
        case "yearsMonthsDays":
            let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
            return "\(components.year ?? 0)년 \(components.month ?? 0)개월 \(components.day ?? 0)일\(suffix)"
        default:
            return "\(days.formatted())일\(suffix)"
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
        date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }

    private func repeatRuleTitle(_ rawValue: String?) -> String {
        rawValue == "monthly" ? "매월" : "매년"
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
