import Foundation

enum DaycoLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .korean: "ko_KR"
        case .english: "en_US"
        }
    }
}

enum DaycoText {
    static var language: DaycoLanguage {
        DaycoLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .korean
    }

    static func t(_ key: String) -> String {
        guard language == .english else { return key }
        return english[key] ?? key
    }

    static func day(_ value: Int) -> String {
        language == .english ? "\(max(value, 1).formatted()) days" : "\(max(value, 1).formatted())일"
    }

    private static let english: [String: String] = [
        "설정": "Settings",
        "나의 설정": "My Settings",
        "화면": "Appearance",
        "모드": "Mode",
        "시스템": "System",
        "라이트": "Light",
        "다크": "Dark",
        "언어 설정": "Language",
        "언어": "Language",
        "백업": "Backup",
        "iCloud 백업": "iCloud Backup",
        "변경한 백업 설정은 앱을 다시 실행한 뒤 적용됩니다.": "Backup changes apply after restarting the app.",
        "앱 정보": "App Info",
        "버전": "Version",
        "이용약관 및 정책": "Terms & Policies",
        "개발자의 다른 앱": "More Apps by Developer",
        "완료": "Done",
        "닫기": "Close",
        "저장": "Save",
        "취소": "Cancel",
        "삭제": "Delete",
        "고정": "Pin",
        "해제": "Unpin",
        "편집": "Edit",
        "상세": "Details",
        "확인": "OK",
        "기본": "Basic",
        "제목": "Title",
        "날짜": "Date",
        "상단에 고정": "Pin to Top",
        "유형": "Type",
        "디데이 유형": "D-Day Type",
        "반복": "Repeat",
        "기념일": "Anniversary",
        "직접 입력": "Custom",
        "일": "days",
        "색상": "Color",
        "계산 옵션": "Calculation",
        "표시 단위": "Display Unit",
        "시작일을 1일로 계산": "Count start date as day 1",
        "알림": "Notifications",
        "알림 날짜": "Notification Date",
        "알림 시간": "Notification Time",
        "설정한 알림": "Selected Notification",
        "추가": "Add",
        "설정된 알림 없음": "No notifications set",
        "알림 삭제": "Delete notification",
        "공유": "Sharing",
        "친구와 공유": "Share with Friends",
        "권한": "Permission",
        "iCloud 공유는 디데이를 저장한 뒤 사용할 수 있습니다.": "iCloud sharing is available after saving this D-Day.",
        "공유 준비 중": "Preparing Share",
        "iCloud 공유 초대 보내기": "Send iCloud Share Invitation",
        "공유는 Dayco 앱 사용자끼리 iCloud로 진행됩니다. 초대를 받은 친구도 Dayco 앱 설치와 iCloud 로그인이 필요합니다.": "Sharing works between Dayco users through iCloud. Invited friends need the Dayco app installed and must be signed in to iCloud.",
        "iCloud 공유를 완료할 수 없습니다": "Couldn’t Complete iCloud Sharing",
        "잠시 후 다시 시도해 주세요.": "Please try again later.",
        "iCloud 공유 정보를 준비하지 못했습니다.": "Couldn’t prepare iCloud sharing information.",
        "iCloud 공유 링크를 준비하지 못했습니다.": "Couldn’t prepare the iCloud sharing link.",
        "삭제하시겠습니까?": "Delete this D-Day?",
        "이 디데이는 복구할 수 없습니다.": "This D-Day can’t be restored.",
        "지난 날짜를 선택해 주세요": "Choose a Past Date",
        "디데이 유형이 지난 날짜일 때는 오늘보다 과거인 날짜로 설정해야 합니다.": "When the type is elapsed date, choose a date before today.",
        "달력에서 고른 날짜와 시간에 알림이 옵니다.\n시작일보다 이전 날짜는 추가할 수 없습니다.": "You’ll be notified at the selected date and time.\nDates before the start date can’t be added.",
        "달력에서 고른 날짜와 시간에 알림이 옵니다.\n디데이 이후 날짜는 추가할 수 없습니다.": "You’ll be notified at the selected date and time.\nDates after the D-Day can’t be added.",
        "시작일 이후 날짜를 선택해 주세요": "Choose a date after the start date",
        "디데이 이전 또는 당일을 선택해 주세요": "Choose a date before or on the D-Day",
        "지난 날짜": "Elapsed Date",
        "남은 날짜": "Remaining Date",
        "반복 기념일": "Recurring Anniversary",
        "일 + 시간": "Days + Hours",
        "년 + 개월 + 일": "Years + Months + Days",
        "일수": "Days",
        "시간": "hours",
        "분": "minutes",
        "매년": "Yearly",
        "매월": "Monthly",
        "보기만 가능": "View Only",
        "같이 편집 가능": "Can Edit",
        "검색": "Search",
        "디데이 이름 검색": "Search D-Day name",
        "검색 결과 없음": "No Results",
        "알림 규칙": "Notification Rule",
        "예약됨": "Scheduled",
        "확인할 알림 없음": "No Notifications",
        "디데이 달력": "D-Day Calendar",
        "오늘": "Today",
        "오늘 날짜": "Today",
        "등록된 디데이 없음": "No D-Days",
        "아직 등록된 디데이가 없어요": "No D-Days Yet",
        "중요한 날짜를 추가하고 오늘부터 바로 확인해보세요.": "Add an important date and start tracking it today.",
        "첫 디데이 추가": "Add First D-Day",
        "달력": "Calendar",
        "디데이 추가": "Add D-Day",
        "개인 설정": "Personal Settings",
        "디데이 편집": "Edit D-Day",
        "계산 방식": "Calculation",
        "상태": "Status",
        "공유 중": "Shared",
        "개인 디데이": "Personal D-Day",
        "시작일 포함": "Include Start Date",
        "켬": "On",
        "끔": "Off",
        "다음": "Next",
        "당일": "Same Day",
        "선택한 날짜": "Selected Date",
        "유형별 기본": "Type Default",
        "그린": "Green",
        "오렌지": "Orange",
        "노랑": "Yellow",
        "마젠타": "Magenta",
        "파랑": "Blue",
        "빨강": "Red",
        "청록": "Cyan",
        "라이트 그린": "Light Green",
        "그레이": "Gray"
    ]
}
