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
                caption: DaycoText.language == .english ? "Since \(formattedDate(startOfTarget))" : "\(formattedDate(startOfTarget))부터",
                targetDate: startOfTarget,
                dayDelta: elapsedDays
            )
        case .countDown:
            return DDayCalculation(
                valueText: rawDayDelta == 0 ? "D-Day" : "D-\(max(rawDayDelta, 0))",
                caption: DaycoText.language == .english ? "Until \(formattedDate(startOfTarget))" : "\(formattedDate(startOfTarget))까지",
                targetDate: startOfTarget,
                dayDelta: rawDayDelta
            )
        case .recurring:
            return DDayCalculation(
                valueText: rawDayDelta == 0 ? DaycoText.t("오늘") : "D-\(rawDayDelta)",
                caption: DaycoText.language == .english ? "Next \(item.repeatRule?.title ?? DaycoText.t("반복"))" : "다음 \(item.repeatRule?.title ?? DaycoText.t("반복"))",
                targetDate: startOfTarget,
                dayDelta: rawDayDelta
            )
        case .milestone:
            let milestoneDay = item.milestoneDayValue
            return DDayCalculation(
                valueText: milestoneValueText(for: rawDayDelta),
                caption: DaycoText.language == .english ? "\(MilestoneDay.title(for: milestoneDay)) Anniversary" : "\(MilestoneDay.title(for: milestoneDay)) 기념일",
                targetDate: startOfTarget,
                dayDelta: rawDayDelta
            )
        }
    }

    func resolvedTargetDate(for item: DDayItem, now: Date = .now) -> Date {
        if item.type == .milestone {
            return milestoneDate(from: item.date, milestoneDay: item.milestoneDayValue, countStartAsDayOne: item.countStartAsDayOne)
        }

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

    func milestoneDate(from date: Date, milestoneDay: Int, countStartAsDayOne: Bool) -> Date {
        let startDate = calendar.startOfDay(for: date)
        let offset = max(milestoneDay, 1) - (countStartAsDayOne ? 1 : 0)
        return calendar.date(byAdding: .day, value: max(offset, 0), to: startDate) ?? startDate
    }

    private func milestoneValueText(for rawDayDelta: Int) -> String {
        if rawDayDelta == 0 {
            return DaycoText.t("오늘")
        }

        if rawDayDelta < 0 {
            return "D+\((-rawDayDelta).formatted())"
        }

        return "D-\(rawDayDelta.formatted())"
    }

    private func format(_ days: Int, unit: DisplayUnit, suffix: String, from start: Date, to end: Date) -> String {
        switch unit {
        case .days:
            return DaycoText.language == .english ? "\(days.formatted()) days" : "\(days.formatted())일\(suffix)"
        case .hours:
            return DaycoText.language == .english ? "\((days * 24).formatted()) hours" : "\((days * 24).formatted())시간\(suffix)"
        case .minutes:
            return DaycoText.language == .english ? "\((days * 24 * 60).formatted()) minutes" : "\((days * 24 * 60).formatted())분\(suffix)"
        case .daysAndHours:
            return DaycoText.language == .english ? "\(days.formatted()) days 0 hours" : "\(days.formatted())일 0시간\(suffix)"
        case .yearsMonthsDays:
            let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
            if DaycoText.language == .english {
                return "\(components.year ?? 0)y \(components.month ?? 0)m \(components.day ?? 0)d"
            }
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
        date.formatted(.dateTime.locale(Locale(identifier: DaycoText.language.localeIdentifier)).year().month(.twoDigits).day(.twoDigits))
    }
}
