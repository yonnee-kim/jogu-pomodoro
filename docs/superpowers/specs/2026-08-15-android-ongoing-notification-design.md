# Android 잠금화면 진행형 알림 설계

날짜: 2026-08-15
브랜치: `worktree-android-ongoing-notification`
선행 작업: iOS Live Activity (2026-07-24 스펙, AppIntent 전환 완료 상태 기준)

## 목표

iOS Live Activity와 동등한 경험을 Android에서 제공한다: 타이머 실행 중 잠금화면·알림창에
남은 시간이 자동 카운트다운되는 진행형(ongoing) 알림을 띄우고, 알림에서 일시정지/재개/취소를
할 수 있으며, 앱 복귀 시 Dart 타이머 상태와 정합을 맞춘다.

범위 제외: 홈 화면 위젯(AppWidget), Android 16 Live Updates(ProgressStyle), 스킨별 캐릭터 이미지.

## 사용자 경험

- 타이머 시작 → 알림 게시. 잠금화면·알림창에서 카운트다운이 매초 자동 갱신.
- 알림 내용: 앱 아이콘 + 큰 카운트다운 숫자 + 서브텍스트("N분 / 오후 5:10" — 총 시간과 종료 시각)
  + `취소 | 일시정지` 텍스트 버튼. 일시정지 중에는 남은 시간이 고정 표시되고 버튼이 `취소 | 재개`로 바뀜.
- 버튼 라벨·라벨 텍스트는 기존 easy_localization 5개 언어 번역을 Dart가 payload로 전달(네이티브에 하드코딩하지 않음).
- 폰트: `Joguman_Handwriting-Rg.ttf`를 `android/app/src/main/res/font/`에 복사해
  카운트다운·서브텍스트·버튼에 `android:fontFamily` 적용. 알림은 SystemUI가 렌더링하므로
  커스텀 폰트는 비보장 사양 — 폴백(시스템 폰트) 시에도 레이아웃이 깨지지 않게 구성.
  원본 파일은 메인 체크아웃 `assets/fonts/Joguman_Handwriting-Rg.ttf`(git 미추적, 11MB)이며
  이 브랜치에는 Android 리소스 사본만 추가한다(Flutter assets/pubspec에는 등록하지 않음).
- 타이머 종료 시(앱이 실행 중이든 아니든) 진행형 알림은 제거되고 기존 종료 알림(소리·진동)이 울린다.
- 제약(수용): 숫자 폰트가 일부 OEM에서 시스템 폰트로 폴백될 수 있음. OEM별 여백·모서리 차이.
  Android 14+에서 사용자가 알림을 스와이프로 지울 수 있음 — 지워져도 타이머와 종료 예약 알림은 정상 동작.

## 아키텍처: iOS 구조 미러링

핵심 원칙: 버튼 탭은 네이티브에서 완결하고, Dart는 앱 복귀 시 sync 스냅샷을 소비(consume)해
상태를 조정한다. iOS의 AppIntent + App Group 스냅샷 구조와 동일한 규약을 SharedPreferences로 재현한다.

### 1. Dart 계층 — `LiveActivityService` 플랫폼 공용화

`lib/services/live_activity_service.dart`:

- `Platform.isIOS` no-op 가드를 플랫폼 분기로 교체.
  - iOS: 기존 `live_activities` 플러그인 경로 그대로.
  - Android: 자체 MethodChannel `com.joguman.pomodoro/live_activity`(iOS와 같은 채널명)로
    `start` / `updatePaused` / `end` invoke.
- `consumeSync()`, `setNativePingListener()`는 이미 이 채널을 쓰므로 변경 없음.
- 호출 지점 6곳(`data_provider.dart`, `utility.dart`, `pomodoro_cast.dart`, `home_screen.dart`,
  `main.dart`)은 수정하지 않는다.
- `startOrUpdateRunning`에 Android용 추가 payload: 총 분(`totalMinutes`), 버튼 라벨 번역
  (`pauseLabel`, `resumeLabel`, `cancelLabel`). iOS 경로에는 영향 없음.
- Android의 `init()`: 활동 입양(iOS 전용 개념) 대신 no-op에 가깝게 — 알림 존재 여부는 네이티브가
  SharedPreferences 상태로 판단.

`lib/services/live_activity_payload.dart`:

- `reconcileFromSync(...)`, `LiveActivityAction`, `ReconcileKind`는 플랫폼 중립 — 그대로 재사용.
- Android payload 구성 순수 함수를 추가(단위 테스트 대상).

### 2. sync 규약 (iOS와 동일한 키·의미)

