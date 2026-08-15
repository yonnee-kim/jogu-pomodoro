# Live Activity 버튼 AppIntent 전환 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 잠금화면/Dynamic Island의 ⏸/▶/✕ 버튼을 URL scheme 딥링크에서 iOS 17+ `LiveActivityIntent`로 전환해, 앱을 열지 않고 잠금화면에서 바로 타이머를 제어한다.

**Architecture:** `LiveActivityIntent`는 위젯 익스텐션이 아니라 **앱 프로세스**에서 백그라운드로 실행되므로, Swift가 직접 예약된 종료 알림을 취소/재예약하고 ActivityKit으로 위젯을 갱신한다. Swift는 처리 결과를 App Group UserDefaults에 비접두사 동기화 스냅샷(`la_sync_*`)으로 남기고, Dart는 앱이 foreground로 돌아올 때(또는 실행 중 NotificationCenter→MethodChannel 핑을 받을 때) 스냅샷을 소비해 타이머 상태를 맞춘다. 딥링크 경로는 전부 제거한다.

**Tech Stack:** Flutter/Dart, Swift(AppIntents `LiveActivityIntent`, ActivityKit, UserNotifications), `live_activities` 2.4.2, App Group UserDefaults, MethodChannel.

## Global Constraints

- 버튼은 iOS 17.0+ 전용(기존과 동일). iOS 16.1~16.x는 표시만 되고 버튼 없음. 비 iOS no-op 유지.
- App Group ID: `group.com.joguman.pomodoro`. 번들 ID: `com.joguman.pomodoro`.
- 종료 알림은 `flutter_local_notifications` id 0으로 예약되며, iOS UNNotificationRequest identifier는 `"0"`(정수 id의 stringValue — FLN 소스 `getIdentifier` 확인 완료).
- App Group UserDefaults는 문자열만 저장. 모든 값은 문자열로 변환.
- `live_activities` 플러그인의 update 방식(검증 완료): prefixed 키를 UserDefaults에 쓴 뒤 `activity.update(...)` 호출 — 동일 ContentState여도 위젯이 UserDefaults를 다시 읽어 재렌더링된다. Swift Intent도 같은 방식을 쓴다.
- ActivityKit은 Attributes를 **모듈이 아닌 타입 이름**으로 매칭한다. 플러그인 내부 사본(`LiveActivitiesAppAttributes`, ContentState에 `appGroupId` 필드 있음)과 우리 사본(빈 ContentState)이 같은 활동을 공유한다. 빈 ContentState의 Codable 디코딩은 미지 키를 무시하므로 상호 호환된다.
- Runner 배포 타겟 13.0 → Runner에 컴파일되는 Swift 파일의 ActivityKit/AppIntents 사용부는 `@available` 필수.
- `ios/LiveActivity/`는 폴더 자동 동기화 그룹(익스텐션 타겟 전용). **두 타겟에 모두** 컴파일할 파일은 `ios/Shared/`에 두고 classic PBXFileReference/PBXBuildFile로 양쪽 Sources에 등록한다.
- 기존 테스트(94개, widget_test.dart 템플릿 1개 제외) 통과 유지. .md는 표 없이 리스트.
- 진단 로그(`[LA]`)는 실기기 검증 완료 전까지 유지.

## 파일 구조

- Modify `lib/services/live_activity_payload.dart` — 파서 입력을 딥링크 path에서 bare 액션명으로 변경, `reconcileFromSync` 순수 함수 추가, running payload에 알림 제목/본문 키 추가.
- Modify `test/services/live_activity_payload_test.dart` — 위 변경의 테스트.
- Create `ios/Shared/LiveActivitiesAppAttributes.swift` — 기존 `ios/LiveActivity/LiveActivitiesAppAttributes.swift`를 이동 + `@available(iOS 16.1, *)` 부여. 양쪽 타겟 멤버십.
- Create `ios/Shared/TimerControlIntents.swift` — Pause/Resume/Cancel 3개 `LiveActivityIntent` + 공용 핸들러. 양쪽 타겟 멤버십.
- Modify `ios/Runner.xcodeproj/project.pbxproj` — Shared 그룹/파일 참조, 양쪽 Sources 등록.
- Modify `ios/LiveActivity/JogumanTimerLiveActivity.swift` — `Link` → `Button(intent:)`.
- Modify `ios/Runner/AppDelegate.swift` — MethodChannel(`consumeSync`) + NotificationCenter→Dart 핑 브리지.
- Modify `lib/services/live_activity_service.dart` — `consumeSync()`/네이티브 핑 리스너 추가, urlScheme 제거.
- Modify `lib/providers/data_provider.dart` — running payload 호출부에 알림 제목/본문 전달.
- Modify `lib/screens/home_screen.dart` — 딥링크 리스너 제거, `_syncFromNative()`로 대체.
- Modify `lib/utility.dart` — 백그라운드 자연 종료 시 Live Activity 종료 누락 보완.
- Modify `ios/Runner/Info.plist` — `CFBundleURLTypes`(joguman scheme) 제거.

