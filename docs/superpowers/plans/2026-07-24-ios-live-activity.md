# iOS 잠금화면 타이머 (Live Activity) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 잠금화면과 Dynamic Island에 뽀모도로 타이머의 실시간 카운트다운과 일시정지/취소 버튼을 표시한다.

**Architecture:** SwiftUI `Text(timerInterval:)`가 종료 시각 기준으로 카운트다운을 시스템 레벨에서 자동으로 그린다(백그라운드 실행 불필요). 앱은 시작/일시정지/재개/취소/종료 시점에만 Live Activity를 갱신한다. 버튼은 URL scheme 딥링크로 앱을 열어 기존 Dart 타이머 로직이 처리한다(타이머 제어 로직은 Dart 단일 소스). Flutter↔ActivityKit 다리는 `live_activities` 패키지.

**Tech Stack:** Flutter/Dart, `live_activities` 패키지, Swift/SwiftUI(ActivityKit, WidgetKit), App Group UserDefaults, easy_localization, Provider.

## Global Constraints

- iOS 전용 기능. iOS 16.1+에서 Live Activity 표시. 버튼(⏸/✕)은 iOS 17.0+에서만 노출·동작. Android는 이번 범위 밖(no-op).
- 모든 Live Activity 코드는 비 iOS 환경에서 no-op. 기존 90개 테스트는 그대로 통과 유지.
- App Group ID: `group.com.joguman.pomodoro` (Runner + Widget Extension 양쪽).
- URL scheme: `joguman` (딥링크: `joguman:///pause`, `joguman:///resume`, `joguman:///cancel`).
- 번들 ID: `com.joguman.pomodoro`. 대상 버전: `1.0.7+20`.
- App Group UserDefaults는 문자열만 저장. 모든 payload 값은 문자열로 변환해 전달.
- .md 문서는 표 없이 리스트로 간결하게.

## 파일 구조

- Create `lib/services/live_activity_payload.dart` — 순수 함수: payload 맵 빌더 + 딥링크 액션 파서. 유일하게 완전 단위 테스트 가능.
- Create `lib/services/live_activity_service.dart` — `live_activities` 패키지 래퍼(싱글턴). start/pause/end + urlSchemeStream. 비 iOS no-op.
- Modify `lib/providers/data_provider.dart` — setMyTimer에 Live Activity 시작/갱신 훅, 자연 종료 시 end, `pauseTimer()`/`cancelAndReset()` 추가.
- Modify `lib/screens/home_screen.dart` — 딥링크 리스너, 바텀 버튼 pause 연결.
- Modify `lib/widgets/pomodoro_cast.dart` — 다이얼 조작 시 Live Activity 종료.
- Modify `lib/main.dart` — 시작 시 서비스 init.
- Modify `assets/translations/*.json` — `live_activity_title` 키 추가.
- Modify `pubspec.yaml` — `live_activities` 의존성 추가, 버전 `1.0.7+20`.
- Create (Xcode GUI) Widget Extension 타겟 `LiveActivity` — Swift 3파일 + Info.plist + entitlements.
- Modify `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements` — NSSupportsLiveActivities, URL scheme, App Group.
- Create test `test/services/live_activity_payload_test.dart`.

---

### Task 1: 순수 로직 — payload 빌더 + 딥링크 파서 (TDD)

**Files:**
- Create: `lib/services/live_activity_payload.dart`
- Test: `test/services/live_activity_payload_test.dart`

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `enum LiveActivityAction { pause, resume, cancel, unknown }`
  - `Map<String, dynamic> buildRunningPayload({required DateTime endDate, required String label})`
  - `Map<String, dynamic> buildPausedPayload({required int remainingSeconds, required String label})`
  - `LiveActivityAction parseLiveActivityAction(String path)`
  - payload 키: `endDateMs`, `isPaused`, `remainingSeconds`, `label` (모두 문자열 값)

- [ ] **Step 1: 실패하는 테스트 작성**

