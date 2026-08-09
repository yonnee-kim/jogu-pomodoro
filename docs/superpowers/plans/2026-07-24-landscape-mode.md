# 가로모드 지원 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 세로 고정 앱에 가로모드를 추가한다. 가로에서는 다이얼을 왼쪽, 시간 텍스트+버튼을 오른쪽에 배치하고, 세로모드 동작은 전부 그대로 유지한다.

**Architecture:** 가로/세로 판별로 `HomeScreen.build`에서 레이아웃을 분기한다. 다이얼 생성부는 헬퍼로 추출해 양쪽이 공유한다. 가로 영역 분할(6:4, 조건부 확장, 버튼영역 최소 20%)은 순수 함수로 분리해 유닛 테스트한다. `TimerWidget` 내부 치수를 단일 기준값 `numberHeight`의 배수로 리팩터해 가로에서 크기를 재조정하되 세로는 픽셀 동일하게 유지한다.

**Tech Stack:** Flutter, Dart(SDK >=3.4.4 <4.0.0), Provider, responsive_sizer, flutter_test.

## Global Constraints

- Dart SDK 제약: `>=3.4.4 <4.0.0`. 새 의존성 추가 금지.
- 세로모드(portrait) 렌더링·정렬·동작은 세 스킨(apple/wash/school) 모두 기존과 **완전히 동일**해야 한다.
- 회전 허용: `portraitUp`, `landscapeLeft`, `landscapeRight`. `portraitDown` 제외.
- 가로 레이아웃 상수: `dialRegionRatio = 0.6`, `panelMinRatio = 0.2`, `dialHeightFactor = 0.9`.
- school 가로 전용 배경은 범위 밖. 가로에서도 기존 세로용 `backgroundBuilder` 그대로 사용.
- 커밋 메시지는 저장소 관례(한국어 conventional: `feat:`/`fix:`/`refactor:`)를 따른다.
- 각 코드 변경 후 `flutter analyze`는 새 경고 0으로 통과해야 한다.

---

## File Structure

- Create: `lib/screens/landscape_layout.dart` — 가로 영역 분할 순수 함수 + 결과 클래스. `HomeScreen`이 소비.
- Create: `test/screens/landscape_layout_test.dart` — 위 함수 유닛 테스트.
- Modify: `lib/widgets/timer_widget.dart` — 내부 치수를 `numberHeight` 단위 배수로 리팩터, 옵셔널 `numberHeight` 파라미터 추가.
- Modify: `lib/widgets/pomodoro_cast.dart` — 다이얼 중심(center)을 회전에도 정확하게 계산하도록 수정.
- Modify: `lib/screens/home_screen.dart` — 방향 분기, 다이얼 헬퍼 추출, 가로 레이아웃, `BottomButtonWidet` 가로 옵션.
- Modify: `lib/main.dart` — 회전 잠금 해제.

---

### Task 1: 가로 영역 분할 순수 함수

가로 화면의 왼쪽(다이얼)/오른쪽(버튼) 영역 폭과 다이얼 크기를 계산하는 순수 함수. 다이얼:버튼 = 6:4 기본, 6:4에서 다이얼이 최대높이에 못 미치면 왼쪽 영역을 넓히되 버튼영역은 최소 20% 보장.

**Files:**
- Create: `lib/screens/landscape_layout.dart`
- Test: `test/screens/landscape_layout_test.dart`

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `class LandscapeLayout { final double leftRegion; final double dialSize; final double rightRegion; const LandscapeLayout({required this.leftRegion, required this.dialSize, required this.rightRegion}); }`
  - `LandscapeLayout computeLandscapeLayout({required double width, required double height, double dialRegionRatio = 0.6, double panelMinRatio = 0.2, double dialHeightFactor = 0.9})`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/screens/landscape_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/screens/landscape_layout.dart';