---

### Task 1: Dart 순수 로직 — 파서 변경 + reconcile 함수 + payload 확장 (TDD)

**Files:**
- Modify: `lib/services/live_activity_payload.dart`
- Test: `test/services/live_activity_payload_test.dart`

**Interfaces:**
- Consumes: 없음(순수 함수).
- Produces:
  - `LiveActivityAction parseLiveActivityAction(String name)` — 입력이 `'pause' | 'resume' | 'cancel'`(bare 이름, 딥링크 path 아님).
  - `enum ReconcileKind { none, pausedAway, runningAway, finishedAway, cancelledAway }`
  - `class ReconcileResult { final ReconcileKind kind; final int newMillisec; }`
  - `ReconcileResult reconcileFromSync({required LiveActivityAction action, required int endDateMs, required int remainingMs, required DateTime now})`
  - `buildRunningPayload({required DateTime endDate, required String label, required String notifTitle, required String notifBody})` — 반환 맵에 `notifTitle`/`notifBody` 키 추가.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/services/live_activity_payload_test.dart`의 파서 테스트를 bare 이름 입력으로 바꾸고, reconcile/payload 테스트를 추가한다. 기존 파서 테스트 그룹을 아래로 교체 + 신규 그룹 추가:

```dart
group('parseLiveActivityAction', () {
  test('bare 액션명을 파싱한다', () {
    expect(parseLiveActivityAction('pause'), LiveActivityAction.pause);
    expect(parseLiveActivityAction('resume'), LiveActivityAction.resume);
    expect(parseLiveActivityAction('cancel'), LiveActivityAction.cancel);
  });
  test('알 수 없는 입력은 unknown', () {
    expect(parseLiveActivityAction('/pause'), LiveActivityAction.unknown);
    expect(parseLiveActivityAction(''), LiveActivityAction.unknown);
  });
});

group('buildRunningPayload', () {
  test('알림 제목/본문 키를 포함한다', () {
    final payload = buildRunningPayload(
      endDate: DateTime.fromMillisecondsSinceEpoch(1000),
      label: '집중',
      notifTitle: '조구만 뽀모도로',
      notifBody: '끝!',
    );
    expect(payload['notifTitle'], '조구만 뽀모도로');
    expect(payload['notifBody'], '끝!');
    expect(payload['endDateMs'], '1000');
  });
});