`test/services/live_activity_payload_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/services/live_activity_payload.dart';

void main() {
  group('buildRunningPayload', () {
    test('종료시각을 epoch ms 문자열로, isPaused는 false로 담는다', () {
      final end = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final map = buildRunningPayload(endDate: end, label: '집중');

      expect(map['endDateMs'], '1700000000000');
      expect(map['isPaused'], 'false');
      expect(map['label'], '집중');
      expect(map['remainingSeconds'], '0');
      // 모든 값은 문자열이어야 한다 (App Group UserDefaults 제약)
      expect(map.values.every((v) => v is String), isTrue);
    });
  });

  group('buildPausedPayload', () {
    test('남은 초를 문자열로, isPaused는 true로 담는다', () {
      final map = buildPausedPayload(remainingSeconds: 125, label: '집중');

      expect(map['isPaused'], 'true');
      expect(map['remainingSeconds'], '125');
      expect(map['label'], '집중');
      expect(map['endDateMs'], '0');
      expect(map.values.every((v) => v is String), isTrue);
    });
  });

  group('parseLiveActivityAction', () {
    test('경로를 액션으로 매핑', () {
      expect(parseLiveActivityAction('/pause'), LiveActivityAction.pause);
      expect(parseLiveActivityAction('/resume'), LiveActivityAction.resume);
      expect(parseLiveActivityAction('/cancel'), LiveActivityAction.cancel);
    });

    test('알 수 없는 경로는 unknown', () {
      expect(parseLiveActivityAction('/foo'), LiveActivityAction.unknown);
      expect(parseLiveActivityAction(''), LiveActivityAction.unknown);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/services/live_activity_payload_test.dart`
Expected: FAIL — `live_activity_payload.dart` 없음 / 심볼 미정의로 컴파일 에러.

- [ ] **Step 3: 최소 구현 작성**

`lib/services/live_activity_payload.dart`:
```dart
/// Live Activity 페이로드 생성 및 딥링크 파싱 (순수 함수).
/// App Group UserDefaults는 문자열만 저장하므로 모든 값을 문자열로 변환한다.

enum LiveActivityAction { pause, resume, cancel, unknown }

/// 실행 중(카운트다운) 상태 페이로드.
Map<String, dynamic> buildRunningPayload({
  required DateTime endDate,
  required String label,
}) {
  return {
    'endDateMs': endDate.millisecondsSinceEpoch.toString(),
    'isPaused': 'false',
    'remainingSeconds': '0',
    'label': label,
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

/// 딥링크 path(예: '/pause')를 액션으로 변환.
LiveActivityAction parseLiveActivityAction(String path) {
  switch (path) {
    case '/pause':
      return LiveActivityAction.pause;
    case '/resume':
      return LiveActivityAction.resume;
    case '/cancel':
      return LiveActivityAction.cancel;
    default:
      return LiveActivityAction.unknown;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/services/live_activity_payload_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: 커밋**

```bash
git add lib/services/live_activity_payload.dart test/services/live_activity_payload_test.dart
git commit -m "feat: Live Activity payload 빌더 및 딥링크 파서 추가"
```

---

### Task 2: LiveActivityService 래퍼 + 패키지 추가

**Files:**
- Modify: `pubspec.yaml` (dependencies에 `live_activities` 추가)
- Create: `lib/services/live_activity_service.dart`

**Interfaces:**
- Consumes: Task 1의 `buildRunningPayload`, `buildPausedPayload`.
- Produces:
  - `LiveActivityService.instance` (싱글턴)
  - `Future<void> init()`
  - `Stream<UrlSchemeData> get urlSchemeStream`
  - `Future<void> startOrUpdateRunning({required DateTime endDate, required String label})`
  - `Future<void> updatePaused({required int remainingSeconds, required String label})`
  - `Future<void> end()`
  - 상수 `appGroupId = 'group.com.joguman.pomodoro'`, `urlScheme = 'joguman'`

- [ ] **Step 1: 패키지 추가**

`pubspec.yaml`의 `dependencies:` 블록에서 `app_badge_plus: ^1.2.3` 아래 줄에 추가:
```yaml
  live_activities: ^2.5.1
```

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: 설치된 패키지 API 시그니처 확인**

Run: `grep -n "Future<String?> createActivity\|Future<void> updateActivity\|Future<void> endActivity\|Stream<UrlSchemeData> urlSchemeStream\|Future<bool> areActivitiesEnabled\|Future<void> init" ~/.pub-cache/hosted/pub.dev/live_activities-*/lib/live_activities.dart`
Expected: 아래 시그니처와 일치 확인. 다르면 Step 3 코드를 설치본에 맞게 조정한다.
- `createActivity(String activityId, Map<String, dynamic> data, {...})` → `Future<String?>`
- `updateActivity(String activityId, Map<String, dynamic> data, {...})`
- `endActivity(String activityId, {...})`
- `init({required String appGroupId, String? urlScheme, ...})`
- `areActivitiesEnabled()` → `Future<bool>`
- `urlSchemeStream()` → `Stream<UrlSchemeData>`

- [ ] **Step 3: 서비스 구현 작성**

`lib/services/live_activity_service.dart`:
```dart
import 'dart:io';