void main() {
  group('computeLandscapeLayout', () {
    test('일반 폰 가로(2.2:1)는 정확히 6:4, 다이얼은 높이 기준', () {
      // W=2200, H=1000 → maxDialByHeight=900, leftRegion=1320(>900 → 확장 없음)
      final r = computeLandscapeLayout(width: 2200, height: 1000);
      expect(r.leftRegion, closeTo(1320, 0.001)); // 60%
      expect(r.rightRegion, closeTo(880, 0.001)); // 40%
      expect(r.dialSize, closeTo(900, 0.001)); // 높이 0.9
    });

    test('태블릿 가로(1.33:1)는 다이얼 영역이 6 이상으로 확장, 버튼 20% 이상', () {
      // W=1330, H=1000 → maxDialByHeight=900, leftRegion=798(<900)
      // → leftRegion=min(900, 1330*0.8=1064)=900
      final r = computeLandscapeLayout(width: 1330, height: 1000);
      expect(r.leftRegion, closeTo(900, 0.001));
      expect(r.dialSize, closeTo(900, 0.001)); // 최대높이 도달
      expect(r.rightRegion, closeTo(430, 0.001));
      expect(r.rightRegion / 1330, greaterThan(0.2)); // 버튼영역 > 20%
      expect(r.leftRegion / 1330, greaterThan(0.6)); // 다이얼영역 > 60%
    });

    test('거의 정사각(1.05:1)은 버튼영역 20% 하한, 다이얼은 최대높이 미달 허용', () {
      // W=1050, H=1000 → maxDialByHeight=900, leftRegion=630(<900)
      // → leftRegion=min(900, 1050*0.8=840)=840
      final r = computeLandscapeLayout(width: 1050, height: 1000);
      expect(r.leftRegion, closeTo(840, 0.001));
      expect(r.dialSize, closeTo(840, 0.001)); // 900에 미달(폭 제약)
      expect(r.rightRegion, closeTo(210, 0.001));
      expect(r.rightRegion / 1050, closeTo(0.2, 0.001)); // 하한 도달
    });

    test('불변식: 다이얼 크기는 항상 높이*0.9 이하, 버튼영역은 항상 폭*0.2 이상', () {
      for (final wh in [[1600, 900], [2400, 1080], [1194, 834], [2000, 1000]]) {
        final r = computeLandscapeLayout(width: wh[0].toDouble(), height: wh[1].toDouble());
        expect(r.dialSize, lessThanOrEqualTo(wh[1] * 0.9 + 0.001));
        expect(r.rightRegion, greaterThanOrEqualTo(wh[0] * 0.2 - 0.001));
        expect(r.leftRegion + r.rightRegion, closeTo(wh[0].toDouble(), 0.001));
      }
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/screens/landscape_layout_test.dart`
Expected: FAIL — `landscape_layout.dart` 없음 / `computeLandscapeLayout` 미정의 컴파일 에러.

- [ ] **Step 3: 최소 구현 작성**

`lib/screens/landscape_layout.dart`:

```dart
import 'dart:math' as math;

/// 가로모드 영역 분할 결과.
class LandscapeLayout {
  final double leftRegion; // 왼쪽(다이얼) 영역 폭
  final double dialSize; // 다이얼 한 변 길이(정사각)
  final double rightRegion; // 오른쪽(버튼) 영역 폭

  const LandscapeLayout({
    required this.leftRegion,
    required this.dialSize,
    required this.rightRegion,
  });
}

/// 가로 화면에서 다이얼/버튼 영역 폭과 다이얼 크기를 계산한다.
///
/// 규칙:
/// - 기본 다이얼:버튼 = dialRegionRatio : (1-dialRegionRatio) (6:4)
/// - 6:4에서 다이얼이 최대높이(height*dialHeightFactor)에 못 미치면
///   왼쪽 영역을 넓혀 다이얼을 키운다.
/// - 단, 버튼(오른쪽) 영역은 최소 width*panelMinRatio(20%) 보장.
LandscapeLayout computeLandscapeLayout({
  required double width,
  required double height,
  double dialRegionRatio = 0.6,
  double panelMinRatio = 0.2,
  double dialHeightFactor = 0.9,
}) {
  final double maxDialByHeight = height * dialHeightFactor;
  double leftRegion = width * dialRegionRatio;
  if (leftRegion < maxDialByHeight) {
    leftRegion = math.min(maxDialByHeight, width * (1 - panelMinRatio));
  }
  final double dialSize = math.min(leftRegion, maxDialByHeight);
  final double rightRegion = width - leftRegion;
  return LandscapeLayout(
    leftRegion: leftRegion,
    dialSize: dialSize,
    rightRegion: rightRegion,
  );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/screens/landscape_layout_test.dart`
Expected: PASS — All tests passed!

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/screens/landscape_layout.dart test/screens/landscape_layout_test.dart`
Expected: No issues found!

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/landscape_layout.dart test/screens/landscape_layout_test.dart
git commit -m "feat: 가로모드 영역 분할 계산 순수 함수 추가"
```

---

### Task 2: TimerWidget를 numberHeight 단위 기준으로 리팩터

`TimerWidget` 내부 치수가 전부 `.w`(가로폭 비례)라 가로모드에서 크기가 폭발한다. 모든 치수를 단일 기준값 `unit`(=numberHeight)의 배수로 표현하고, 옵셔널 `numberHeight` 파라미터를 추가한다. null이면 기존 `10.5.w` → 세로 픽셀 동일.

**Files:**
- Modify: `lib/widgets/timer_widget.dart`

**Interfaces:**
- Consumes: 없음.
- Produces: `const TimerWidget({super.key, this.numberHeight})` — `final double? numberHeight;`. null이면 세로(=10.5.w), 값이 있으면 그 값 기준으로 전체 스케일.

- [ ] **Step 1: 생성자에 옵셔널 numberHeight 추가**

`lib/widgets/timer_widget.dart`의 클래스 선언부를 교체:

```dart
class TimerWidget extends StatelessWidget {
  const TimerWidget({super.key, this.numberHeight});

  final double? numberHeight;

  @override
  Widget build(BuildContext context) {
```

- [ ] **Step 2: build 내부 치수를 unit 배수로 교체**

기존 `double numberHeight = 10.5.w;` 줄을 아래로 교체하고, 이어지는 파생 치수를 선언:

```dart
    final double unit = numberHeight ?? 10.5.w;
    final double overlayHeight = unit * (51 / 10.5);
    final double overlayWidth = unit * (100 / 10.5);
    final double offsetX = unit * (-0.8 / 10.5);
    final double offsetY = unit * (2.3 / 10.5);
    final double digitGap = unit * (0.8 / 10.5);
    final double colonPad = unit * (3 / 10.5);
```

그리고 `return Stack(...)` 내부의 리터럴을 아래처럼 교체한다:

- `SizedBox(height: 51.w, width: 100.w, ...)` → `SizedBox(height: overlayHeight, width: overlayWidth, ...)`
- `Transform.translate(offset: Offset(-0.8.w, 2.3.w), ...)` → `Transform.translate(offset: Offset(offsetX, offsetY), ...)`
- 숫자 이미지 4개의 `height: numberHeight` → `height: unit`
- 콜론 `Image.asset(..., height: numberHeight)` → `height: unit`
- 숫자 사이 `SizedBox(width: 0.8.w)` (2곳) → `SizedBox(width: digitGap)`
- 콜론 `Padding(padding: EdgeInsets.symmetric(horizontal: 3.w), ...)` → `EdgeInsets.symmetric(horizontal: colonPad)`

교체 후 build의 반환부는 다음 형태가 된다:

```dart
    return Stack(
      alignment: Alignment.center,
      children: [
        Selector<DataProvider, bool>(
            selector: (context, dataProvider) => dataProvider.isStarted,
            builder: (context, isStarted, child) {
              return SizedBox(
                height: overlayHeight,
                width: overlayWidth,
                child: skin.timerOverlayBuilder != null ? skin.timerOverlayBuilder!(isStarted) : null,
              );
            }),
        Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image(image: numberMap[minutes1], color: skin.numberTintColor, height: unit),
                    SizedBox(width: digitGap),
                    Image(image: numberMap[minutes2], color: skin.numberTintColor, height: unit),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: colonPad),
                child: Image.asset('assets/img/colon.png', color: skin.numberTintColor, height: unit),
              ),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Image(image: numberMap[seconds1], color: skin.numberTintColor, height: unit),
                    SizedBox(width: digitGap),
                    Image(image: numberMap[seconds2], color: skin.numberTintColor, height: unit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
```

- [ ] **Step 3: analyze로 검증**

Run: `flutter analyze lib/widgets/timer_widget.dart`
Expected: No issues found!

(세로 픽셀 동일성: `unit = 10.5.w`일 때 `unit*(51/10.5)=51.w`, `unit*(100/10.5)=100.w`, `unit*(0.8/10.5)=0.8.w` 등으로 기존 리터럴과 수학적으로 동일. 실제 세로 렌더링은 Task 6에서 육안 확인.)

- [ ] **Step 4: 커밋**

```bash
git add lib/widgets/timer_widget.dart
git commit -m "refactor: TimerWidget 치수를 numberHeight 단위 기준으로 통일 및 파라미터화"
```

---

### Task 3: BottomButtonWidet 가로 배치 옵션

가로에서 play/stop·change 버튼을 패널 중앙에 묶어 배치하도록 `landscape` 플래그를 추가한다. 세로 배치는 그대로 유지.

**Files:**
- Modify: `lib/screens/home_screen.dart` (`BottomButtonWidet`)

**Interfaces:**
- Consumes: 없음.
- Produces: `const BottomButtonWidet({super.key, this.landscape = false})` — `final bool landscape;`.

- [ ] **Step 1: 생성자에 landscape 플래그 추가**

`class BottomButtonWidet extends StatefulWidget {` 선언부를 교체:

```dart
class BottomButtonWidet extends StatefulWidget {
  const BottomButtonWidet({super.key, this.landscape = false});

  final bool landscape;

  @override
  State<BottomButtonWidet> createState() => _BottomButtonWidetState();
}
```

- [ ] **Step 2: build에서 두 버튼을 지역 변수로 추출 후 방향 분기**

`_BottomButtonWidetState.build`의 `return Padding(...)` 전체를 아래로 교체한다. play/stop·change 버튼 위젯을 지역 변수로 뽑고, 세로는 기존 `spaceBetween` 레이아웃, 가로는 중앙 묶음 레이아웃을 반환한다:

```dart
  @override
  Widget build(BuildContext context) {
    Timer? myTimer = context.watch<DataProvider>().myTimer;
    final skin = context.watch<ThemeProvider>().currentSkin;

    final Widget playStopButton = GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (myTimer != null && myTimer.isActive) {
          context.read<DataProvider>().cancleTimer();
          context.read<DataProvider>().setIsStarted(false);
        } else {
          context.read<DataProvider>().setMyTimer(context);
          if (context.read<DataProvider>().startSec > 0) {
            context.read<DataProvider>().setIsStarted(true);
          }
        }
      },
      child: Image.asset(
        myTimer != null && myTimer.isActive ? (skin.stopButtonAsset ?? 'assets/img/stop.png') : (skin.playButtonAsset ?? 'assets/img/play.png'),
        width: 60,
      ),
    );

    final Widget changeButton = GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await context.read<ThemeProvider>().addThemeIndex();
      },
      child: Image.asset(skin.changeButtonAsset ?? 'assets/img/change.png', width: 60),
    );

    if (widget.landscape) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          playStopButton,
          const SizedBox(width: 28),
          changeButton,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          playStopButton,
          // 테스트 버튼 (기존 비활성 데드코드 — 그대로 보존)
          if (false)
            GestureDetector(
              onTap: () async {
                String bodyText = 'end_message'.tr();
                DateTime alarmDate = DateTime.now().add(const Duration(seconds: 3));
                await setScheduleNotification(dateTime: alarmDate, title: 'app_name'.tr(), body: bodyText, type: 'alarm');
              },
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: const Color.fromARGB(255, 213, 213, 213),
                ),
                child: Center(
                  child: Text(
                    isTapped ? '❌' : '🎵',
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
              ),
            ),
          changeButton,
        ],
      ),
    );
  }
```

(주의: 기존 `if (false)` 테스트 버튼은 사전 데드코드이므로 삭제하지 않고 세로 Row에 그대로 보존한다. 실제 버튼 두 개만 지역 변수로 추출해 세로/가로가 공유한다. 로직 변화 없음.)

- [ ] **Step 3: analyze로 검증**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: 이번 변경으로 인한 새 이슈 0. (기존 파일의 사전 경고가 있으면 그대로 유지 — 새로 추가 금지.)

- [ ] **Step 4: 커밋**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: BottomButtonWidet 가로 배치 옵션 추가"
```

---

### Task 4: PomodoroCast 다이얼 중심 회전 대응 수정

`center`가 `initState`에서 초기 `clockSize`로 1회만 계산돼, 회전으로 `clockSize`가 바뀌면 다이얼 터치 각도 계산이 틀어진다. `onPanUpdate`에서 현재 `widget.clockSize`로 계산하도록 수정한다.

**Files:**
- Modify: `lib/widgets/pomodoro_cast.dart`

**Interfaces:**
- Consumes: 없음.
- Produces: 없음(내부 동작 수정).

- [ ] **Step 1: 캐시된 center 필드와 initState 제거**

`_PomodoroCastState`에서 다음 필드 선언을 삭제:

```dart
  late Offset center; // 다이얼의 중심 위치
```

그리고 아래 `initState` 오버라이드 전체를 삭제:

```dart
  @override
  void initState() {
    super.initState();
    center = Offset(widget.clockSize / 2, widget.clockSize / 2);
  }
```

- [ ] **Step 2: onPanUpdate에서 center를 현재 clockSize로 계산**

`onPanUpdate` 안에서 dx/dy 계산 직전에 center를 지역 변수로 계산하도록 수정한다. 기존:

```dart
    // 현재 손가락 위치와 중심의 위치를 이용해 각도 계산
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
```

교체:

```dart
    // 현재 손가락 위치와 중심의 위치를 이용해 각도 계산 (회전 시에도 현재 clockSize 기준)
    final center = Offset(widget.clockSize / 2, widget.clockSize / 2);
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
```

- [ ] **Step 3: analyze로 검증**

Run: `flutter analyze lib/widgets/pomodoro_cast.dart`
Expected: No issues found! (미사용 필드/초기화 관련 경고 없음.)

- [ ] **Step 4: 커밋**

```bash
git add lib/widgets/pomodoro_cast.dart
git commit -m "fix: 다이얼 중심을 현재 clockSize로 계산해 회전 시 터치 각도 보정"
```

---

### Task 5: HomeScreen 방향 분기 + 가로 레이아웃, 회전 잠금 해제

방향을 판별해 세로(기존 Column)와 가로(Row: 왼쪽 다이얼 / 오른쪽 패널)로 분기한다. 다이얼 생성부는 헬퍼로 추출해 공유한다. 마지막으로 `main.dart`에서 회전을 허용해 기능을 켠다.

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `computeLandscapeLayout`, `LandscapeLayout` (Task 1), `TimerWidget(numberHeight:)` (Task 2), `BottomButtonWidet(landscape:)` (Task 3).
- Produces: 없음.

- [ ] **Step 1: landscape_layout import 추가**

`lib/screens/home_screen.dart` 상단 import 목록에 추가:

```dart
import 'package:joguman_pomodoro/screens/landscape_layout.dart';
```

- [ ] **Step 2: 다이얼 생성부를 헬퍼로 추출**

`_buildContent` 안의 `List<Widget> pomodoroList = ...` 부터 만들어지는 `IndexedStack`을 별도 헬퍼로 뽑는다. `HomeScreenState`에 아래 메서드를 추가한다(기존 `_buildContent` 위/아래 아무 곳):

```dart
  Widget _buildDial(BuildContext context, double clockSize) {
    themeIndex = context.watch<ThemeProvider>().themeIndex; // 기존 State 필드 재사용(제거하지 않음)

    final pomodoroList = skinConfigs.map((config) {
      Widget motionWidget = config.motionWidgetBuilder();
      if (config.centerAnimationScale != null) {
        motionWidget = Transform.scale(scale: config.centerAnimationScale!, child: motionWidget);
      }

      return PomodoroCast(
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
        clockHandFoot: Image.asset(config.clockHandFootAsset, width: config.clockHandFootWidth * clockSize),
        centerAnimation: Container(
          width: (clockSize) * 0.75 - 40,
          height: (clockSize) * 0.75 - 40,
          clipBehavior: config.centerClipBehavior,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.centerBackgroundColor,
            boxShadow: [BoxShadow(color: config.centerShadowColor, blurRadius: config.centerShadowBlur, spreadRadius: config.centerShadowSpread)],
          ),
          child: motionWidget,
        ),
        timerPainterBuilder: config.timerPainterBuilder,
        dialOverlayBuilder: config.dialOverlayBuilder,
        dialBackgroundBuilder: config.dialBackgroundBuilder,
      );
    }).toList();

    return IndexedStack(
      index: themeIndex,
      alignment: Alignment.center,
      children: pomodoroList,
    );
  }
```

그리고 기존 `_buildContent`에서 `List<Widget> pomodoroList = skinConfigs.map(...).toList();` 블록과 그 아래 `IndexedStack(index: themeIndex, alignment: Alignment.center, children: pomodoroList,)`를 다음 한 줄로 교체한다(Column의 해당 위치):

```dart
                    _buildDial(context, clockSize),
```

교체 후 `_buildContent` 상단에 남아있던 `themeIndex = context.watch<ThemeProvider>().themeIndex;` 줄은 제거한다(`_buildDial`이 대신 할당). 클래스 필드 `int themeIndex = 0;`는 `_buildDial`에서 계속 쓰이므로 **제거하지 않는다**. `final skin = context.watch<ThemeProvider>().currentSkin;`는 배경/timerOffsetY에 쓰이므로 유지한다.

- [ ] **Step 3: 알림 권한 버튼을 헬퍼로 추출**

세로/가로가 공유하도록 `HomeScreenState`에 추가:

```dart
  Widget _notificationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(200),
            ),
            onPressed: () async {
              await getPermissionWithNotification();
            },
            icon: const Icon(Icons.notifications, color: Color.fromARGB(255, 149, 149, 149), size: 30),
          )
        ],
      ),
    );
  }
```

그리고 기존 `_buildContent`의 `if (!isGranted) Padding(...)` 블록을 아래로 교체:

```dart
                if (!isGranted) _notificationButton(),
```

- [ ] **Step 4: 가로 레이아웃 메서드 추가**

`HomeScreenState`에 추가. 오른쪽 패널은 세로 중앙 정렬로 타이머 위, 버튼 아래:

```dart
  Widget _buildLandscapeContent(BuildContext context, LandscapeLayout layout, double numberHeight) {
    final skin = context.watch<ThemeProvider>().currentSkin;

    return Stack(
      children: [
        if (skin.backgroundBuilder != null) Positioned.fill(child: skin.backgroundBuilder!()),
        SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: layout.leftRegion,
                child: Center(child: _buildDial(context, layout.dialSize)),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, skin.timerOffsetY),
                      child: TimerWidget(numberHeight: numberHeight),
                    ),
                    SizedBox(height: numberHeight * 0.4),
                    const BottomButtonWidet(landscape: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isGranted)
          SafeArea(
            child: Align(alignment: Alignment.topRight, child: _notificationButton()),
          ),
      ],
    );
  }
```

- [ ] **Step 5: build에서 방향 분기**

`build`의 비-디버그 분기(`if (!_debugAspectRatio) { ... }`) 내부를 아래로 교체한다. 세로는 기존과 동일, 가로는 `computeLandscapeLayout` + `_buildLandscapeContent` 사용:

```dart
    if (!_debugAspectRatio) {
      double maxHeight = 100.h;
      double maxWidth = 100.w;

      if (maxWidth < maxHeight) {
        // 세로: 기존 동작 유지
        final double clockSize = maxWidth * 0.9;
        return Scaffold(
          backgroundColor: skin.backgroundColor,
          body: !isLoaded
              ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 189, 189, 189)))
              : _buildContent(context, clockSize),
        );
      }

      // 가로: 다이얼 왼쪽 / 텍스트+버튼 오른쪽
      final layout = computeLandscapeLayout(width: maxWidth, height: maxHeight);
      final double landscapeNumberHeight = math.min(
        layout.rightRegion * 0.85 / (100 / 10.5), // 타이머 폭을 패널의 약 85%에 맞춤
        maxHeight * 0.14, // 높이 상한
      );
      return Scaffold(
        backgroundColor: skin.backgroundColor,
        body: !isLoaded
            ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 189, 189, 189)))
            : _buildLandscapeContent(context, layout, landscapeNumberHeight),
      );
    }
```

(참고: `math`는 `home_screen.dart`에 이미 `import 'dart:math' as math;`로 임포트돼 있어 추가 불필요.)

- [ ] **Step 6: analyze로 검증**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: 이번 변경으로 인한 새 이슈 0. (미사용 변수/임포트 없음.)

- [ ] **Step 7: main.dart 회전 잠금 해제**

`lib/main.dart`의 다음 줄을 교체:

```dart
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
```

교체 후:

```dart
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
```

- [ ] **Step 8: analyze로 검증**

Run: `flutter analyze lib/main.dart`
Expected: No issues found!

- [ ] **Step 9: 커밋**

```bash
git add lib/screens/home_screen.dart lib/main.dart
git commit -m "feat: 가로모드 레이아웃 분기 및 회전 잠금 해제"
```

---

### Task 6: 전체 검증 (analyze + test + 실제 구동)

**Files:**
- 없음(검증 전용).

- [ ] **Step 1: 정적 분석 전체**

Run: `flutter analyze`
Expected: No issues found! (또는 우리 변경과 무관한 사전 경고만.)

- [ ] **Step 2: 유닛 테스트 전체**

Run: `flutter test test/screens/landscape_layout_test.dart test/skins/ test/models/ test/providers/`
Expected: All tests passed!

(주의: `test/widget_test.dart`는 기본 카운터 템플릿으로 이 앱과 무관하며 사전부터 실패한다. 이번 작업 범위 밖 — 손대지 않는다. 실패가 확인되면 사용자에게 별도 안내.)

- [ ] **Step 3: 실제 구동 — 세로 회귀 확인**

기기/에뮬레이터에서 `flutter run` 후 세로 상태로 세 스킨(apple/wash/school)을 change 버튼으로 순회하며 다음을 확인:
- 타이머 텍스트 위치·크기, 다이얼, 버튼 배치가 기존과 동일.
- wash 세탁기 오버레이가 타이머 숫자와 정렬 유지.

Expected: 세로 화면이 변경 전과 육안상 동일.

- [ ] **Step 4: 실제 구동 — 가로 확인**

기기를 가로로 회전(좌/우 모두) 후 세 스킨 각각에서 확인:
- 다이얼이 왼쪽, 시간 텍스트 위·버튼 2개 아래가 오른쪽에 배치.
- 다이얼:버튼 비율이 6:4 근처(폰 기준).
- 다이얼 터치로 시간 설정이 정확히 동작(회전 직후 포함).
- play/stop·change 버튼 동작 정상.

Expected: 예시 이미지와 유사한 가로 레이아웃, 모든 상호작용 정상.

- [ ] **Step 5: 최종 상태 확인**

Run: `git status`
Expected: 모든 변경이 커밋됨(working tree clean). 미커밋 잔여물 없음.

---

## Self-Review 노트

- **Spec coverage:** 회전 정책(Task 5·main.dart), 가로 분할 규칙(Task 1), 오른쪽 패널(Task 5), TimerWidget 리팩터·wash 오버레이 스케일(Task 2), BottomButtonWidet 가로(Task 3), 알림 버튼(Task 5 Step 3), 다이얼 터치 회전 버그(Task 4), school 배경 범위 밖(Global Constraints) — 스펙 각 항목이 태스크에 매핑됨.
- **Type consistency:** `computeLandscapeLayout`/`LandscapeLayout`(leftRegion/dialSize/rightRegion), `TimerWidget(numberHeight)`, `BottomButtonWidet(landscape)`, `_buildDial`/`_buildLandscapeContent`/`_notificationButton` 명칭이 정의처와 사용처에서 일치.
- **Placeholder scan:** TBD/TODO 없음. 모든 코드 스텝에 실제 코드 포함.
- **가로 numberHeight 계수(0.85, 0.14)**: 시각 튜닝 값. Task 6 육안 확인에서 필요 시 조정 가능(로직 정확성과 무관).
