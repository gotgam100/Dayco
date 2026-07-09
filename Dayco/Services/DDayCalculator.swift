import Foundation

struct DDayCalculation: Equatable {
    var valueText: String
    var caption: String
    var targetDate: Date
    var dayDelta: Int
}

struct DDayCalculator {
    var calendar: Calendar = .current

    func calculate(item: DDayItem, now: Date = .now) -> DDayCalculation {
        let startOfNow = calendar.startOfDay(for: now)
        let targetDate = resolvedTargetDate(for: item, now: startOfNow)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let rawDayDelta = calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0

        switch item.type {
        case .countUp:
            let elapsedDays = -rawDayDelta + (item.countStartAsDayOne ? 1 : 0)
            return DDayCalculation(
                valueText: format(abs(elapsedDays), unit: item.displayUnit, suffix: "째", from: startOfTarget, to: startOfNow),
                caption: "\(formattedDate(startOfTarget))부터",
                targetDate: startOfTarget,
                dayDelta: elapsedDays
            )
        case .countDown:
            return DDayCalculation(
                valueText: rawDayDelta == 0 ? "D-Day" : "D-\(max(rawDayDelta, 0))",
                caption: "\(formattedDate(startOfTarget))까지",
                targetDate: startOfTarget,
                dayDelta: rawDayDelta
            )
        case .recurring:
            return DDayCalculation(
                valueText: rawDayDelta == 0 ? "오늘" : "D-\(rawDayDelta)",
                caption: "다음 \(item.repeatRule?.title ?? "반복")",
                targetDate: startOfTarget,
                dayDelta: rawDayDelta
            )
        }
    }

    func resolvedTargetDate(for item: DDayItem, now: Date = .now) -> Date {
        guard item.type == .recurring else {
            return item.date
        }

        switch item.repeatRule ?? .yearly {
        case .yearly:
            return nextYearlyDate(monthAndDayFrom: item.date, now: now)
        case .monthly:
            return nextMonthlyDate(dayFrom: item.date, now: now)
        }
    }

    private func format(_ days: Int, unit: DisplayUnit, suffix: String, from start: Date, to end: Date) -> String {
        switch unit {
        case .days:
            return "\(days.formatted())일\(suffix)"
        case .hours:
            return "\((days * 24).formatted())시간\(suffix)"
        case .minutes:
            return "\((days * 24 * 60).formatted())분\(suffix)"
        case .daysAndHours:
            return "\(days.formatted())일 0시간\(suffix)"
        case .yearsMonthsDays:
            let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
            return "\(components.year ?? 0)년 \(components.month ?? 0)개월 \(components.day ?? 0)일\(suffix)"
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
}