import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/url_scheme_data.dart';

import 'live_activity_payload.dart';

/// live_activities 패키지 래퍼. iOS 외/미지원 환경에서는 모든 메서드가 no-op.
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const String appGroupId = 'group.com.joguman.pomodoro';
  static const String urlScheme = 'joguman';

  final LiveActivities _plugin = LiveActivities();
  String? _activityId;
  bool _initialized = false;

  Future<void> init() async {
    if (!Platform.isIOS) return;
    await _plugin.init(appGroupId: appGroupId, urlScheme: urlScheme);
    _initialized = true;
  }

  Stream<UrlSchemeData> get urlSchemeStream => _plugin.urlSchemeStream();

  Future<bool> _enabled() async {
    if (!Platform.isIOS || !_initialized) return false;
    return _plugin.areActivitiesEnabled();
  }

  /// 실행 중 상태로 시작(없으면 생성) 또는 갱신.
  Future<void> startOrUpdateRunning({
    required DateTime endDate,
    required String label,
  }) async {
    if (!await _enabled()) return;
    final data = buildRunningPayload(endDate: endDate, label: label);
    if (_activityId == null) {
      _activityId = await _plugin.createActivity(
        DateTime.now().millisecondsSinceEpoch.toString(),
        data,
      );
    } else {
      await _plugin.updateActivity(_activityId!, data);
    }
  }

  /// 일시정지 상태로 갱신.
  Future<void> updatePaused({
    required int remainingSeconds,
    required String label,
  }) async {
    if (!await _enabled() || _activityId == null) return;
    await _plugin.updateActivity(
      _activityId!,
      buildPausedPayload(remainingSeconds: remainingSeconds, label: label),
    );
  }

  /// 활동 종료 및 제거.
  Future<void> end() async {
    if (!Platform.isIOS || _activityId == null) return;
    await _plugin.endActivity(_activityId!);
    _activityId = null;
  }
}
```

Note: `url_scheme_data.dart` import 경로는 Step 2에서 확인한 설치본 구조에 맞춘다. `UrlSchemeData`가 `package:live_activities/live_activities.dart`에서 이미 export되면 두 번째 import는 삭제한다.

- [ ] **Step 4: 정적 분석 통과 확인**

Run: `flutter analyze lib/services/live_activity_service.dart`
Expected: `No issues found!` (경고 0).

- [ ] **Step 5: 기존 테스트 회귀 없음 확인**

Run: `flutter test`
Expected: 기존과 동일하게 90 passed, 1 failed(`widget_test.dart`의 기본 템플릿 테스트 — 사전 존재 실패, 무관). Task 1 테스트 5개 추가 통과.

- [ ] **Step 6: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib/services/live_activity_service.dart
git commit -m "feat: live_activities 패키지 추가 및 LiveActivityService 래퍼 구현"
```

---

### Task 3: DataProvider 연동 + 번역 키

**Files:**
- Modify: `lib/providers/data_provider.dart`
- Modify: `assets/translations/en.json`, `ko.json`, `ja.json`, `zh-Hans.json`, `zh-Hant.json`

**Interfaces:**
- Consumes: Task 2의 `LiveActivityService.instance` (startOrUpdateRunning/updatePaused/end).
- Produces:
  - `Future<void> pauseTimer()` — cancleTimer + Live Activity를 일시정지로 갱신.
  - `Future<void> cancelAndReset()` — cancleTimer + currSec/currMillisec를 startSec로 복원 + Live Activity 종료. (다이얼 각도 복원은 호출 측 담당)
  - setMyTimer는 시작/재개 시 Live Activity를 실행 상태로 시작·갱신하고, 자연 종료 시 종료한다.
  - 번역 키 `live_activity_title`.

- [ ] **Step 1: 번역 키 추가**

`assets/translations/ko.json`을 아래로 교체:
```json
{
    "app_name" : "조구만 뽀모도로 타이머",
    "end_message" : "🦕 : 끝! 잠깐 쉬어가요.",
    "live_activity_title" : "집중"
}
```

