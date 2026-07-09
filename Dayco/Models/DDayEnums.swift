import Foundation

enum DDayType: String, CaseIterable, Identifiable, Codable {
    case countUp
    case countDown
    case recurring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countUp: "지난 날짜"
        case .countDown: "남은 날짜"
        case .recurring: "반복 기념일"
        }
    }

    var symbolName: String {
        switch self {
        case .countUp: "plus.forwardslash.minus"
        case .countDown: "calendar.badge.clock"
        case .recurring: "arrow.trianglehead.2.clockwise"
        }
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
        case .days: "일"
        case .hours: "시간"
        case .minutes: "분"
        case .daysAndHours: "일 + 시간"
        case .yearsMonthsDays: "년 + 개월 + 일"
        }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable, Codable {
    case yearly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearly: "매년"
        case .monthly: "매월"
        }
    }
}

enum SharePermission: String, CaseIterable, Identifiable, Codable {
    case readOnly
    case editable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readOnly: "보기만 가능"
        case .editable: "같이 편집 가능"
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
        case .typeDefault: "유형별 기본"
        case .blue: "그린"
        case .green: "그린"
        case .yellow: "오렌지"
        case .pink: "노랑"
        case .purple: "마젠타"
        case .darkYellow: "노랑"
        case .darkBlue: "파랑"
        case .red: "빨강"
        case .cyan: "청록"
        case .beige: "노랑"
        case .lightGreen: "라이트 그린"
        case .gray: "그레이"
        }
    }
}