group('reconcileFromSync', () {
  final now = DateTime.fromMillisecondsSinceEpoch(100000);

  test('pause → pausedAway, 남은 시간 유지', () {
    final r = reconcileFromSync(
        action: LiveActivityAction.pause, endDateMs: 0, remainingMs: 65000, now: now);
    expect(r.kind, ReconcileKind.pausedAway);
    expect(r.newMillisec, 65000);
  });
  test('resume + 종료 시각 미래 → runningAway, 남은 시간 재계산', () {
    final r = reconcileFromSync(
        action: LiveActivityAction.resume, endDateMs: 160000, remainingMs: 0, now: now);
    expect(r.kind, ReconcileKind.runningAway);
    expect(r.newMillisec, 60000);
  });
  test('resume + 종료 시각 경과 → finishedAway', () {
    final r = reconcileFromSync(
        action: LiveActivityAction.resume, endDateMs: 90000, remainingMs: 0, now: now);
    expect(r.kind, ReconcileKind.finishedAway);
    expect(r.newMillisec, 0);
  });
  test('cancel → cancelledAway', () {
    final r = reconcileFromSync(
        action: LiveActivityAction.cancel, endDateMs: 0, remainingMs: 0, now: now);
    expect(r.kind, ReconcileKind.cancelledAway);
  });
  test('unknown → none', () {
    final r = reconcileFromSync(
        action: LiveActivityAction.unknown, endDateMs: 0, remainingMs: 0, now: now);
    expect(r.kind, ReconcileKind.none);
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/services/live_activity_payload_test.dart`
Expected: FAIL (reconcileFromSync 미정의, notifTitle 파라미터 없음, 파서 기대값 불일치)

- [ ] **Step 3: 최소 구현**

`lib/services/live_activity_payload.dart`:

```dart
/// Live Activity 페이로드 생성, 제어 액션 파싱, 네이티브 동기화 해석 (순수 함수).
/// App Group UserDefaults는 문자열만 저장하므로 모든 값을 문자열로 변환한다.

enum LiveActivityAction { pause, resume, cancel, unknown }

enum ReconcileKind { none, pausedAway, runningAway, finishedAway, cancelledAway }

class ReconcileResult {
  final ReconcileKind kind;
  final int newMillisec;
  const ReconcileResult(this.kind, this.newMillisec);
}

/// 실행 중(카운트다운) 상태 페이로드.
/// notifTitle/notifBody는 위젯 버튼(재개)이 앱 프로세스의 Swift Intent에서
/// 종료 알림을 재예약할 때 사용한다.
Map<String, dynamic> buildRunningPayload({
  required DateTime endDate,
  required String label,
  required String notifTitle,
  required String notifBody,
}) {
  return {
    'endDateMs': endDate.millisecondsSinceEpoch.toString(),
    'isPaused': 'false',
    'remainingSeconds': '0',
    'label': label,
    'notifTitle': notifTitle,
    'notifBody': notifBody,
  };
}

/// 일시정지 상태 페이로드. remainingSeconds로 고정 표시.
Map<String, dynamic> buildPausedPayload({
  required int remainingSeconds,
  required String label,
}) {
  return {
    'endDateMs': '0',
    'isPaused': 'true',
    'remainingSeconds': remainingSeconds.toString(),
    'label': label,
  };
}

/// 네이티브가 전달한 액션명('pause'|'resume'|'cancel')을 변환.
LiveActivityAction parseLiveActivityAction(String name) {
  switch (name) {
    case 'pause':
      return LiveActivityAction.pause;
    case 'resume':
      return LiveActivityAction.resume;
    case 'cancel':
      return LiveActivityAction.cancel;
    default:
      return LiveActivityAction.unknown;
  }
}

/// Swift Intent가 남긴 동기화 스냅샷을 Dart 타이머 상태 변화로 해석한다.
ReconcileResult reconcileFromSync({
  required LiveActivityAction action,
  required int endDateMs,
  required int remainingMs,
  required DateTime now,
}) {
  switch (action) {
    case LiveActivityAction.pause:
      return ReconcileResult(ReconcileKind.pausedAway, remainingMs);
    case LiveActivityAction.resume:
      final remaining = endDateMs - now.millisecondsSinceEpoch;
      if (remaining > 0) {
        return ReconcileResult(ReconcileKind.runningAway, remaining);
      }
      return const ReconcileResult(ReconcileKind.finishedAway, 0);
    case LiveActivityAction.cancel:
      return const ReconcileResult(ReconcileKind.cancelledAway, 0);
    case LiveActivityAction.unknown:
      return const ReconcileResult(ReconcileKind.none, 0);
  }
}
```

이 시점에 `data_provider.dart`의 `startOrUpdateRunning` 호출부가 컴파일 에러가 나므로 함께 수정한다(`lib/providers/data_provider.dart`의 `setMyTimer` 안):

```dart
      LiveActivityService.instance.startOrUpdateRunning(
        endDate: alarmDate,
        label: 'live_activity_title'.tr(),
        notifTitle: 'app_name'.tr(),
        notifBody: 'end_message'.tr(),
      );
```

`lib/services/live_activity_service.dart`의 `startOrUpdateRunning`에도 파라미터를 통과시킨다:

```dart
  Future<void> startOrUpdateRunning({
    required DateTime endDate,
    required String label,
    required String notifTitle,
    required String notifBody,
  }) async {
    if (!await _enabled()) return;
    final data = buildRunningPayload(
      endDate: endDate,
      label: label,
      notifTitle: notifTitle,
      notifBody: notifBody,
    );
    // ... 이하 기존 try/catch 블록 그대로
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/services/live_activity_payload_test.dart && flutter analyze lib/services lib/providers`
Expected: 테스트 전체 PASS, 신규 analyze 이슈 0

- [ ] **Step 5: 전체 회귀 확인**

Run: `flutter test`
Expected: 기존과 동일(94 pass / widget_test.dart 템플릿 1 fail)

- [ ] **Step 6: 커밋**

```bash
git add lib/services/live_activity_payload.dart lib/services/live_activity_service.dart lib/providers/data_provider.dart test/services/live_activity_payload_test.dart
git commit -m "feat: reconcile 순수 함수 및 알림 재예약용 payload 키 추가"
```

---

### Task 2: Swift 공유 파일 — Shared 폴더, Intent 3종, 양쪽 타겟 멤버십

**Files:**
- Create: `ios/Shared/LiveActivitiesAppAttributes.swift` (기존 `ios/LiveActivity/LiveActivitiesAppAttributes.swift` 이동)
- Create: `ios/Shared/TimerControlIntents.swift`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: App Group prefixed 키(`<uuid>_endDateMs`/`_isPaused`/`_remainingSeconds`/`_notifTitle`/`_notifBody`), 알림 identifier `"0"`, 사운드 `bip.wav`(Runner 번들 포함 확인 완료).
- Produces:
  - `PauseTimerIntent`, `ResumeTimerIntent`, `CancelTimerIntent` — `@available(iOS 17.0, *) LiveActivityIntent`. Task 3의 위젯 버튼이 사용.
  - 비접두사 동기화 스냅샷 키: `la_sync_action`(`"pause"|"resume"|"cancel"`), `la_sync_end_date_ms`, `la_sync_remaining_ms` (모두 문자열). Task 4의 `consumeSync`가 소비.
  - `NotificationCenter` post 이름: `"JogumanTimerControlDidChange"`. Task 4의 AppDelegate가 관찰.

- [ ] **Step 1: Attributes 파일 이동 + availability 부여**

```bash
mkdir -p ios/Shared
git mv ios/LiveActivity/LiveActivitiesAppAttributes.swift ios/Shared/LiveActivitiesAppAttributes.swift
```

내용을 아래로 교체한다(Runner는 배포 타겟 13.0이므로 `@available` 필수):

```swift
import ActivityKit
import Foundation

// live_activities 패키지 규약상 이름은 반드시 LiveActivitiesAppAttributes 여야 한다.
// ActivityKit은 타입 이름으로 활동을 매칭하므로 플러그인 내부 사본과 같은 활동을 공유한다.
@available(iOS 16.1, *)
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  public struct ContentState: Codable, Hashable {}
  var id = UUID()
}

@available(iOS 16.1, *)
extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    return "\(id)_\(key)"
  }
}
```

- [ ] **Step 2: TimerControlIntents.swift 작성**

`ios/Shared/TimerControlIntents.swift`:

```swift
import ActivityKit
import AppIntents
import Foundation
import UserNotifications

/// LiveActivityIntent는 위젯 익스텐션이 아니라 앱 프로세스에서 실행된다.
/// 앱이 예약한 종료 알림(id "0")을 여기서 직접 취소/재예약할 수 있는 이유다.
/// 이 파일은 Runner와 LiveActivityExtension 양쪽 타겟에 컴파일된다
/// (위젯은 Button(intent:) 참조용, 실행은 앱 프로세스).
@available(iOS 17.0, *)
enum TimerControlHandler {
  static let appGroupId = "group.com.joguman.pomodoro"
  static let notificationId = "0"
  static let syncChangedNotification = Notification.Name("JogumanTimerControlDidChange")

  static func currentActivity() -> Activity<LiveActivitiesAppAttributes>? {
    Activity<LiveActivitiesAppAttributes>.activities.first { $0.activityState == .active }
  }

  static func pause() async {
    guard let activity = currentActivity(),
          let defaults = UserDefaults(suiteName: appGroupId) else { return }
    let prefix = activity.attributes.id
    let endMs = Double(defaults.string(forKey: "\(prefix)_endDateMs") ?? "0") ?? 0
    let remainingMs = max(0, Int(endMs - Date().timeIntervalSince1970 * 1000))
    let remainingSec = Int(ceil(Double(remainingMs) / 1000))

    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: [notificationId])

    defaults.set("true", forKey: "\(prefix)_isPaused")
    defaults.set(String(remainingSec), forKey: "\(prefix)_remainingSeconds")
    defaults.set("0", forKey: "\(prefix)_endDateMs")
    writeSync(defaults, action: "pause", endDateMs: 0, remainingMs: remainingMs)

    await activity.update(ActivityContent(state: .init(), staleDate: nil))
    notifyApp()
  }

  static func resume() async {
    guard let activity = currentActivity(),
          let defaults = UserDefaults(suiteName: appGroupId) else { return }
    let prefix = activity.attributes.id
    let remainingSec = Int(defaults.string(forKey: "\(prefix)_remainingSeconds") ?? "0") ?? 0
    guard remainingSec > 0 else { return }
    let endMs = Int(Date().timeIntervalSince1970 * 1000) + remainingSec * 1000

    scheduleEndNotification(defaults: defaults, prefix: prefix, secondsFromNow: remainingSec)

    defaults.set("false", forKey: "\(prefix)_isPaused")
    defaults.set("0", forKey: "\(prefix)_remainingSeconds")
    defaults.set(String(endMs), forKey: "\(prefix)_endDateMs")
    writeSync(defaults, action: "resume", endDateMs: endMs, remainingMs: 0)

    await activity.update(ActivityContent(state: .init(), staleDate: nil))
    notifyApp()
  }

  static func cancel() async {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: [notificationId])
    if let activity = currentActivity() {
      await activity.end(ActivityContent(state: .init(), staleDate: nil),
                         dismissalPolicy: .immediate)
    }
    writeSync(defaults, action: "cancel", endDateMs: 0, remainingMs: 0)
    notifyApp()
  }

  /// flutter_local_notifications가 예약하던 종료 알림을 동일 identifier("0")로 재예약.
  /// 제목/본문은 타이머 시작 시 Dart가 payload에 실어 둔 번역 문자열을 그대로 쓴다.
  private static func scheduleEndNotification(defaults: UserDefaults, prefix: UUID, secondsFromNow: Int) {
    let content = UNMutableNotificationContent()
    content.title = defaults.string(forKey: "\(prefix)_notifTitle") ?? "조구만 뽀모도로"
    content.body = defaults.string(forKey: "\(prefix)_notifBody") ?? ""
    content.sound = UNNotificationSound(named: UNNotificationSoundName("bip.wav"))
    content.interruptionLevel = .critical
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: TimeInterval(secondsFromNow), repeats: false)
    let request = UNNotificationRequest(
      identifier: notificationId, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
  }

  private static func writeSync(_ defaults: UserDefaults, action: String, endDateMs: Int, remainingMs: Int) {
    defaults.set(action, forKey: "la_sync_action")
    defaults.set(String(endDateMs), forKey: "la_sync_end_date_ms")
    defaults.set(String(remainingMs), forKey: "la_sync_remaining_ms")
  }

  /// 앱이 foreground로 떠 있는 상태에서 버튼이 눌린 경우(Dynamic Island 확장 뷰 등)
  /// Flutter 엔진이 즉시 동기화하도록 같은 프로세스 안에서 핑을 보낸다.
  private static func notifyApp() {
    NotificationCenter.default.post(name: syncChangedNotification, object: nil)
  }
}

