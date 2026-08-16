# AlarmKit 마이그레이션 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 26+에서 타이머를 AlarmKit으로 예약해 0초 자연종료 시 위젯·다이내믹 아일랜드가 시스템에 의해 정리되도록 하고, '끝!' 표시 방식을 제거한다.

**Architecture:** 분기는 Dart `LiveActivityService` 내부 한 곳(iOS 26+ && AlarmKit 권한 허용 → AlarmKit 채널, 그 외 기존 live_activities 경로). 네이티브는 AppDelegate 채널 + `ios/Shared/AlarmKitSupport.swift`(양쪽 타깃) + 위젯 `JogumanAlarmLiveActivity`. 기존 `la_sync_*` 스냅샷/핑 동기화 메커니즘 재사용.

**Tech Stack:** Flutter(Provider), Swift(AlarmKit, ActivityKit, AppIntents, WidgetKit), Xcode 26 SDK.

**Spec:** docs/superpowers/specs/2026-08-16-alarmkit-migration-design.md

## Global Constraints

- AlarmKit 코드는 전부 `@available(iOS 26.0, *)` 가드.
- 종료음은 `.named("bip.wav")` (1회 재생). 알럿 제목은 `end_message`, 중지 버튼은 신규 키 `la_stop`.
- iOS 26+에서 로컬 종료 알림 예약·무음모드 진동 특례 건너뜀.
- 자연종료(0초)는 AlarmKit 경로에서 알람을 건드리지 않음(알럿이 울려야 함). 사용자 취소만 stop/cancel.
- `ios/LiveActivity/`는 동기화 그룹(파일만 추가), `ios/Shared/`는 레거시 그룹(pbxproj에 파일참조+빌드파일 추가 필요, 기존 5A11AA07 패턴 참조).
- 커밋은 사용자가 요청할 때만 (git-commit 스킬).

---

### Task 1: Dart — '끝!'/staleDate 제거

**Files:**
- Modify: `test/services/live_activity_payload_test.dart` (doneLabel 기대 제거)
- Modify: `lib/services/live_activity_payload.dart` (buildRunningPayload에서 doneLabel 파라미터/키 제거)
- Modify: `lib/services/live_activity_service.dart` (doneLabel 파라미터, setStaleDate invokeMethod 2곳 제거)
- Modify: `lib/providers/data_provider.dart` (doneLabel 인자 제거)
- Modify: `assets/translations/{en,ko,ja,zh-Hans,zh-Hant}.json` (la_done 키 제거)

- [ ] 테스트에서 doneLabel 기대 제거 후 `flutter test` 실패 확인 → 구현 제거 → `flutter test` 통과.

### Task 2: iOS 기존 경로 — '끝!'/staleDate 제거

**Files:**
- Modify: `ios/LiveActivity/JogumanTimerLiveActivity.swift` (timerText의 isStale/'끝!' 분기 제거, 카운트다운 Text만 유지)
- Modify: `ios/Shared/TimerControlIntents.swift` (resume의 staleDate 지정 → nil)
- Modify: `ios/Runner/AppDelegate.swift` (setStaleDate 메서드·채널 케이스 제거)

- [ ] 제거 후 Task 8 빌드에서 컴파일 확인.

### Task 3: 번역 — la_stop 추가

**Files:**
- Modify: `assets/translations/*.json` 5개

- [ ] ko `중지`, en `Stop`, ja `停止`, zh-Hans `停止`, zh-Hant `停止`.

### Task 4: iOS Shared — AlarmKitSupport.swift

**Files:**
- Create: `ios/Shared/AlarmKitSupport.swift`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (파일참조 + Runner/LiveActivityExtension 양쪽 Sources 빌드파일, 기존 TimerControlIntents 항목 패턴 복제)

**Interfaces (Produces):**
- `struct JogumanAlarmMetadata: AlarmMetadata` — `let label: String` (위젯 '타이머' 라벨)
- `@available(iOS 26.0, *) enum AlarmKitControlHandler`:
  - App Group 키: `ak_alarmId`, `ak_endDateMs`, `ak_remainingSeconds`, `ak_isPaused`
  - `pause()` / `resume()` / `cancel()` — AlarmManager 호출 + 북키핑 + `la_sync_*` 스냅샷 기록 + `JogumanTimerControlDidChange` 핑 (TimerControlHandler와 동일 스냅샷 계약, 알림 재예약 없음)
- LiveActivityIntent 3종: `AlarmKitPauseIntent` / `AlarmKitResumeIntent` / `AlarmKitCancelIntent`

