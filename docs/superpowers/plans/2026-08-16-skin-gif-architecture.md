# 스킨 GIF 아키텍처 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 애니메이션 상태를 타이머 상태에서 순수함수로 유도해, 모든 스킨을 IndexedStack에 살려두는 구조를 "현재 스킨만 빌드"로 전환한다.

**Architecture:** apple은 자체 100ms 타이머를 제거하고 DataProvider의 초당 알림 구독 + 구간 계산 순수함수로 전환. wash는 마운트 시 `isStarted`로 초기 상태를 유도하고 전이 로직을 순수함수로 통합. HomeScreen은 현재 스킨 1개만 빌드하고 나머지 스킨 에셋은 백그라운드 프리캐시.

**Tech Stack:** Flutter, provider(ChangeNotifier), gif_view, flutter_test

**Spec:** `docs/superpowers/specs/2026-08-16-skin-gif-architecture-design.md`

## Global Constraints

- 새 패키지 추가 금지 (기존 pubspec.yaml 그대로)
- 렌더링 방식 유지: apple은 `Image.asset(gaplessPlayback: true)`, wash는 `MyGif`(gif_view)
- `AssetImage.evict()`는 apple 인트로 GIF를 프레임 0부터 재생할 때만 호출
- 동기화 수준은 "구간만 맞추기": 중간 진입 시 올바른 구간의 루프 GIF를 프레임 0부터
- 인트로/전환 모션은 화면에서 직접 목격한 경계 통과·버튼 조작에만 재생
- **`flutter run` 실행 금지** — 실기기 확인은 사용자가 직접 수행 (에이전트가 실행하면 사용자 인스턴스가 종료됨)
- 각 태스크 완료 시 `flutter analyze` 경고 0 유지

---

### Task 1: apple 구간 계산 순수함수

**Files:**
- Modify: `lib/skins/apple/apple_motion_logic.dart` (파일 끝에 추가)
- Test: `test/skins/apple/apple_motion_logic_test.dart` (그룹 추가)

**Interfaces:**
- Consumes: 기존 `appleGifFrames`, `getGifDurationMilliSec(String)` (변경 없음)
- Produces: `int appleSegment({required int startSec, required int currentMilliSec})`, `String appleIntroGif(int segment)`, `String appleBlinkGif(int segment)` — Task 2가 사용

- [ ] **Step 1: 실패하는 테스트 작성**

`test/skins/apple/apple_motion_logic_test.dart`의 `main()` 마지막에 그룹 추가:

```dart
  group('appleSegment', () {
    // 60초 타이머: 2/3 경계 = 40000ms, 1/3 경계 = 20000ms
    const int startSec = 60;

    test('완료(0 이하) → 1', () {
      expect(appleSegment(startSec: startSec, currentMilliSec: 0), 1);
      expect(appleSegment(startSec: startSec, currentMilliSec: -100), 1);
    });

    test('남은 시간 2/3 초과 → 2', () {
      expect(appleSegment(startSec: startSec, currentMilliSec: 60000), 2);
      expect(appleSegment(startSec: startSec, currentMilliSec: 40100), 2);
    });

    test('정확히 2/3 경계 → 3 (기존 getAppleGifForProgress 경계와 동일)', () {
      expect(appleSegment(startSec: startSec, currentMilliSec: 40000), 3);
    });

    test('정확히 1/3 경계 → 4', () {
      expect(appleSegment(startSec: startSec, currentMilliSec: 20000), 4);
    });

    test('1/3 미만 → 4', () {
      expect(appleSegment(startSec: startSec, currentMilliSec: 100), 4);
    });

    test('홀수 초 타이머(45초): 2/3 경계 = 30000ms', () {
      expect(appleSegment(startSec: 45, currentMilliSec: 30100), 2);
      expect(appleSegment(startSec: 45, currentMilliSec: 30000), 3);
    });
  });

  group('appleIntroGif / appleBlinkGif', () {
    test('구간별 인트로 GIF 경로', () {
      expect(appleIntroGif(1), 'assets/gif/apple/apple_01.gif');
      expect(appleIntroGif(3), 'assets/gif/apple/apple_03.gif');
    });

    test('구간별 blink 루프 GIF 경로', () {
      expect(appleBlinkGif(2), 'assets/gif/apple/apple_02_blink.gif');
      expect(appleBlinkGif(4), 'assets/gif/apple/apple_04_blink.gif');
    });
  });
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/skins/apple/apple_motion_logic_test.dart`
Expected: FAIL — `appleSegment` 미정의 컴파일 에러