@available(iOS 17.0, *)
struct PauseTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Pause Timer"
  func perform() async throws -> some IntentResult {
    await TimerControlHandler.pause()
    return .result()
  }
}

@available(iOS 17.0, *)
struct ResumeTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Resume Timer"
  func perform() async throws -> some IntentResult {
    await TimerControlHandler.resume()
    return .result()
  }
}

@available(iOS 17.0, *)
struct CancelTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Cancel Timer"
  func perform() async throws -> some IntentResult {
    await TimerControlHandler.cancel()
    return .result()
  }
}
```

- [ ] **Step 3: pbxproj에 Shared 그룹과 양쪽 타겟 멤버십 등록**

`ios/Runner.xcodeproj/project.pbxproj`를 편집한다. 24자리 고유 hex ID 6개가 필요하다(기존 ID와 충돌하지 않는 임의 값, 예: `5A11AA0100000000000000B1` 형식으로 생성).

PBXBuildFile 섹션(파일 상단 `/* Begin PBXBuildFile section */` 안)에 4줄 추가:

```
		5A11AA0100000000000000B1 /* LiveActivitiesAppAttributes.swift in Sources */ = {isa = PBXBuildFile; fileRef = 5A11AA0500000000000000F1 /* LiveActivitiesAppAttributes.swift */; };
		5A11AA0200000000000000B2 /* LiveActivitiesAppAttributes.swift in Sources */ = {isa = PBXBuildFile; fileRef = 5A11AA0500000000000000F1 /* LiveActivitiesAppAttributes.swift */; };
		5A11AA0300000000000000B3 /* TimerControlIntents.swift in Sources */ = {isa = PBXBuildFile; fileRef = 5A11AA0600000000000000F2 /* TimerControlIntents.swift */; };
		5A11AA0400000000000000B4 /* TimerControlIntents.swift in Sources */ = {isa = PBXBuildFile; fileRef = 5A11AA0600000000000000F2 /* TimerControlIntents.swift */; };
