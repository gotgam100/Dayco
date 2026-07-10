import Foundation

enum DDayType: String, CaseIterable, Identifiable, Codable {
    case countUp
    case countDown
    case recurring
    case milestone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countUp: DaycoText.t("지난 날짜")
        case .countDown: DaycoText.t("남은 날짜")
        case .recurring: DaycoText.t("반복 기념일")
        case .milestone: DaycoText.t("기념일")
        }
    }

    var symbolName: String {
        switch self {
        case .countUp: "plus.forwardslash.minus"
        case .countDown: "calendar.badge.clock"
        case .recurring: "arrow.trianglehead.2.clockwise"
        case .milestone: "party.popper"
        }
    }
}

enum MilestoneDay: Int, CaseIterable, Identifiable, Codable {
    case day100 = 100
    case day200 = 200
    case day300 = 300
    case day400 = 400
    case day500 = 500
    case day600 = 600
    case day700 = 700
    case day800 = 800
    case day900 = 900
    case day1000 = 1000
    case day2000 = 2000
    case day3000 = 3000
    case day4000 = 4000
    case day5000 = 5000
    case day6000 = 6000
    case day7000 = 7000
    case day8000 = 8000
    case day9000 = 9000
    case day10000 = 10000

    var id: Int { rawValue }

    var title: String {
        DaycoText.day(rawValue)
    }

    static func title(for day: Int) -> String {
        DaycoText.day(day)
    }
}

enum DisplayUnit: String, CaseIterable, Identifiable, Codable {
    case days
    case hours
    case minutes
    case daysAndHours
    case yearsMonthsDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days: DaycoText.t("일")
        case .hours: DaycoText.t("시간")
        case .minutes: DaycoText.t("분")
        case .daysAndHours: DaycoText.t("일 + 시간")
        case .yearsMonthsDays: DaycoText.t("년 + 개월 + 일")
        }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable, Codable {
    case yearly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearly: DaycoText.t("매년")
        case .monthly: DaycoText.t("매월")
        }
    }
}

enum SharePermission: String, CaseIterable, Identifiable, Codable {
    case readOnly
    case editable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readOnly: DaycoText.t("보기만 가능")
        case .editable: DaycoText.t("같이 편집 가능")
        }
    }
}

enum DDayCardColor: String, CaseIterable, Identifiable, Codable {
    case typeDefault
    case blue
    case green
    case yellow
    case pink
    case purple
    case darkYellow
    case darkBlue
    case red
    case cyan
    case beige
    case lightGreen
    case gray

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typeDefault: DaycoText.t("유형별 기본")
        case .blue: DaycoText.t("그린")
        case .green: DaycoText.t("그린")
        case .yellow: DaycoText.t("오렌지")
        case .pink: DaycoText.t("노랑")
        case .purple: DaycoText.t("마젠타")
        case .darkYellow: DaycoText.t("노랑")
        case .darkBlue: DaycoText.t("파랑")
        case .red: DaycoText.t("빨강")
        case .cyan: DaycoText.t("청록")
        case .beige: DaycoText.t("노랑")
        case .lightGreen: DaycoText.t("라이트 그린")
        case .gray: DaycoText.t("그레이")
        }
    }
}