- [ ] **Step 3: 구현**

`lib/skins/apple/apple_motion_logic.dart` 파일 끝에 추가:

```dart
/// 남은 시간 기준 현재 구간.
/// 1: 완료, 2: 남은 시간 2/3 초과, 3: 1/3~2/3, 4: 0~1/3
int appleSegment({required int startSec, required int currentMilliSec}) {
  if (currentMilliSec <= 0) return 1;
  final int twoThirdMs = (startSec * 2 / 3).round() * 1000;
  final int oneThirdMs = (startSec * 1 / 3).round() * 1000;
  if (currentMilliSec > twoThirdMs) return 2;
  if (currentMilliSec > oneThirdMs) return 3;
  return 4;
}

/// 구간 진입을 목격했을 때 1회 재생하는 인트로 GIF 경로.
String appleIntroGif(int segment) => 'assets/gif/apple/apple_0$segment.gif';

/// 구간 대기 루프 GIF 경로.
String appleBlinkGif(int segment) => 'assets/gif/apple/apple_0${segment}_blink.gif';
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/skins/apple/apple_motion_logic_test.dart`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```bash
git add lib/skins/apple/apple_motion_logic.dart test/skins/apple/apple_motion_logic_test.dart
git commit -m "feat: apple 구간 계산 순수함수 추가 (appleSegment/appleIntroGif/appleBlinkGif)"
```

---

### Task 2: AppleMotionWidget 재작성 — 자체 타이머 제거, 유도 상태 전환

**Files:**
- Modify: `lib/skins/apple/apple_motion_widget.dart` (전체 교체)
- Modify: `lib/skins/apple/apple_motion_logic.dart` (`getAppleGifForProgress` 삭제)
- Test: `test/skins/apple/apple_motion_logic_test.dart` (`getAppleGifForProgress` 그룹 삭제)

**Interfaces:**
- Consumes: Task 1의 `appleSegment`/`appleIntroGif`/`appleBlinkGif`, 기존 `getAppleGifForPause`, `getGifDurationMilliSec`, `DataProvider.startSec/currMillisec/isStarted`
- Produces: `AppleMotionWidget` (시그니처 불변 — `apple_skin.dart`의 `motionWidgetBuilder` 수정 불필요)

동작 규칙 (spec 합의사항):
- 마운트 직후(`_lastSegment == null`)에는 인트로 생략, 현재 구간의 blink 루프부터
- 재생 중 구간 경계 통과를 목격하면(`segment != _lastSegment`) 인트로 재생 → 인트로 길이만큼의 일회성 Timer로 blink 전환
- 처음부터 시작(`isStarted` false→true이고 `currMillisec == startSec * 1000`)이면 구간 2 인트로 재생 (기존 동작 보존 — 다이얼 조작 시 `onPanEnd`에서 `setStartSec(currSec)`이 호출되므로 fresh start에서 항상 등식 성립)
- 일시정지 중 재개(위 등식 불성립)는 인트로 없이 blink (기존 동작과 동일)
- 완료 구간(1)은 인트로 없음

- [ ] **Step 1: 위젯 전체 교체**

`lib/skins/apple/apple_motion_widget.dart` 전체를 다음으로 교체:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/skins/apple/apple_motion_logic.dart';
import 'package:provider/provider.dart';

class AppleMotionWidget extends StatefulWidget {
  const AppleMotionWidget({super.key});

  @override
  State<AppleMotionWidget> createState() => _AppleMotionWidgetState();
}