```

PBXFileReference 섹션에 2줄 추가:

```
		5A11AA0500000000000000F1 /* LiveActivitiesAppAttributes.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LiveActivitiesAppAttributes.swift; sourceTree = "<group>"; };
		5A11AA0600000000000000F2 /* TimerControlIntents.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TimerControlIntents.swift; sourceTree = "<group>"; };
```

PBXGroup 섹션에 Shared 그룹 추가:

```
		5A11AA0700000000000000A1 /* Shared */ = {
			isa = PBXGroup;
			children = (
				5A11AA0500000000000000F1 /* LiveActivitiesAppAttributes.swift */,
				5A11AA0600000000000000F2 /* TimerControlIntents.swift */,
			);
			path = Shared;
			sourceTree = "<group>";
		};
```

메인 그룹(children에 `Runner`, `LiveActivity` 등이 나열된 최상위 PBXGroup)의 `children`에 `5A11AA0700000000000000A1 /* Shared */,` 추가.

Runner의 Sources 페이즈(`97C146EA1CF9000F007C117D /* Sources */`)의 `files`에 2줄 추가:

```
				5A11AA0100000000000000B1 /* LiveActivitiesAppAttributes.swift in Sources */,
				5A11AA0300000000000000B3 /* TimerControlIntents.swift in Sources */,
