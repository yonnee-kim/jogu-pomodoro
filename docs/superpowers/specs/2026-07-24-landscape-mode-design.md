# 가로모드 지원 설계

## 목표

세로모드 고정인 뽀모도로 앱에 가로모드를 추가한다. 가로에서는 다이얼을 왼쪽, 시간 텍스트와 버튼부를 오른쪽에 배치한다. 세로모드 동작·레이아웃은 전부 그대로 유지한다.

## 회전 정책

- 기기 회전 자동. 세로(portraitUp) + 좌/우 가로(landscapeLeft, landscapeRight) 허용.
- portraitDown 제외.
- `main.dart`의 `setPreferredOrientations([portraitUp])` → `[portraitUp, landscapeLeft, landscapeRight]`.
- `ResponsiveSizer`가 회전 시 리빌드하므로 `.w`/`.h`는 현재 방향 기준으로 갱신된다.

## 가로 레이아웃 규칙

- 화면을 `Row[ 왼쪽 다이얼 영역, 오른쪽 패널 ]`로 구성.
- 다이얼영역 : 버튼영역 = 6 : 4 기본. 조정 가능한 상수로 분리.
- 다이얼은 왼쪽 영역 안에서 높이 기준으로 최대한 크게. 화면 중앙이 아니라 왼쪽 고정.
- 6:4에서 다이얼이 최대높이에 못 미치면(좁은 화면) 왼쪽 영역을 6 이상으로 넓혀 다이얼을 키운다.
- 단, 버튼영역은 최소 20% 보장.

레이아웃 상수:

- `dialRegionRatio = 0.6` — 다이얼 영역 기본 비율
- `panelMinRatio = 0.2` — 버튼(오른쪽) 영역 최소 비율
- `dialHeightFactor = 0.9` — 다이얼 최대 크기 = 화면 높이 × 이 값

계산 알고리즘 (W = 화면폭, H = 화면높이, 가로일 때 W > H):

```
leftRegion = W * dialRegionRatio            // 기본 6:4
maxDialByHeight = H * dialHeightFactor
if (leftRegion < maxDialByHeight)           // 6:4에선 다이얼이 최대높이 못 채움
    leftRegion = min(maxDialByHeight, W * (1 - panelMinRatio))  // 넓히되 버튼영역 >= 20%
dialSize    = min(leftRegion, maxDialByHeight)
rightRegion = W - leftRegion
```

기기별 기대 결과:

- 일반 폰 가로(약 2.2:1): 다이얼 60% 열 안에 높이 꽉 참, 버튼 40% → 6:4
- 태블릿 가로(약 1.33:1): 다이얼 열 약 68%로 확장, 버튼 약 32%
- 거의 정사각 화면: 다이얼 열 80% 상한, 버튼 20% 하한

## 컴포넌트 설계

### HomeScreen (`lib/screens/home_screen.dart`)

- `build`에서 방향 판별(W > H) 후 세로/가로 레이아웃으로 분기.
- 다이얼 생성부(`IndexedStack` of `PomodoroCast`)는 헬퍼로 추출해 세로/가로가 clockSize만 다르게 재사용.
- 세로: 기존 Column 레이아웃(`_buildContent`) 유지.
- 가로: `Row[ SizedBox(width: leftRegion, child: Center(다이얼)), Expanded(child: 오른쪽 패널) ]`.
- 오른쪽 패널: `Column(mainAxisAlignment: center)[ TimerWidget, 간격, BottomButtonWidet(landscape) ]`.
- 알림 권한 버튼: 가로에서도 우상단 유지.
- 레이아웃 상수 3개는 State 상단 static const로 분리.

### TimerWidget (`lib/widgets/timer_widget.dart`)

핵심 문제: 내부 치수가 전부 `.w`(가로폭 비례)라 가로모드에서 크기가 폭발한다. `10.5.w` 숫자높이, `51.w × 100.w` 오버레이 박스, `Transform.translate(-0.8.w, 2.3.w)`, 숫자 간격 `0.8.w`, 콜론 패딩 `3.w`.

해결: 내부 모든 치수를 단일 기준값 `numberHeight`(=`unit`)의 배수로 표현한다.

- 오버레이 박스 높이 = `unit * (51/10.5)`
- 오버레이 박스 폭 = `unit * (100/10.5)`
- Transform 오프셋 = `(unit * (-0.8/10.5), unit * (2.3/10.5))`
- 숫자 간격 = `unit * (0.8/10.5)`
- 콜론 패딩 = `unit * (3/10.5)`

`TimerWidget`에 옵셔널 `double? numberHeight` 파라미터 추가:

- null(세로): `unit = 10.5.w` → 기존과 픽셀 동일, 동작 변화 없음.
- 값 전달(가로): 오른쪽 패널 폭 기반값(높이 상한 포함) → 모든 정렬·간격이 비율 그대로 축소.

효과: wash 스킨 세탁기 머리 오버레이(`timerOverlayBuilder`, `51.w×100.w` 박스에 그려짐)도 같은 기준으로 스케일되어 숫자와의 상대 위치가 세로와 동일하게 유지된다. 스킨별 정렬 문제가 자동 해결된다.

가로 `numberHeight` 산출: 오른쪽 패널 폭에 맞춰 타이머 전체 폭이 패널 안에 들어오도록 계산하고, 화면 높이 상한을 함께 적용한다. 구체 계수는 구현 중 조정.

### BottomButtonWidet (`lib/screens/home_screen.dart`)

- 파라미터 추가(`landscape` 플래그). 버튼 위젯 자체(60px play/stop + change)는 동일.
- 세로: 기존 `Row(spaceBetween, padding 35)` 유지.
- 가로: `Row(mainAxisAlignment: center, mainAxisSize: min, [playStop, 간격, change])`.

### PomodoroCast (`lib/widgets/pomodoro_cast.dart`) — 버그 수정

- 현재 `center = clockSize/2`를 `initState`에서 1회만 계산. 회전으로 `clockSize`가 바뀌면 다이얼 터치 각도 계산이 틀어진다.
- `onPanUpdate`에서 `widget.clockSize` 기준으로 center를 계산하도록 수정(캐시 필드 제거 또는 `didUpdateWidget` 갱신).

## 범위 밖 (이번 작업 제외)

- school 스킨 가로 전용 배경: 지금은 기존 세로용 배경 그대로 사용. 추후 가로용 배경 파일을 받으면 skin config에 가로 전용 `backgroundBuilder`를 추가한다.
- 버튼 크기 반응형: 가로에서도 60px 고정 유지(추후 필요 시 조정).

## 변경 파일

- `lib/main.dart` — 회전 잠금 해제
- `lib/screens/home_screen.dart` — 방향 분기 + 가로 레이아웃 + 버튼 옵션 + 상수
- `lib/widgets/timer_widget.dart` — numberHeight 기준 리팩터
- `lib/widgets/pomodoro_cast.dart` — center 계산 수정

## 검증 기준

- 세로모드: 세 스킨(apple/wash/school) 모두 기존과 동일하게 렌더링.
- 가로모드: 다이얼 왼쪽, 시간 텍스트+버튼 오른쪽. 6:4 비율(좁은 화면에선 규칙대로 확장).
- 회전 후 다이얼 터치로 시간 설정이 정확히 동작.
- wash 세탁기 오버레이가 가로에서도 숫자와 정렬 유지.
- `flutter analyze` 통과, 기존 테스트 통과.