네이티브(Kotlin)가 SharedPreferences(`joguman_timer_notification` prefs)에 기록:

- `la_sync_action`: `pause` | `resume` | `cancel` (1회성, consume 시 삭제)
- `la_sync_end_date_ms`: 재개/실행 중 종료 시각(ms)
- `la_sync_remaining_ms`: 일시정지 시 남은 ms

Dart `consumeSync()` → 기존 `reconcileFromSync`가 `pausedAway` / `runningAway` /
`finishedAway` / `cancelledAway`로 해석. 소비 시점: (a) 앱 `resumed`,
(b) 포그라운드 상태에서 네이티브 핑(`syncRequested`) 수신 — iOS와 동일 흐름.

### 3. 네이티브 계층 (Kotlin 신규)

패키지: `com.joguman.pomodoro` (기존 `MainActivity.kt` 경로 `com/example/joguman_pomodoro`와의
디렉터리 불일치는 이번에 손대지 않음 — 신규 파일은 기존 디렉터리에 함께 둠).

- `MainActivity.kt` (확장): `configureFlutterEngine`에서 MethodChannel 등록.
  메서드: `start`, `updatePaused`, `end`, `consumeSync`. 포그라운드에서 Receiver가 상태를
  바꾸면 `syncRequested`를 Dart로 push — MainActivity companion object에 채널 참조를 두고
  Receiver가 접근(iOS의 NotificationCenter 옵저버와 같은 역할, 액티비티 부재 시 no-op).
- `TimerNotificationManager.kt` (신규): 알림 채널 생성(`timer_ongoing`, IMPORTANCE_LOW 무음,
  `lockscreenVisibility = VISIBILITY_PUBLIC`), RemoteViews 빌드(축소/확장), 게시·갱신·제거.
  실행 중 카운트다운은 `Chronometer`(`setChronometerCountDown(true)`,
  `base = elapsedRealtime() + remainingMs`) — 시스템 자동 갱신이라 매초 재게시 없음.
  일시정지 중에는 고정 텍스트(MM:SS). `setOngoing(true)`.
- `TimerActionReceiver.kt` (신규 BroadcastReceiver, 매니페스트 등록, exported=false):
  버튼 PendingIntent 수신. 앱 프로세스·Flutter 엔진 없이도 동작.
  - `pause`: 남은 ms 계산 → prefs에 상태 기록(`isPaused=true`, `remainingMs`) + sync 스냅샷
    (`la_sync_action=pause`, `la_sync_remaining_ms`) → 알림을 일시정지 뷰로 갱신 →
    종료 알람 취소(아래 4절) → 포그라운드면 핑.
  - `resume`: `endMs` 재계산 → prefs·sync 기록(`la_sync_action=resume`, `la_sync_end_date_ms`)
    → 알림을 실행 뷰로 갱신 → 자체 종료 알람 예약(아래 4절) → 핑.
  - `cancel`: prefs 정리 + sync(`la_sync_action=cancel`) → 알림 제거 → 양쪽 종료 알람 취소 → 핑.
  - 중복 탭 가드: 현재 상태와 액션이 안 맞으면 무시(iOS `guard !isPaused` 등과 동일).
- `TimerFinishReceiver.kt` (신규 BroadcastReceiver): 자체 예약 알람(4절) 수신 시
  종료 알림 표시(소리 `bip`, 진동, `notifTitle`/`notifBody`) + 진행형 알림 제거 + prefs 정리.

### 4. 종료 알림 예약의 소유권 (핵심 결정)

- 타이머 시작 시: 지금처럼 Dart(`flutter_local_notifications.zonedSchedule`, id 0)가 예약.
- 잠금화면 **일시정지**: 네이티브가 플러그인의 알람을 취소. 플러그인 PendingIntent는
  대상 `ScheduledNotificationReceiver`, requestCode = 알림 id(0) — 취소는 intent 매칭
  (component + requestCode)만 필요하므로 안전. `FLAG_NO_CREATE`로 조회 후 cancel.
- 잠금화면 **재개**: 플러그인 내부 페이로드(직렬화된 알림 스펙) 재현은 취약하므로 하지 않는다.
  대신 네이티브 자체 `AlarmManager.setExactAndAllowWhileIdle` 알람(→ `TimerFinishReceiver`)으로
  재예약. 제목/본문은 시작 시 Dart가 payload로 전달해 prefs에 저장해 둔 `notifTitle`/`notifBody` 사용
  (iOS Resume AppIntent가 Swift에서 재예약하는 것과 동일 패턴). 종료 알림 채널은 기존
  `end_alarm` 채널 규약(사운드 `bip`, 중요도 max)과 동일하게 네이티브에서 생성.
