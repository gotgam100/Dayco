# Dayco

Dayco는 중요한 날짜를 단순하게 세고, 위젯과 알림으로 확인하며, 친구와 함께 공유하는 iOS 디데이 앱입니다.

## 현재 구현 범위

- SwiftUI 기반 iOS 앱 프로젝트
- SwiftData 기반 디데이 저장 모델
- 지난 날짜, 남은 날짜, 매년/매월 반복 디데이 계산
- 일, 시간, 분, 일+시간, 년+개월+일 표시 단위
- 디데이 목록, 생성/편집, 상세 화면
- 직접 입력하는 알림 일수 UI와 로컬 알림 예약 서비스 뼈대

## 프로젝트 생성

```sh
xcodegen generate
```

## 테스트

```sh
xcodebuild test -scheme Dayco -destination 'platform=iOS Simulator,name=iPhone 16'
```

## GitHub Pages

이용약관 및 정책 페이지는 `docs/` 폴더에 있습니다.

GitHub 저장소의 `Settings > Pages`에서 `Deploy from a branch`를 선택하고, branch는 `main`, folder는 `/docs`로 설정하면 아래 주소로 배포됩니다.

```text
https://gotgam100.github.io/Dayco/
```