`assets/translations/en.json`:
```json
{
    "app_name" : "Joguman Pomodoro Timer",
    "end_message" : "🦕 : Time's up! Let's take a short break.",
    "live_activity_title" : "Focus"
}
```

`assets/translations/ja.json`:
```json
{
    "app_name" : "ジョグマン・ポモドーロ・タイマー",
    "end_message" : "🦕 : おしまい！ちょっと休憩しよう.",
    "live_activity_title" : "集中"
}
```

`assets/translations/zh-Hans.json`:
```json
{
    "app_name" : "乔古漫 番茄钟计时器",
    "end_message" : "🦕 : 完成啦！休息一下吧。",
    "live_activity_title" : "专注"
}
```

`assets/translations/zh-Hant.json`:
```json
{
    "app_name" : "乔古漫 番茄鐘計時器",
    "end_message" : "🦕 : 完成囉！休息一下吧。",
    "live_activity_title" : "專注"
}
```

- [ ] **Step 2: import 추가**

`lib/providers/data_provider.dart` 상단 import 블록(`import '../utility.dart';` 위)에 추가:
```dart
import '../services/live_activity_service.dart';
```

- [ ] **Step 3: setMyTimer에 실행 상태 시작 훅 추가**

`lib/providers/data_provider.dart`에서 알림 스케줄 직후(`if (isGranted) setScheduleNotification(...)` 줄 바로 아래, `} else {` 위)에 추가:
```dart
      LiveActivityService.instance.startOrUpdateRunning(
        endDate: alarmDate,
        label: 'live_activity_title'.tr(),
      );
```
(여기서 `alarmDate`는 같은 블록 상단에서 선언된 `DateTime.now().add(Duration(milliseconds: currMillisec))` 지역 변수다.)

- [ ] **Step 4: 자연 종료 시 Live Activity 종료 훅 추가**

같은 파일 periodic 콜백의 `if (currMillisec <= 0) {` 블록 안, `isStarted = false;` 아래에 추가:
```dart
            LiveActivityService.instance.end();
```

- [ ] **Step 5: pauseTimer / cancelAndReset 메서드 추가**

`cancleTimer()` 메서드 정의 바로 아래에 추가:
```dart
  /// 일시정지: 타이머 정지(남은 시간 유지) + Live Activity를 일시정지 상태로 갱신.
  Future<void> pauseTimer() async {
    cancleTimer();
    await LiveActivityService.instance.updatePaused(
      remainingSeconds: (currMillisec / 1000).ceil(),
      label: 'live_activity_title'.tr(),
    );
    notifyListeners();
  }

  /// 취소: 타이머 종료 + 남은 시간을 시작값(startSec)으로 복원 + Live Activity 제거.
  /// 다이얼 각도 복원은 context를 가진 호출 측에서 처리한다.
  Future<void> cancelAndReset() async {
    cancleTimer();
    currSec = startSec;
    currMillisec = startSec * 1000;
    await LiveActivityService.instance.end();
    notifyListeners();
  }
```

- [ ] **Step 6: 정적 분석 + 회귀 테스트**

Run: `flutter analyze lib/providers/data_provider.dart && flutter test`
Expected: `No issues found!`; 테스트는 Task 2와 동일 결과(90 passed + Task1 5개, 1 pre-existing fail). 비 iOS 테스트 환경에서 서비스는 no-op이므로 DataProvider 관련 테스트 영향 없음.

- [ ] **Step 7: 커밋**

```bash
git add lib/providers/data_provider.dart assets/translations
git commit -m "feat: DataProvider에 Live Activity 시작/일시정지/취소 훅 및 번역 키 추가"
```

---

### Task 4: 앱 초기화 · 딥링크 리스너 · 바텀버튼/다이얼 연결

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/widgets/pomodoro_cast.dart`

**Interfaces:**
- Consumes: Task 2 `LiveActivityService.instance.init()` / `urlSchemeStream` / `end()`; Task 1 `parseLiveActivityAction` / `LiveActivityAction`; Task 3 `pauseTimer` / `cancelAndReset`.
- Produces: 딥링크 수신 시 pause/resume/cancel 동작. 바텀 "정지" 버튼 → pauseTimer. 다이얼 조작 시 Live Activity 종료.

- [ ] **Step 1: main.dart에서 서비스 초기화**

`lib/main.dart` 상단 import에 추가:
```dart
import 'package:joguman_pomodoro/services/live_activity_service.dart';
```
`main()`에서 `await _initLocalNotification();` 아래 줄에 추가:
```dart
  await LiveActivityService.instance.init();