- 알람 소유권 분리(이중 예약·오취소 방지 불변식):
  - 플러그인 알람(id 0)은 **Dart가 소유** — 예약·취소 모두 기존 Dart 흐름 그대로.
    네이티브 `start`/`end` 핸들러는 플러그인 알람을 건드리지 않는다
    (Dart의 `setMyTimer`가 예약 직후 `start`를 invoke하므로, 네이티브가 취소하면 방금 예약한
    알람을 지우는 순서 버그가 생김).
  - 자체 알람은 **네이티브가 소유** — Receiver `resume`에서만 예약하고, 네이티브
    `start`/`end` 핸들러와 Receiver `pause`/`cancel`에서 취소.
  - 플러그인 알람을 네이티브가 취소하는 유일한 경로는 Receiver `pause`/`cancel`
    (앱 밖에서 탭됐고 Dart가 개입할 수 없는 시점).
- exact alarm 권한: 기존 `USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM` 선언 재사용.
  `canScheduleExactAlarms()` false면 `setAndAllowWhileIdle`로 폴백.

### 5. 매니페스트·권한

- `POST_NOTIFICATIONS` 주석 해제(Android 13+ 필수 — 기존 예약 알림에도 원래 필요했던 것).
- 앱 시작 시 Android 13+ 알림 권한 요청: 기존 `permission_handler`로
  `Permission.notification.request()` (현재 iOS만 요청 중인 부분 보완).
- `TimerActionReceiver`, `TimerFinishReceiver` 등록(`exported="false"`).

### 6. 알림 레이아웃 리소스

- `res/layout/notification_timer_collapsed.xml`, `notification_timer_expanded.xml`
  (실행/일시정지는 동일 레이아웃에서 Chronometer/TextView 가시성 토글).
- `res/font/joguman_handwriting.ttf` (리소스 명명 규칙: 소문자+밑줄).
- `DecoratedCustomViewStyle` 없이 완전 커스텀 뷰 사용(목업의 카드형 디자인 유지).
  배경은 목업 기조(밝은 배경 + 검정 텍스트)를 다크모드에서도 그대로 쓰는 단일 팔레트.

### 7. 엣지 케이스

- 알림 스와이프 삭제(Android 14+): `deleteIntent`로 감지하지 않고 무시 — 타이머·종료 알람은 유지.
  앱 복귀 시 Dart 상태는 그대로이므로 정합 문제 없음(알림만 사라진 상태).
- 프로세스 사망 후 버튼 탭: Receiver가 새 프로세스에서 순수 네이티브로 처리. prefs가 유일한 진실.
- 앱 강제 종료(force stop): 알람·알림 모두 시스템이 제거 — 별도 대응 없음(iOS도 동일 한계).
- 재부팅: 진행형 알림·자체 알람 소멸. 기존 `ScheduledNotificationBootReceiver`가 플러그인 예약만
  복원. 재부팅 복원은 범위 외(현 iOS 구현도 동일 수준).
- 기기 잠금 상태에서 버튼 탭: BroadcastReceiver 기반이라 잠금 해제 없이 즉시 동작.

### 8. 테스트

- Dart 순수 함수(Android payload 구성, 기존 reconcile 재사용부): `test/services/`에 단위 테스트 추가.
- `LiveActivityService` 플랫폼 분기: MethodChannel mock 테스트(가능한 범위).
- 네이티브 Kotlin: 단위 테스트 없이 수동 E2E — 사용자가 직접 기기에서 검증
  (시작→잠금→일시정지→재개→취소→종료 시나리오, 앱 스와이프 킬 후 버튼 탭 시나리오).
- `flutter analyze` / `flutter test` 통과를 각 단계 완료 기준으로 삼는다.

## 결정 기록

- 진행형 알림(오른쪽 목업)만 구현, 홈 위젯(왼쪽 목업)은 범위 외 — 사용자 확정.
- 네이티브 커스텀 레이아웃(RemoteViews) 채택 — 시스템 기본 레이아웃 대신 목업 유사 디자인, 사용자 확정.
- 캐릭터 이미지는 앱 아이콘 고정 — 사용자 확정.
- 폰트는 `Joguman_Handwriting-Rg.ttf`, 비보장(폴백 허용) 조건부 적용 — 사용자 확정.
- Foreground Service 미사용: 알림 갱신이 상태 전이 시점에만 필요(Chronometer 자동 갱신)하므로
  서비스 생존이 불필요. BroadcastReceiver + AlarmManager로 충분.
