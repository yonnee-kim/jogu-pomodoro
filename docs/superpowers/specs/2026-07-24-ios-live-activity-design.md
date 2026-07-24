# iOS 잠금화면 타이머 (Live Activity) 설계

작성일: 2026-07-24
브랜치: worktree-ios-live-activity
대상 버전: 1.0.7+20

## 목표

iOS 잠금화면과 Dynamic Island에 뽀모도로 타이머의 실시간 카운트다운을 표시한다.
사용자가 참고한 화면은 iOS 기본 타이머의 Live Activity 형태(타이머 숫자 + 일시정지/취소 버튼)이다.

## 범위 (확정)

- iOS 전용. iOS 16.1+ 지원. Android는 후속으로 진행형 알림(ongoing notification) 방식으로 별도 진행한다.
- 미니멀 디자인: 타이머 카운트다운 + 라벨 + 일시정지(⏸)/취소(✕) 버튼. 스킨(캐릭터) 반영은 후속.
- 버튼 동작 방식은 URL scheme(A안): 버튼 탭 시 앱이 순간 포그라운드로 열려 기존 Dart 로직으로 처리한 뒤 Live Activity를 갱신한다.
- 버튼은 iOS 17.0+ 에서만 노출·동작. iOS 16.1~16.4는 카운트다운 표시만 한다.
- `live_activities` pub 패키지를 사용한다.

## 핵심 기술 판단

- 매초 갱신은 앱이 하지 않는다. SwiftUI `Text(timerInterval:)`에 종료 시각만 넘기면 시스템이 잠금화면에서 카운트다운을 자동으로 그린다. 따라서 백그라운드 실행 권한이나 푸시가 필요 없다. 앱은 시작/일시정지/재개/취소/종료 시점에만 Live Activity를 갱신한다.
- 앱의 Dart 타이머(`Timer.periodic`)는 기존대로 포그라운드에서만 돈다. 백그라운드 카운트다운 표시는 전적으로 SwiftUI에 위임한다.

## 앱 기존 동작 (전제)

- `home_screen.dart`의 하단 버튼 하나가 play/stop을 토글한다.
- "stop"이 호출하는 `cancleTimer()`(`data_provider.dart`)는 남은 시간(`currMillisec`)을 초기화하지 않는다. 따라서 stop은 사실상 일시정지이며, 다시 play를 누르면 `setMyTimer`가 남은 시간부터 이어서 진행한다.
- 즉 앱에는 이미 pause/resume 동작이 존재한다. Live Activity의 ⏸/✕는 이 동작에 매핑한다.

## 동작 흐름

- 시작(`setMyTimer`): Live Activity 생성. 종료 시각(`alarmDate` 상당)을 넘겨 SwiftUI가 자동 카운트다운.
- 일시정지(⏸): 앱 열림 → `cancleTimer`(남은 시간 유지) → Live Activity를 "일시정지(고정된 남은시간)" 상태로 update.
- 재개(▶): 앱 열림 → `setMyTimer`(남은 시간부터) → Live Activity를 새 종료시각으로 update.
- 취소(✕): 앱 열림 → `cancleTimer` + 남은 시간을 `startSec`(시작 시 맞춘 값)으로 복원 → `endActivity`로 즉시 제거. (iOS 기본 타이머 표준 동작: 취소하면 다이얼이 처음 맞춘 값으로 복귀)
- 자연 종료(0 도달): `endActivity`.
- 앱 강제 종료/스와이프: Live Activity는 시스템이 유지하며 종료 시각까지 자동 카운트다운. 앱 재실행 시 기존 `setTimerByLifecycle` 로직과 활동 상태를 동기화.

## 구성 요소와 책임

- Dart `LiveActivityService` (`lib/services/live_activity_service.dart`, 신규): `live_activities` 패키지 래퍼. `start / updatePaused / updateRunning / end` 메서드 제공. 비 iOS 또는 미지원 버전에서는 no-op. `DataProvider`는 이 서비스만 호출한다.
- Dart `DataProvider` 연동: 기존 `setMyTimer` / `cancleTimer`에 `LiveActivityService` 호출 훅 추가. 딥링크 수신 핸들러(앱이 URL로 열렸을 때 action에 따라 pause/resume/cancel 분기).
- Dart 순수 함수(테스트 대상): 딥링크 URL → action 파싱, Live Activity payload 생성 로직을 `*_logic.dart` 형태로 분리한다.
- Swift Widget Extension (`ios/`, 신규 타겟): SwiftUI로 잠금화면/Dynamic Island UI. 패키지 규약명 `LiveActivitiesAppAttributes` 사용. App Group UserDefaults에서 라벨/종료시각/일시정지상태를 읽는다. iOS 17+ 조건부로 버튼(Link)을 렌더한다.
- Xcode 설정: Widget Extension 타겟 추가, App Group `group.com.joguman.pomodoro`(Runner+Extension 양쪽), `NSSupportsLiveActivities=true`(양쪽 Info.plist), URL scheme `joguman://` 등록, Push Notifications capability(Runner).

## 공유 데이터 (App Group UserDefaults)

최소 필드만 공유한다.

- `endDate`: 종료 시각(ISO8601). 카운트다운 기준.
- `isPaused`: bool.
- `remainingSeconds`: 일시정지 시 고정 표시용.
- `label`: 예 "집중". 다국어 문자열은 Dart에서 번역해 전달.
- 버튼 노출 여부 등 표시에 필요한 최소 플래그.

## 테스트 전략

- 단위 테스트: 딥링크 파싱 로직, payload 생성 로직(순수 함수)을 `test/`에서 검증. 기존 `*_logic.dart` 패턴을 따른다.
- 네이티브/위젯 UI: 단위 테스트 불가. 실기기(iOS 17 / iOS 16) 수동 확인 체크리스트로 대체.
- 기존 90개 테스트는 그대로 통과 유지. (`test/widget_test.dart`의 "Counter increments smoke test"는 flutter create 기본 템플릿 잔여 실패로 이번 작업과 무관.)

## 리스크와 주의

- 실기기 필수: Live Activity는 시뮬레이터 제약이 있어 실제 검증은 iOS 기기가 필요하다.
- `flutter build ios` 시 Widget Extension 타겟이 함께 빌드되도록 Xcode 설정 정확도가 관건.
- URL scheme 방식의 트레이드오프: 버튼 탭 시 앱이 순간 열린다. iOS 기본 타이머처럼 앱을 안 열고 잠금화면에서 바로 제어하려면 iOS 17 App Intent가 필요하며, 이는 pause/resume/cancel 로직을 Swift로도 중복 구현해야 해 리스크가 크다. 1차에서는 채택하지 않는다.

## 후속 과제 (이번 범위 밖)

- 스킨(캐릭터/색상) 반영: Live Activity는 정적 이미지만 가능(GIF 불가). App Group 이미지 공유 필요.
- iOS 17 App Intent로 "앱 안 열고 제어" 고도화.
- Android 진행형 알림(Chronometer + 액션 버튼) 구현.

## 팀 공유용 문서 체계

- `_docs/version-update-note/`에 버전별 업데이트 노트를 누적한다. 상세 규칙은 해당 폴더의 `README.md` 참조.
- 이번 작업은 `_docs/version-update-note/1.0.7+20.md`에 요구사항·의사결정·트레이드오프·구현·이슈를 기록한다.
- 문서의 최종 목표는 이를 바탕으로 팀 공유용 자연어 보고 메시지를 작성하는 것이다.