- [ ] 파일 작성 + pbxproj 등록. 컴파일 확인은 Task 8.

### Task 5: iOS Runner — 채널 배선 + Info.plist

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Info.plist` (`NSAlarmKitUsageDescription`)

**Interfaces (Produces, 채널 `com.joguman.pomodoro/live_activity`):**
- `alarmkitAvailable` → Bool (iOS 26+)
- `alarmkitEnsureAuth` → Bool (authorized)
- `alarmkitStart {endDateMs, label, alertTitle, stopLabel}` → 기존 알람이 같은 endDateMs(±1.5s)로 카운트다운 중이면 no-op(위젯 resume 후 reconcile 재호출 대비), 아니면 cancel 후 `AlarmManager.schedule(id:, configuration: .timer(duration:, attributes:, sound: .named("bip.wav")))`
- `alarmkitPause` / `alarmkitCancel` → AlarmKitControlHandler 위임 (단, 앱 발신이므로 스냅샷 기록 없이 알람·북키핑만)

- [ ] AlarmPresentation: alert(title: end_message 번역, stopButton: la_stop) + countdown/paused(title: label, 버튼 문구는 시스템 위젯이 아닌 커스텀 UI를 쓰므로 최소값).

### Task 6: 위젯 — JogumanAlarmLiveActivity

**Files:**
- Create: `ios/LiveActivity/WidgetTheme.swift` (TimerMetrics·jogumanFont·buttonImage를 JogumanTimerLiveActivity.swift에서 이동, internal)
- Modify: `ios/LiveActivity/JogumanTimerLiveActivity.swift` (이동분 제거)
- Create: `ios/LiveActivity/JogumanAlarmLiveActivity.swift` (`@available(iOS 26.0, *)`)
- Modify: `ios/LiveActivity/LiveActivityBundle.swift` (`@WidgetBundleBuilder` 헬퍼로 `#available(iOS 26)` 등록)

**Interfaces (Consumes):** Task 4의 JogumanAlarmMetadata·인텐트 3종.

- [ ] `ActivityConfiguration(for: AlarmAttributes<JogumanAlarmMetadata>.self)`. `context.state.mode`로 렌더:
  - `.countdown(cd)`: `Text(timerInterval: (cd.fireDate - remainingWindow)...cd.fireDate, countsDown: true)`, 링은 시작 = fireDate − totalCountdownDuration
  - `.paused(p)`: 남은 = totalCountdownDuration − previouslyElapsedDuration, 정적 Text + 정적 ProgressView
  - `.alert`: 라벨 + `0:00` (시스템 알럿 UI가 덮으므로 폴백)
  - 잠금화면/아일랜드 레이아웃·상수는 기존 JogumanTimerLiveActivity와 동일 구성 재사용.

### Task 7: Dart — AlarmKit 라우팅

**Files:**
- Modify: `lib/services/live_activity_service.dart`
- Modify: `lib/providers/data_provider.dart`

**Interfaces (Produces):**
- `LiveActivityService.startOrUpdateRunning(...)` → `Future<bool>` (true = 네이티브가 종료 알럿 전담)
- `LiveActivityService.end({bool natural = false})` — natural + AlarmKit 경로 = no-op
- 내부: `_alarmkitAvailable`(init에서 조회), `_alarmkitAuthorized`(첫 start에서 ensureAuth, 거부 시 이후 기존 경로)

- [ ] `DataProvider.setMyTimer`: `final nativeAlert = await startOrUpdateRunning(...)`; nativeAlert면 setScheduleNotification·진동 특례(currMillisec==1000 분기) 건너뜀(플래그 보관). 자연종료(currMillisec<=0)는 `end(natural: true)`.
- [ ] `pauseTimer` → AlarmKit 경로에서 alarmkitPause. `cancelAndReset`/home_screen finishedAway의 `end()` → stop+cancel.
- [ ] `flutter analyze` + `flutter test` 통과.

### Task 8: 빌드 검증 (Swift 시그니처 확정 루프)

- [ ] `flutter build ios --no-codesign` 또는 xcodebuild로 컴파일. AlarmKit 정확한 시그니처(AlarmConfiguration.timer 파라미터, AlarmPresentation 이니셜라이저, AlarmPresentationState.mode 케이스, alarmID 접근자)는 SDK 에러 기반으로 확정하며 반복.
- [ ] `flutter analyze` / `flutter test` 최종 통과.
- [ ] 실기기 E2E는 사용자 수행(내가 flutter run 금지).