class _AppleMotionWidgetState extends State<AppleMotionWidget> {
  Timer? _introTimer;
  int? _lastSegment; // 직전 빌드에서 목격한 구간 (null = 방금 마운트 → 인트로 생략)
  bool _wasStarted = false;
  bool _showingIntro = false;

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  void _startIntro(int segment) {
    _showingIntro = true;
    final String intro = appleIntroGif(segment);
    AssetImage(intro).evict(); // 인트로를 프레임 0부터 재생
    _introTimer?.cancel();
    _introTimer = Timer(
      Duration(milliseconds: getGifDurationMilliSec(intro)),
      () {
        if (!mounted) return;
        setState(() => _showingIntro = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // DataProvider가 재생 중 초당 notifyListeners()를 호출한다 — 그 알림이 시계 역할
    final data = context.watch<DataProvider>();
    final int segment = appleSegment(
        startSec: data.startSec, currentMilliSec: data.currMillisec);

    if (data.isStarted) {
      final bool freshStart =
          !_wasStarted && data.currMillisec == data.startSec * 1000;
      final bool crossedBoundary =
          _lastSegment != null && segment != _lastSegment;
      if (segment != 1 && (freshStart || crossedBoundary)) {
        _startIntro(segment);
      }
    } else {
      _introTimer?.cancel();
      _showingIntro = false;
    }
    _lastSegment = segment;
    _wasStarted = data.isStarted;

    final String imgUrl;
    if (!data.isStarted) {
      imgUrl = getAppleGifForPause(
          startSec: data.startSec, currentMilliSec: data.currMillisec);
    } else if (_showingIntro) {
      imgUrl = appleIntroGif(segment);
    } else {
      imgUrl = appleBlinkGif(segment);
    }
    return Image.asset(imgUrl, gaplessPlayback: true);
  }
}
```

- [ ] **Step 2: 사용처가 사라진 `getAppleGifForProgress` 삭제**

`lib/skins/apple/apple_motion_logic.dart`에서 `getAppleGifForProgress` 함수 전체(doc 주석 포함)를 삭제. `getGifDurationMilliSec`, `getAppleGifForPause`, `appleGifFrames`는 계속 사용되므로 유지.

`test/skins/apple/apple_motion_logic_test.dart`에서 `group('getAppleGifForProgress', ...)` 블록 전체 삭제.

- [ ] **Step 3: 분석·테스트 통과 확인**

Run: `flutter analyze && flutter test`
Expected: 경고 0, 전체 테스트 PASS

- [ ] **Step 4: 커밋**

```bash
git add lib/skins/apple/apple_motion_widget.dart lib/skins/apple/apple_motion_logic.dart test/skins/apple/apple_motion_logic_test.dart
git commit -m "refactor: apple 모션을 타이머 상태 유도 방식으로 전환 (자체 100ms 타이머 제거)"
```

---

### Task 3: wash 상태 전이 순수함수

**Files:**
- Create: `lib/skins/wash/wash_motion_logic.dart`
- Test: `test/skins/wash/wash_motion_logic_test.dart` (새 파일)

**Interfaces:**
- Consumes: 없음 (순수 Dart)
- Produces: `enum WashState { blink, start, activate, stop }` (인덱스 = IndexedStack 순서), `WashState washInitialState({required bool isStarted})`, `WashState washNextState({required WashState finished, required bool isStarted})` — Task 4가 사용

- [ ] **Step 1: 실패하는 테스트 작성**

`test/skins/wash/wash_motion_logic_test.dart` 생성:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/skins/wash/wash_motion_logic.dart';

void main() {
  group('washInitialState', () {
    test('작동 중이면 activate 루프부터 (전환 모션 생략)', () {
      expect(washInitialState(isStarted: true), WashState.activate);
    });

    test('정지 상태면 blink부터', () {
      expect(washInitialState(isStarted: false), WashState.blink);
    });
  });

  group('washNextState', () {
    test('blink 종료: 작동 중 → start, 아니면 blink 유지', () {
      expect(washNextState(finished: WashState.blink, isStarted: true),
          WashState.start);
      expect(washNextState(finished: WashState.blink, isStarted: false),
          WashState.blink);
    });

    test('start 종료: 작동 중 → activate, 아니면 stop', () {
      expect(washNextState(finished: WashState.start, isStarted: true),
          WashState.activate);
      expect(washNextState(finished: WashState.start, isStarted: false),
          WashState.stop);
    });

    test('activate 종료: 작동 중 → activate 반복, 아니면 stop', () {
      expect(washNextState(finished: WashState.activate, isStarted: true),
          WashState.activate);
      expect(washNextState(finished: WashState.activate, isStarted: false),
          WashState.stop);
    });

    test('stop 종료: 작동 중 → start, 아니면 blink', () {
      expect(washNextState(finished: WashState.stop, isStarted: true),
          WashState.start);
      expect(washNextState(finished: WashState.stop, isStarted: false),
          WashState.blink);
    });
  });

  test('WashState 인덱스가 IndexedStack 자식 순서와 일치', () {
    expect(WashState.blink.index, 0);
    expect(WashState.start.index, 1);
    expect(WashState.activate.index, 2);
    expect(WashState.stop.index, 3);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/skins/wash/wash_motion_logic_test.dart`
Expected: FAIL — `wash_motion_logic.dart` 파일 없음 컴파일 에러

- [ ] **Step 3: 구현**

`lib/skins/wash/wash_motion_logic.dart` 생성:

```dart
/// wash 모션 상태. 값 순서는 WashMotionWidget 내부 IndexedStack의 자식 순서와 일치한다.
enum WashState { blink, start, activate, stop }

/// 마운트 시 타이머 상태로부터 초기 모션을 유도한다 (전환 모션 생략).
WashState washInitialState({required bool isStarted}) =>
    isStarted ? WashState.activate : WashState.blink;

/// 모션(finished)의 재생이 끝났을 때 다음 모션을 결정한다.
WashState washNextState(
    {required WashState finished, required bool isStarted}) {
  switch (finished) {
    case WashState.blink:
      return isStarted ? WashState.start : WashState.blink;
    case WashState.start:
      return isStarted ? WashState.activate : WashState.stop;
    case WashState.activate:
      return isStarted ? WashState.activate : WashState.stop;
    case WashState.stop:
      return isStarted ? WashState.start : WashState.blink;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/skins/wash/wash_motion_logic_test.dart`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```bash
git add lib/skins/wash/wash_motion_logic.dart test/skins/wash/wash_motion_logic_test.dart
git commit -m "feat: wash 상태 전이 순수함수 추가 (washInitialState/washNextState)"
```

---

### Task 4: WashMotionWidget 재작성 — 초기 상태 유도

**Files:**
- Modify: `lib/skins/wash/wash_motion_widget.dart` (전체 교체)

**Interfaces:**
- Consumes: Task 3의 `WashState`/`washInitialState`/`washNextState`, 기존 `MyGif`, `GifController`, `DataProvider.isStarted`
- Produces: `WashMotionWidget` (시그니처 불변 — `wash_skin.dart` 수정 불필요)

동작 규칙 (spec 합의사항):
- 마운트 시 `isStarted`로 초기 모션 유도 (작동 중 → activate 루프, 아니면 blink). 기존의 "중간 진입 시 start 전환 모션 재생" 제거
- 화면에 보이는 중 시작 조작 목격(blink 중 `isStarted` true) → 즉시 start 전환 모션
- 정지 조작은 기존 동작대로 현재 모션 사이클이 끝나는 시점에 `washNextState`가 stop으로 전이
- 4개 콜백의 분기를 `washNextState` 호출 하나로 통합. activate 반복 재생의 `seek(0) → 1ms 대기 → play()` 패턴은 기존 그대로 유지

- [ ] **Step 1: 위젯 전체 교체**

`lib/skins/wash/wash_motion_widget.dart` 전체를 다음으로 교체:

```dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/skins/wash/wash_motion_logic.dart';
import 'package:joguman_pomodoro/widgets/my_gif.dart';
import 'package:provider/provider.dart';

class WashMotionWidget extends StatefulWidget {
  const WashMotionWidget({super.key});

  @override
  State<WashMotionWidget> createState() => _WashMotionWidgetState();
}

class _WashMotionWidgetState extends State<WashMotionWidget> {
  final controllerBlink = GifController();
  final controllerStart = GifController();
  final controllerActivate = GifController();
  final controllerStop = GifController();
  late WashState _state;
  late final WashState _initialState; // 마운트 시 1회 고정 — autoPlay 대상 결정용

  GifController _controllerOf(WashState state) {
    switch (state) {
      case WashState.blink:
        return controllerBlink;
      case WashState.start:
        return controllerStart;
      case WashState.activate:
        return controllerActivate;
      case WashState.stop:
        return controllerStop;
    }
  }

  @override
  void initState() {
    super.initState();
    _initialState =
        washInitialState(isStarted: context.read<DataProvider>().isStarted);
    _state = _initialState;
  }

  @override
  void dispose() {
    controllerBlink.dispose();
    controllerStart.dispose();
    controllerActivate.dispose();
    controllerStop.dispose();
    super.dispose();
  }

  Future<void> _onFinish(WashState finished) async {
    if (!mounted) return;
    final bool isStarted = context.read<DataProvider>().isStarted;
    final WashState next =
        washNextState(finished: finished, isStarted: isStarted);
    if (next == finished) {
      // 같은 모션 반복: blink는 loop=true라 seek(0)만, activate는 재생을 다시 건다
      final controller = _controllerOf(finished);
      controller.seek(0);
      if (finished == WashState.activate) {
        await Future.delayed(const Duration(milliseconds: 1));
        controller.play();
      }
    } else {
      _controllerOf(finished).stop();
      _controllerOf(next).play();
    }
    if (!mounted) return;
    setState(() => _state = next);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<DataProvider, bool>(
      selector: (context, dataProvider) => dataProvider.isStarted,
      builder: (context, isStarted, child) {
        // 화면에 보이는 중 시작 조작을 목격하면 즉시 start 전환 모션 재생
        // (정지는 기존 동작대로 현재 모션이 끝나는 시점에 _onFinish에서 전이)
        if (isStarted && _state == WashState.blink) {
          _state = WashState.start;
          controllerBlink.stop();
          controllerStart.play();
        }
        return IndexedStack(
          index: _state.index,
          children: [
            MyGif(
                image: 'assets/gif/wash/wash_blink.gif',
                callback: () => _onFinish(WashState.blink),
                controller: controllerBlink,
                autoPlay: _initialState == WashState.blink,
                loop: true),
            MyGif(
                image: 'assets/gif/wash/wash_start.gif',
                callback: () => _onFinish(WashState.start),
                controller: controllerStart),
            MyGif(
                image: 'assets/gif/wash/wash_activate.gif',
                callback: () => _onFinish(WashState.activate),
                controller: controllerActivate,
                autoPlay: _initialState == WashState.activate),
            MyGif(
                image: 'assets/gif/wash/wash_stop.gif',
                callback: () => _onFinish(WashState.stop),
                controller: controllerStop),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: 분석·테스트 통과 확인**

Run: `flutter analyze && flutter test`
Expected: 경고 0, 전체 테스트 PASS

- [ ] **Step 3: 커밋**

```bash
git add lib/skins/wash/wash_motion_widget.dart
git commit -m "refactor: wash 모션 초기 상태를 타이머 상태에서 유도, 전이 로직 순수함수로 통합"
```

---

### Task 5: HomeScreen 단일 스킨 빌드 + 백그라운드 프리캐시

**Files:**
- Modify: `lib/screens/home_screen.dart` (`_buildDial`, `initFunc`, import 추가)

**Interfaces:**
- Consumes: `skinConfigs`(skin_registry), `precacheImages(BuildContext, SkinConfig)`/`prefetchGifImages(SkinConfig)`(utility.dart), Task 2·4의 재작성된 모션 위젯 (마운트 시 스스로 올바른 상태 유도)
- Produces: 없음 (최종 소비자)

- [ ] **Step 1: `_buildDial`을 단일 스킨 빌드로 교체**

`_buildDial`에서 `skinConfigs.map((config) { ... }).toList()`와 마지막 `IndexedStack` 반환을 제거하고, 현재 스킨 하나만 빌드하도록 교체. 기존 `PomodoroCast` 인자는 전부 그대로 유지:

```dart
  Widget _buildDial(BuildContext context, double clockSize,
      {double footScale = 1.0,
      double overlayScale = 1.0,
      double overlayLift = 0.0}) {
    themeIndex = context.watch<ThemeProvider>().themeIndex; // 기존 State 필드 재사용
    final config = skinConfigs[themeIndex];

    Widget motionWidget = config.motionWidgetBuilder();
    if (config.centerAnimationScale != null) {
      motionWidget = Transform.scale(
          scale: config.centerAnimationScale!, child: motionWidget);
    }

    // key로 스킨 전환 시 이전 모션 위젯 dispose + 새 위젯 fresh 마운트 보장
    return KeyedSubtree(
      key: ValueKey(config.id),
      child: PomodoroCast(
        dialImage: config.dialImageAsset ?? 'assets/img/chrono.png',
        dialImageOffset: config.dialImageOffset,
        dialImageScale: config.dialImageScale,
        clockSize: clockSize,
        clockHandHeight: clockSize * (7.8 / 10) / 2 - 5,
        clockHandWidth: 5,
        clockHandColor: const Color.fromARGB(255, 222, 37, 49),
        leftTimeColor: config.leftTimeColor,
        dialCircleColor: config.dialCircleColor,
        dialShadowColor: config.dialShadowColor,
        clockHandFootYOffset: config.clockHandFootOffset * clockSize,
        clockHandFootRotatesWithDial: config.clockHandFootRotatesWithDial,
        clockHandFoot: Image.asset(config.clockHandFootAsset,
            width: config.clockHandFootWidth * clockSize * footScale),
        centerAnimation: Container(
          width: (clockSize) * 0.75 - 40,
          height: (clockSize) * 0.75 - 40,
          clipBehavior: config.centerClipBehavior,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.centerBackgroundColor,
            boxShadow: [
              BoxShadow(
                  color: config.centerShadowColor,
                  blurRadius: config.centerShadowBlur,
                  spreadRadius: config.centerShadowSpread)
            ],
          ),
          child: motionWidget,
        ),
        timerPainterBuilder: config.timerPainterBuilder,
        dialOverlayBuilder: config.dialOverlayBuilder == null
            ? null
            : (cs) => Transform.translate(
                offset: Offset(0, -overlayLift * cs), // 양수=위로(중심에서 멀어짐)
                child: Transform.scale(
                    scale: overlayScale,
                    child: config.dialOverlayBuilder!(cs))),
        dialBackgroundBuilder: config.dialBackgroundBuilder,
      ),
    );
  }
```

- [ ] **Step 2: 나머지 스킨 백그라운드 프리캐시**

`lib/screens/home_screen.dart` import에 추가:

```dart
import 'package:joguman_pomodoro/models/skin_config.dart';
```

`initFunc`의 `finally` 블록을 다음으로 변경 (`isLoaded` 후 프리캐시 시작):

```dart
        } finally {
          setState(() {
            isLoaded = true;
          });
          unawaited(_precacheOtherSkins(skin));
        }
```

`initFunc` 아래에 메서드 추가:

```dart
  /// 현재 스킨 로딩 후 나머지 스킨 에셋을 백그라운드로 순차 프리캐시한다.
  /// 지연 빌드 전환으로 스킨 변경 순간 로딩 끊김이 생기지 않게 미리 채워둔다.
  Future<void> _precacheOtherSkins(SkinConfig current) async {
    for (final config in skinConfigs) {
      if (config.id == current.id) continue;
      if (!mounted) return;
      try {
        await precacheImages(context, config);
        await prefetchGifImages(config);
      } catch (e) {
        print('skin precache error (${config.id}): $e');
      }
    }
  }
```

참고: `dart:async`는 이미 import되어 있어 `unawaited` 사용 가능. `use_build_context_synchronously` 경고가 나오면 루프 안 `context` 사용 직전의 `if (!mounted) return;` 가드로 해소되는지 확인하고, 그래도 남으면 해당 라인에 `// ignore: use_build_context_synchronously`를 붙인다.

- [ ] **Step 3: 분석·테스트 통과 확인**

Run: `flutter analyze && flutter test`
Expected: 경고 0, 전체 테스트 PASS

- [ ] **Step 4: 커밋**

```bash
git add lib/screens/home_screen.dart
git commit -m "refactor: 현재 스킨만 빌드하도록 전환, 나머지 스킨은 백그라운드 프리캐시"
```

---

### Task 6: 최종 검증

**Files:** 없음 (검증만)

- [ ] **Step 1: 전체 정적 분석·테스트**

Run: `flutter analyze && flutter test`
Expected: 경고 0, 전체 테스트 PASS

- [ ] **Step 2: 사용자 실기기 확인 요청**

에이전트는 `flutter run`을 실행하지 않는다. 사용자에게 아래 체크리스트로 확인을 요청한다:

- 세로/가로 각각에서 스킨 3종 전환이 즉시(로딩 화면 없이) 되는지
- apple: 타이머 시작 → 인트로 재생 → blink 루프, 2/3·1/3 경계에서 인트로 재생
- apple: 타이머 중간에 다른 스킨 갔다가 돌아오면 올바른 구간의 blink부터 시작하는지
- wash: 타이머 중간에 진입하면 start 모션 없이 activate 루프부터인지
- wash: 화면을 보며 재생/정지 버튼을 누르면 start/stop 전환 모션이 나오는지
- 일시정지·재개, 타이머 완료, 백그라운드 갔다가 복귀 시 모션이 어긋나지 않는지

- [ ] **Step 3: 확인 결과 반영 후 마무리**

사용자 확인에서 문제가 나오면 수정 커밋, 이상 없으면 완료 보고.