```

- [ ] **Step 2: home_screen.dart 딥링크 리스너 추가**

`lib/screens/home_screen.dart` 상단 import에 추가:
```dart
import 'package:joguman_pomodoro/providers/angle_provider.dart';
import 'package:joguman_pomodoro/services/live_activity_service.dart';
import 'package:joguman_pomodoro/services/live_activity_payload.dart';
```
`HomeScreenState` 클래스 필드에 추가(`int themeIndex = 0;` 아래):
```dart
  StreamSubscription<UrlSchemeData>? _urlSchemeSub;
```
`UrlSchemeData` 타입을 위해 import 추가:
```dart
import 'package:live_activities/models/url_scheme_data.dart';
```
`initState()`의 `initFunc();` 아래에 추가:
```dart
    _urlSchemeSub = LiveActivityService.instance.urlSchemeStream.listen((data) {
      _handleLiveActivityAction(parseLiveActivityAction(data.path ?? ''));
    });
```
`dispose()`의 `WidgetsBinding.instance.removeObserver(this);` 아래에 추가:
```dart
    await _urlSchemeSub?.cancel();
```

- [ ] **Step 3: 딥링크 액션 핸들러 추가**

`HomeScreenState`에 메서드 추가(`dispose()` 아래 아무 곳):
```dart
  void _handleLiveActivityAction(LiveActivityAction action) {
    if (!mounted) return;
    final data = context.read<DataProvider>();
    switch (action) {
      case LiveActivityAction.pause:
        data.pauseTimer();
        break;
      case LiveActivityAction.resume:
        data.setMyTimer(context);
        if (data.startSec > 0) data.setIsStarted(true);
        break;
      case LiveActivityAction.cancel:
        data.cancelAndReset();
        context.read<AngleProvider>().setAngle(data.startSec / 3600 * 2 * math.pi);
        break;
      case LiveActivityAction.unknown:
        break;
    }
  }