```

익스텐션의 Sources 페이즈(`3B21B9AB30289E220069A612 /* Sources */`)의 `files`에 2줄 추가:

```
				5A11AA0200000000000000B2 /* LiveActivitiesAppAttributes.swift in Sources */,
				5A11AA0400000000000000B4 /* TimerControlIntents.swift in Sources */,
```

- [ ] **Step 4: 빌드로 멤버십 검증**

Run: `flutter build ios --debug --no-codesign`
Expected: 빌드 성공. 실패 시 pbxproj ID 충돌/오타를 먼저 의심한다.
(위젯 파일 `JogumanTimerLiveActivity.swift`는 아직 `Link`를 쓰므로 이 시점 컴파일에 영향 없음. Attributes가 sync 폴더에서 빠지고 classic 참조로 바뀌어도 익스텐션이 계속 컴파일되는지 이 빌드가 확인해준다.)

- [ ] **Step 5: 커밋**

```bash
git add ios/Shared ios/LiveActivity ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: LiveActivityIntent 3종 및 공유 Attributes를 양쪽 타겟에 등록"
```

---

### Task 3: 위젯 버튼을 Link에서 Button(intent:)로 교체

**Files:**
- Modify: `ios/LiveActivity/JogumanTimerLiveActivity.swift`

**Interfaces:**
- Consumes: Task 2의 `PauseTimerIntent`/`ResumeTimerIntent`/`CancelTimerIntent`.
- Produces: 앱을 열지 않는 ⏸/▶/✕ 버튼(iOS 17+).

- [ ] **Step 1: controlButtons 교체**

`JogumanTimerLiveActivity.swift`의 `controlButtons(_:)` 전체를 아래로 교체(`Link` 제거):

```swift
  @ViewBuilder
  private func controlButtons(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    if #available(iOS 17.0, *) {
      let isPaused = (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false") == "true"
      HStack(spacing: 12) {
        if isPaused {
          Button(intent: ResumeTimerIntent()) {
            Image(systemName: "play.fill")
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(Color.orange)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        } else {
          Button(intent: PauseTimerIntent()) {
            Image(systemName: "pause.fill")
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(Color.orange)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }
        Button(intent: CancelTimerIntent()) {
          Image(systemName: "xmark")
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.gray.opacity(0.5))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
    }
  }
```

- [ ] **Step 2: 빌드 확인**

Run: `flutter build ios --debug --no-codesign`
Expected: 빌드 성공

- [ ] **Step 3: 커밋**

```bash
git add ios/LiveActivity/JogumanTimerLiveActivity.swift
git commit -m "feat: 위젯 버튼을 딥링크 Link에서 Button(intent:)로 교체"
```

---

### Task 4: AppDelegate — MethodChannel과 NotificationCenter 브리지

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes: Task 2의 스냅샷 키(`la_sync_action`/`la_sync_end_date_ms`/`la_sync_remaining_ms`), NotificationCenter 이름 `"JogumanTimerControlDidChange"`.
- Produces:
  - MethodChannel `com.joguman.pomodoro/live_activity`
  - Dart→Swift `consumeSync` → `["action": String, "endDateMs": String, "remainingMs": String]` 또는 `nil`(스냅샷 없음). 읽은 뒤 키 삭제.
  - Swift→Dart `syncRequested` (인자 없음) — Task 5의 Dart 핸들러가 수신.

- [ ] **Step 1: AppDelegate 수정**

`ios/Runner/AppDelegate.swift`의 클래스 본문에 추가(기존 didFinishLaunching 내용 유지, `GeneratedPluginRegistrant.register(with: self)` 뒤에 채널 설정 삽입):

```swift
@main
@objc class AppDelegate: FlutterAppDelegate {
  private var liveActivityChannel: FlutterMethodChannel?
  private static let appGroupId = "group.com.joguman.pomodoro"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ... 기존 local_notification 설정 코드 그대로 ...

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.joguman.pomodoro/live_activity",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "consumeSync" {
          result(AppDelegate.consumeSyncSnapshot())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      liveActivityChannel = channel

      NotificationCenter.default.addObserver(
        forName: Notification.Name("JogumanTimerControlDidChange"),
        object: nil, queue: .main
      ) { [weak self] _ in
        self?.liveActivityChannel?.invokeMethod("syncRequested", arguments: nil)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func consumeSyncSnapshot() -> [String: String]? {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let action = defaults.string(forKey: "la_sync_action") else { return nil }
    let snapshot = [
      "action": action,
      "endDateMs": defaults.string(forKey: "la_sync_end_date_ms") ?? "0",
      "remainingMs": defaults.string(forKey: "la_sync_remaining_ms") ?? "0",
    ]
    defaults.removeObject(forKey: "la_sync_action")
    defaults.removeObject(forKey: "la_sync_end_date_ms")
    defaults.removeObject(forKey: "la_sync_remaining_ms")
    return snapshot
  }
}
```

- [ ] **Step 2: 빌드 확인**

Run: `flutter build ios --debug --no-codesign`
Expected: 빌드 성공

- [ ] **Step 3: 커밋**

```bash
git add ios/Runner/AppDelegate.swift
git commit -m "feat: Live Activity 동기화 MethodChannel 및 프로세스 내 핑 브리지 추가"
```

---

### Task 5: Dart 연동 — consumeSync 반영, 딥링크 제거, 자연 종료 보완

**Files:**
- Modify: `lib/services/live_activity_service.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/utility.dart`
- Modify: `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: Task 4의 채널 `com.joguman.pomodoro/live_activity`(`consumeSync`/`syncRequested`), Task 1의 `reconcileFromSync`/`parseLiveActivityAction`.
- Produces:
  - `LiveActivityService.consumeSync()` → `Future<Map<String, String>?>`
  - `LiveActivityService.setNativePingListener(void Function()? onPing)`
  - `HomeScreen._syncFromNative()` — resumed 및 네이티브 핑 양쪽에서 호출되는 단일 동기화 경로.

- [ ] **Step 1: LiveActivityService에서 딥링크 제거 + 채널 추가**

`lib/services/live_activity_service.dart`에서:

`import 'package:live_activities/models/url_scheme_data.dart';` 삭제, `import 'package:flutter/services.dart';` 추가.

`urlScheme` 상수, `urlSchemeStream` getter 삭제. `init`의 plugin 호출을 `await _plugin.init(appGroupId: appGroupId);`로 변경.

클래스에 추가:

```dart
  static const MethodChannel _syncChannel =
      MethodChannel('com.joguman.pomodoro/live_activity');

  /// Swift Intent가 남긴 동기화 스냅샷을 읽고 비운다. 없으면 null.
  Future<Map<String, String>?> consumeSync() async {
    if (!Platform.isIOS) return null;
    final raw = await _syncChannel.invokeMethod<Map>('consumeSync');
    return raw?.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  /// 앱 실행 중 버튼이 눌렸을 때 네이티브가 보내는 핑 수신.
  void setNativePingListener(void Function()? onPing) {
    if (!Platform.isIOS) return;
    _syncChannel.setMethodCallHandler((call) async {
      if (call.method == 'syncRequested') onPing?.call();
    });
  }
```

- [ ] **Step 2: home_screen 딥링크 리스너를 _syncFromNative로 교체**

`lib/screens/home_screen.dart`에서:

`StreamSubscription<UrlSchemeData>? _urlSchemeSub;` 필드와 `import ...url_scheme_data...`(있다면), `dart:async`의 미사용 import 삭제.

initState의 urlSchemeStream 구독을 아래로 교체:

```dart
    LiveActivityService.instance.setNativePingListener(() => _syncFromNative());
```

dispose의 `await _urlSchemeSub?.cancel();`를 아래로 교체:

```dart
    LiveActivityService.instance.setNativePingListener(null);
```

`_handleLiveActivityAction` 메서드 전체를 아래로 교체:

```dart
  Future<void> _syncFromNative() async {
    final sync = await LiveActivityService.instance.consumeSync();
    if (sync == null || !mounted) return;
    final result = reconcileFromSync(
      action: parseLiveActivityAction(sync['action'] ?? ''),
      endDateMs: int.tryParse(sync['endDateMs'] ?? '') ?? 0,
      remainingMs: int.tryParse(sync['remainingMs'] ?? '') ?? 0,
      now: DateTime.now(),
    );
    if (result.kind == ReconcileKind.none) return;
    final data = context.read<DataProvider>();
    data.setLeaveDateTime(null); // 이후 setTimerByLifecycle의 중복 복원 차단
    switch (result.kind) {
      case ReconcileKind.pausedAway:
        data.cancleTimer();
        data.setCurrSec((result.newMillisec / 1000).ceil(),
            milliseconds: result.newMillisec);
        context
            .read<AngleProvider>()
            .setAngle(result.newMillisec / 3600000 * 2 * math.pi);
        break;
      case ReconcileKind.runningAway:
        data.setCurrSec((result.newMillisec / 1000).ceil(),
            milliseconds: result.newMillisec);
        context
            .read<AngleProvider>()
            .setAngle(result.newMillisec / 3600000 * 2 * math.pi);
        data.setMyTimer(context);
        break;
      case ReconcileKind.finishedAway:
        data.cancleTimer();
        data.setCurrSec(0, milliseconds: 0);
        context.read<AngleProvider>().setAngle(0);
        LiveActivityService.instance.end();
        break;
      case ReconcileKind.cancelledAway:
        data.cancelAndReset();
        context
            .read<AngleProvider>()
            .setAngle(data.startSec / 3600 * 2 * math.pi);
        break;
      case ReconcileKind.none:
        break;
    }
  }
```

`didChangeAppLifecycleState`의 resumed 분기 첫 줄(`final skin = ...` 앞)에 추가:

```dart
      await _syncFromNative();
```

- [ ] **Step 3: 백그라운드 자연 종료 시 활동 종료 보완**

`lib/utility.dart`의 `setTimerByLifecycle`에서 `newSec <= 0` 분기에 한 줄 추가(백그라운드에서 타이머가 다 지나 돌아온 경우 위젯이 00:00으로 남는 기존 공백 보완):

```dart
    if (newSec <= 0) {
      newSec = 0;
      context.read<DataProvider>().setCurrSec(newSec, milliseconds: newMillisec);
      context.read<AngleProvider>().setAngle(0);
      LiveActivityService.instance.end();
    } else {
```

파일 상단에 `import 'package:joguman_pomodoro/services/live_activity_service.dart';` 추가(기존 import 스타일에 맞춤).

- [ ] **Step 4: Info.plist에서 URL scheme 제거**

`ios/Runner/Info.plist`에서 `CFBundleURLTypes` 키와 그 `<array>...</array>` 블록 전체 삭제(`NSSupportsLiveActivities`는 유지).

- [ ] **Step 5: 정적 분석 + 회귀 테스트 + 빌드**

Run: `flutter analyze lib && flutter test && flutter build ios --debug --no-codesign`
Expected: 신규 analyze 이슈 0, 테스트 기존과 동일, 빌드 성공

- [ ] **Step 6: 커밋**

```bash
git add lib ios/Runner/Info.plist
git commit -m "feat: 네이티브 동기화 반영 및 딥링크 경로 제거"
```

---

### Task 6: 실기기 수동 검증

**Files:** 없음(검증 전용). 통과 후 진단 로그 제거는 별도 커밋.

**사전 조건:** entitlements/Info.plist가 바뀌었으므로 기기에서 **앱 완전 삭제 후 재설치**(과거 `ActivityInput 오류 0` 재발 방지).

- [ ] 타이머 시작 → 잠금화면 카운트다운 표시, 앱 종료 상태에서도 매초 감소.
- [ ] ⏸ 탭 → **앱이 열리지 않고** 위젯이 고정 시간 + ▶로 전환. 이후 종료 예정 시각에 알림이 오지 않아야 함.
- [ ] ▶ 탭 → 앱이 열리지 않고 카운트다운 재개. 재개된 종료 시각에 알림(bip 사운드)이 울려야 함.
- [ ] ✕ 탭 → 앱이 열리지 않고 위젯 제거, 알림도 오지 않아야 함.
- [ ] 위젯에서 ⏸ 후 앱 열기 → 앱 타이머가 일시정지 상태(남은 시간 일치, 재생 버튼 표시)로 맞춰져 있어야 함.
- [ ] 위젯에서 ✕ 후 앱 열기 → 앱 타이머가 시작값으로 리셋되어 있어야 함.
- [ ] 앱 foreground 상태에서 Dynamic Island 확장 뷰의 ⏸ 탭 → 앱 화면 타이머가 즉시 일시정지로 반영(네이티브 핑 경로).
- [ ] 앱 내 정지/재생 버튼도 기존대로 위젯과 동기화되는지 확인(회귀).
- [ ] 검증 통과 후: `lib/services/live_activity_service.dart`의 `[LA]` 진단 로그 제거 후 커밋:

```bash
git add lib/services/live_activity_service.dart
git commit -m "chore: Live Activity 진단 로그 제거"
```

---

## Self-Review

- 스펙 커버리지: 버튼 무열림 전환(Task 2·3), 알림 취소/재예약(Task 2), Dart 상태 동기화 — 백그라운드 복귀(Task 5 resumed)와 foreground 즉시 반영(Task 2 notifyApp → Task 4 브리지 → Task 5 핑 리스너) 모두 포함. 딥링크 제거 완료(Task 5). 자연 종료 위젯 잔존 공백 보완(Task 5 Step 3).
- 타입 일관성: 채널명 `com.joguman.pomodoro/live_activity`, 메서드 `consumeSync`/`syncRequested`, 스냅샷 키 `la_sync_action`/`la_sync_end_date_ms`/`la_sync_remaining_ms`, NotificationCenter 이름 `JogumanTimerControlDidChange`가 Task 2·4·5에서 동일함을 확인.
- 알려진 한계: 앱이 완전 종료된 상태에서 인텐트가 백그라운드로 앱을 깨울 때의 동작(알림 재예약 포함)은 실기기에서만 검증 가능 — Task 6에 포함. `ContentState`가 빈 구조체라 `activity.update`가 동일 상태로 호출되는데, 플러그인도 같은 방식으로 동작 중이므로(검증 완료) 재렌더링에 문제 없음.
