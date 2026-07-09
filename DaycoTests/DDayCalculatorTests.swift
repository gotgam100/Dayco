import Testing
import Foundation
@testable import Dayco

@Suite("DDayCalculator")
struct DDayCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func countUpCanIncludeStartDateAsDayOne() {
        let item = DDayItem(
            title: "시작",
            date: date(2026, 7, 4),
            type: .countUp,
            countStartAsDayOne: true
        )
        let result = DDayCalculator(calendar: calendar).calculate(item: item, now: date(2026, 7, 4))

        #expect(result.valueText == "1일째")
        #expect(result.dayDelta == 1)
    }

    @Test func countDownShowsRemainingDays() {
        let item = DDayItem(title: "시험", date: date(2026, 7, 22), type: .countDown)
        let result = DDayCalculator(calendar: calendar).calculate(item: item, now: date(2026, 7, 4))

        #expect(result.valueText == "D-18")
        #expect(result.dayDelta == 18)
    }

    @Test func yearlyRecurringUsesNextOccurrence() {
        let item = DDayItem(
            title: "생일",
            date: date(2020, 6, 1),
            type: .recurring,
            repeatRule: .yearly
        )
        let result = DDayCalculator(calendar: calendar).calculate(item: item, now: date(2026, 7, 4))

        #expect(result.targetDate == date(2027, 6, 1))
    }

    @Test func monthlyRecurringClampsOverflowDay() {
        let item = DDayItem(
            title: "정산",
            date: date(2026, 1, 31),
            type: .recurring,
            repeatRule: .monthly
        )
        let result = DDayCalculator(calendar: calendar).calculate(item: item, now: date(2026, 2, 1))

        #expect(result.targetDate == date(2026, 2, 28))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