```
(`math`는 파일 상단에 `import 'dart:math' as math;`로 이미 존재.)

- [ ] **Step 4: 바텀 버튼 "정지"를 pauseTimer로 변경**

`lib/screens/home_screen.dart`의 GestureDetector onTap(약 366행):
```dart
              if (myTimer != null && myTimer.isActive) {
                context.read<DataProvider>().cancleTimer();
                context.read<DataProvider>().setIsStarted(false);
              } else {
```
를 다음으로 변경:
```dart
              if (myTimer != null && myTimer.isActive) {
                context.read<DataProvider>().pauseTimer();
              } else {
```
(pauseTimer 내부의 cancleTimer가 isStarted=false로 설정하고 notify하므로 동작 동일 + Live Activity 일시정지 갱신 추가.)

- [ ] **Step 5: 다이얼 조작 시 Live Activity 종료**

`lib/widgets/pomodoro_cast.dart` 상단 import에 추가:
```dart
import 'package:joguman_pomodoro/services/live_activity_service.dart';
```
`onPanUpdate`의 `context.read<DataProvider>().cancleTimer();`(약 80행) 아래에 추가:
```dart
    LiveActivityService.instance.end();
```
(사용자가 다이얼로 새 시간을 맞추면 실행 중이던 Live Activity를 제거. end()는 활동이 없으면 즉시 반환하므로 반복 호출 안전.)

- [ ] **Step 6: 정적 분석 + 회귀 테스트**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; 테스트 결과 Task 3과 동일(회귀 없음).

- [ ] **Step 7: 커밋**

```bash
git add lib/main.dart lib/screens/home_screen.dart lib/widgets/pomodoro_cast.dart
git commit -m "feat: Live Activity 딥링크 처리 및 앱 초기화/버튼 연결"
```

---

### Task 5: iOS Widget Extension 타겟 · App Group · URL scheme 설정 (Xcode GUI)

이 태스크는 Xcode GUI 조작이 필요하다. 각 단계의 정확한 값과 붙여넣을 파일 내용을 그대로 사용한다. 완료 기준은 "Live Activity Extension이 포함된 앱이 실기기에 빌드·설치된다".

**Files:**
- Create (Xcode 템플릿 후 내용 교체): `ios/LiveActivity/LiveActivitiesAppAttributes.swift`, `ios/LiveActivity/LiveActivityBundle.swift`, `ios/LiveActivity/JogumanTimerLiveActivity.swift`(내용은 Task 6), `ios/LiveActivity/Info.plist`
- Modify: `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`
- Create: `ios/LiveActivity/LiveActivity.entitlements`

**Interfaces:**
- Consumes: Task 1이 정한 payload 키(`endDateMs`/`isPaused`/`remainingSeconds`/`label`), App Group `group.com.joguman.pomodoro`, URL scheme `joguman`.
- Produces: 시스템에 등록된 Live Activity Widget. Runner의 UserDefaults(App Group)로 payload 수신.

- [ ] **Step 1: Widget Extension 타겟 생성**

Xcode에서 `ios/Runner.xcworkspace` 열기 → File > New > Target > **Widget Extension** 선택 → Product Name: `LiveActivity`, "Include Live Activity" 체크, "Include Configuration App Intent" 체크 해제 → Finish → "Activate scheme?"는 Cancel. 생성 폴더가 `ios/LiveActivity/`인지 확인.

- [ ] **Step 2: 최소 배포 타겟 설정**

`LiveActivity` 타겟 선택 > General > Minimum Deployments > iOS **16.1**.

- [ ] **Step 3: App Group capability 추가 (양쪽 타겟)**

`Runner` 타겟 > Signing & Capabilities > + Capability > **App Groups** > `group.com.joguman.pomodoro` 추가.
`LiveActivity` 타겟에도 동일하게 App Groups > `group.com.joguman.pomodoro` 추가.
결과로 `ios/Runner/Runner.entitlements`와 `ios/LiveActivity/LiveActivity.entitlements`에 아래가 포함되어야 한다:
```xml
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.joguman.pomodoro</string>
	</array>
```
`ios/Runner/Runner.entitlements`가 비어 있던 `<dict/>`였다면 위 키를 가진 `<dict>...</dict>`로 채워졌는지 확인.

- [ ] **Step 4: Runner Info.plist에 NSSupportsLiveActivities + URL scheme 추가**

`ios/Runner/Info.plist`의 최상위 `<dict>` 안에 추가:
```xml
	<key>NSSupportsLiveActivities</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>com.joguman.pomodoro</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>joguman</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 5: LiveActivity Extension Info.plist에 NSSupportsLiveActivities 추가**

`ios/LiveActivity/Info.plist`의 최상위 `<dict>` 안에 추가:
```xml
	<key>NSSupportsLiveActivities</key>
	<true/>
```

- [ ] **Step 6: Attributes / Bundle Swift 파일 작성**

Xcode 템플릿이 만든 파일들을 아래로 교체(또는 신규 생성 후 `LiveActivity` 타겟 멤버십 체크). 템플릿 기본 위젯 파일(예: `LiveActivityLiveActivity.swift`, `LiveActivity.swift`)은 삭제한다.

`ios/LiveActivity/LiveActivitiesAppAttributes.swift`:
```swift
import ActivityKit
import Foundation

// live_activities 패키지 규약상 이름은 반드시 LiveActivitiesAppAttributes 여야 한다.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  public struct ContentState: Codable, Hashable {}
  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    return "\(id)_\(key)"
  }
}
```

`ios/LiveActivity/LiveActivityBundle.swift`:
```swift
import SwiftUI
import WidgetKit

@main
struct LiveActivityBundle: WidgetBundle {
  var body: some Widget {
    JogumanTimerLiveActivity()
  }
}
```

`ios/LiveActivity/JogumanTimerLiveActivity.swift` — 이 태스크에서는 빌드 확인용 최소 버전으로 작성(정식 UI는 Task 6):
```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct JogumanTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      Text("타이머")
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) { Text("타이머") }
      } compactLeading: {
        Image(systemName: "timer")
      } compactTrailing: {
        Image(systemName: "timer")
      } minimal: {
        Image(systemName: "timer")
      }
    }
  }
}
```

- [ ] **Step 7: 빌드 확인 (실기기)**

Run: `flutter build ios --debug --no-codesign` 로 컴파일 성공 확인(코드사인 없이 컴파일만). 이후 실기기 설치는 Xcode에서 개발자 계정으로 Run.
Expected: 빌드 성공. 앱 실행 → 타이머 시작 → 잠금화면/Dynamic Island에 "타이머" 최소 위젯이 뜨는지 확인(카운트다운·버튼은 Task 6에서).
주의: Live Activity는 시뮬레이터 제약이 있어 **실기기 확인 필수**.

- [ ] **Step 8: 커밋**

```bash
git add ios/
git commit -m "feat: iOS Live Activity Widget Extension 타겟 및 App Group/URL scheme 설정"
```

---

### Task 6: SwiftUI Live Activity 위젯 UI

**Files:**
- Modify: `ios/LiveActivity/JogumanTimerLiveActivity.swift`

**Interfaces:**
- Consumes: App Group UserDefaults의 payload 키(`endDateMs`/`isPaused`/`remainingSeconds`/`label`), 딥링크 `joguman:///pause|resume|cancel`.
- Produces: 카운트다운 표시(자동 tick) + 일시정지 시 고정 표시 + iOS 17+ 조작 버튼.

- [ ] **Step 1: 정식 위젯 UI로 교체**

`ios/LiveActivity/JogumanTimerLiveActivity.swift` 전체를 아래로 교체:
```swift
import ActivityKit
import SwiftUI
import WidgetKit

private let sharedDefault = UserDefaults(suiteName: "group.com.joguman.pomodoro")!

struct JogumanTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      lockScreenView(context)
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          controlButtons(context)
        }
        DynamicIslandExpandedRegion(.trailing) {
          timerText(context)
            .font(.title2).monospacedDigit()
            .foregroundColor(.orange)
        }
      } compactLeading: {
        Image(systemName: "timer").foregroundColor(.orange)
      } compactTrailing: {
        timerText(context)
          .monospacedDigit()
          .foregroundColor(.orange)
          .frame(maxWidth: 60)
      } minimal: {
        Image(systemName: "timer").foregroundColor(.orange)
      }
    }
  }

  @ViewBuilder
  private func lockScreenView(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    let label = sharedDefault.string(forKey: context.attributes.prefixedKey("label")) ?? ""
    HStack {
      controlButtons(context)
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(label)
          .font(.caption)
          .foregroundColor(.orange.opacity(0.9))
        timerText(context)
          .font(.system(size: 40, weight: .semibold))
          .monospacedDigit()
          .foregroundColor(.orange)
      }
    }
    .padding()
  }

  @ViewBuilder
  private func timerText(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    let isPaused = (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false") == "true"
    if isPaused {
      let remaining = Int(sharedDefault.string(forKey: context.attributes.prefixedKey("remainingSeconds")) ?? "0") ?? 0
      Text(formatTime(remaining))
    } else {
      let endMs = Double(sharedDefault.string(forKey: context.attributes.prefixedKey("endDateMs")) ?? "0") ?? 0
      let endDate = Date(timeIntervalSince1970: endMs / 1000.0)
      let start = min(Date(), endDate)
      Text(timerInterval: start...max(endDate, start.addingTimeInterval(1)), countsDown: true)
    }
  }

  @ViewBuilder
  private func controlButtons(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    if #available(iOS 17.0, *) {
      let isPaused = (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false") == "true"
      HStack(spacing: 12) {
        Link(destination: URL(string: isPaused ? "joguman:///resume" : "joguman:///pause")!) {
          Image(systemName: isPaused ? "play.fill" : "pause.fill")
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.orange)
            .clipShape(Circle())
        }
        Link(destination: URL(string: "joguman:///cancel")!) {
          Image(systemName: "xmark")
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.gray.opacity(0.5))
            .clipShape(Circle())
        }
      }
    }
  }

  private func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
  }
}
```

- [ ] **Step 2: 빌드 확인**

Run: `flutter build ios --debug --no-codesign`
Expected: 빌드 성공.

- [ ] **Step 3: 실기기 수동 검증 체크리스트**

iOS 17+ 실기기와 iOS 16.x 실기기(가능하면)에서 확인:
- [ ] 타이머 시작 → 잠금화면에 카운트다운이 매초 자동으로 줄어든다(앱 종료 상태에서도).
- [ ] Dynamic Island(지원 기기)의 compact/expanded에 시간이 표시된다.
- [ ] (iOS 17+) ⏸ 탭 → 앱이 잠깐 열리며 일시정지, 위젯이 고정 시간 + ▶(재생)로 바뀐다.
- [ ] (iOS 17+) ▶ 탭 → 재개, 위젯이 다시 카운트다운.
- [ ] (iOS 17+) ✕ 탭 → 위젯 사라짐, 앱 다이얼이 처음 맞춘 시간으로 복귀.
- [ ] 타이머 자연 종료(0 도달) → 위젯 사라짐 + 기존 알림 정상 동작.
- [ ] (iOS 16.1~16.4) 카운트다운은 표시되고 버튼은 노출되지 않는다.
- [ ] 다이얼로 새 시간 설정 → 실행 중이던 위젯이 사라진다.

발견된 문제는 `_docs/version-update-note/1.0.7+20.md`의 "이슈와 해결"에 기록한다.

- [ ] **Step 4: 커밋**

```bash
git add ios/LiveActivity/JogumanTimerLiveActivity.swift
git commit -m "feat: Live Activity 위젯 UI(카운트다운·일시정지·조작 버튼) 구현"
```

---

### Task 7: 버전 범프 및 팀 공유 문서 업데이트

**Files:**
- Modify: `pubspec.yaml`
- Modify: `_docs/version-update-note/1.0.7+20.md`

**Interfaces:**
- Consumes: Task 1~6 구현 결과와 실기기 검증 내용.
- Produces: 버전 `1.0.7+20`, 완성된 버전 노트(구현 내용/이슈/보고용 초안 포함).

- [ ] **Step 1: 버전 범프**

`pubspec.yaml`의 `version: 1.0.6+19` → `version: 1.0.7+20`.

- [ ] **Step 2: 버전 노트 "구현 내용" 채우기**

`_docs/version-update-note/1.0.7+20.md`의 "구현 내용" 섹션에 실제 만든 것을 리스트로 기록:
- 추가한 파일/패키지(`live_activities`, `LiveActivityService`, payload 로직, Widget Extension 등).
- 앱 동작 연결(시작/일시정지/재개/취소/자연종료/다이얼).
- iOS 설정(App Group, URL scheme, NSSupportsLiveActivities).

- [ ] **Step 3: "이슈와 해결" 및 "상태" 갱신**

Task 6 실기기 검증에서 나온 문제와 대응을 기록. 문서 상단 "상태"를 "구현 완료(실기기 검증 포함)"로 변경.

- [ ] **Step 4: "보고용 초안" 작성**

"원래 이렇게 기획했는데, 이런 이유로 이렇게 개발했다" 형식의 팀 공유용 자연어 메시지를 작성. 요구사항 → iOS/Android 분리 → iOS 미니멀 1차 → 버튼 17+ → 패키지 한계로 URL scheme(A) 채택과 트레이드오프(버튼 탭 시 앱이 잠깐 열림)를 비개발자도 이해할 수 있게 풀어 쓴다.

- [ ] **Step 5: 커밋**

```bash
git add pubspec.yaml _docs/version-update-note/1.0.7+20.md
git commit -m "docs: 1.0.7+20 버전 범프 및 Live Activity 작업 노트 완성"
```

---

## Self-Review

- **Spec coverage:** 스펙의 범위(iOS 전용/미니멀/버튼 17+/URL scheme/live_activities), 동작 흐름(시작·일시정지·재개·취소·자연종료·강제종료), 구성요소(payload 로직·서비스·DataProvider·HomeScreen·Widget Extension·Xcode 설정), 공유 데이터(4개 키), 테스트 전략(순수함수 TDD + 실기기 체크리스트), 문서 체계 — 각각 Task 1~7에 매핑됨. 강제종료 후 자동 카운트다운은 SwiftUI `Text(timerInterval:)`가 담당(Task 6), 재실행 동기화는 기존 `setTimerByLifecycle` + setMyTimer의 update 훅(Task 3)으로 커버.
- **Placeholder scan:** 실기기·Xcode GUI 단계는 "나중에"가 아니라 정확한 값/붙여넣기 코드로 기술함. 유일하게 값이 확정 불가한 부분(설치된 패키지의 정확한 시그니처, import 경로)은 Task 2 Step 2에서 검증 후 조정하도록 명시.
- **Type consistency:** payload 키(`endDateMs`/`isPaused`/`remainingSeconds`/`label`)가 Dart(Task1)와 Swift(Task6)에서 동일. 액션 경로(`/pause`,`/resume`,`/cancel`)가 파서(Task1)·핸들러(Task4)·위젯 Link(Task6)에서 일치. 메서드명(startOrUpdateRunning/updatePaused/end/pauseTimer/cancelAndReset)이 정의(Task2·3)와 호출(Task3·4)에서 일치.
