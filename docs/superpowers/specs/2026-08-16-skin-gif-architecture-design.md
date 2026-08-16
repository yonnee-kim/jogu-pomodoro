# 스킨 GIF 아키텍처 개선 설계

날짜: 2026-08-16
브랜치: worktree-skin-gif-architecture

## 배경과 문제

- 현재 `HomeScreen._buildDial`은 등록된 모든 스킨의 `PomodoroCast`를 `IndexedStack`에 넣어 전부 살려둔다. 스킨이 늘수록 안 보이는 스킨의 타이머·GIF 디코딩 비용이 누적된다.
- 이렇게 한 이유: 애니메이션 상태가 타이머 상태로부터 계산되지 않고, 위젯이 계속 살아있어야만 유지되기 때문. 스킨 전환으로 중간 진입하면 올바른 애니메이션 지점에서 시작할 수 없었다.
  - apple: 자체 100ms `Timer.periodic`으로 남은 시간을 복제해 센다 (DataProvider와 이중 관리, 드리프트 가능).
  - wash: 4개 `GifController`의 `onFinish` 콜백 체인으로만 상태가 이어진다.

## 핵심 원칙

애니메이션 상태는 타이머 상태(`startSec`, `currMillisec`, `isStarted`)에서 언제든 순수함수로 계산 가능해야 한다. 위젯은 마운트 시점에 이 계산만으로 올바른 화면을 그린다.

## 합의된 동작 규칙

- 동기화 수준: "구간만 맞추기". 중간 진입 시 올바른 구간의 루프 GIF를 프레임 0부터 재생. 프레임 단위 정밀 동기화는 하지 않는다 (지금도 루프 위치는 타이머와 무관하므로 체감 동등).
- 인트로/전환 모션은 사용자가 해당 스킨을 보면서 경계 통과·버튼 조작을 직접 목격했을 때만 재생. 중간 진입 시에는 생략하고 바로 루프부터.

## 변경 1: HomeScreen — 단일 스킨 빌드

- `_buildDial`의 `IndexedStack` 제거. `skinConfigs[themeIndex]` 하나로만 `PomodoroCast` 생성.
- `KeyedSubtree(key: ValueKey(config.id))`로 감싸 스킨 전환 시 이전 모션 위젯 dispose와 새 위젯 fresh 마운트를 보장.
- 세로/가로 레이아웃 모두 `_buildDial`을 사용하므로 수정 지점은 한 곳.

프리캐시 전략:

- `initFunc`은 지금처럼 현재 스킨을 await로 프리캐시하고 `isLoaded = true`.
- 그 후 나머지 스킨들을 백그라운드로 순차 프리캐시(`precacheImages` + `prefetchGifImages`, await로 시작을 막지 않음). 실패는 try-catch로 로그만 남긴다.
- 최악의 경우(미캐시 상태 전환)에도 `MyGif`의 `progressBuilder` 폴백이 동작한다.
- 메모리는 기존과 동일(지금도 전 스킨 캐시 상주), CPU는 스킨 1개분으로 고정된다.

## 변경 2: apple 모션 위젯

`lib/skins/apple/apple_motion_widget.dart`, `apple_motion_logic.dart`

- `_debounce`(자체 100ms 타이머)와 `currMilliSec` 복제 변수 삭제. DataProvider의 초당 알림을 `Selector`로 구독해 매번 순수함수로 표시할 GIF를 계산.
- `apple_motion_logic.dart`에 추가 (기존 함수는 유지):
  - `appleSegment(startSec, currMillisec)` → 현재 구간 (1: 시작/대기, 2: 남은 시간 2/3 초과, 3: 1/3~2/3, 4: 0~1/3)
  - 구간 → 인트로 GIF / blink 루프 GIF 매핑
  - 인트로 길이는 기존 `getGifDurationMilliSec` 재사용
- 인트로 재생 규칙:
  - 위젯이 직전 빌드의 구간을 기억하다가, 재생 중 구간이 바뀐 것을 목격하면 인트로 재생 → 끝나면 blink 루프.
  - 마운트 직후(직전 구간 기록 없음)에는 곧바로 blink 루프.
  - 인트로 → blink 전환은 인트로 길이만큼의 일회성 `Timer` 예약으로 처리. dispose 시 취소, 어긋나면 다음 초당 알림에서 자동 보정. (시간 상태 복제가 아닌 파생 예약)
- 일시정지/종료 상태는 기존 `getAppleGifForPause` 그대로 사용.
- 렌더링은 `Image.asset(gaplessPlayback: true)` 유지. `AssetImage.evict()`는 인트로 GIF를 처음부터 재생해야 할 때만 호출하도록 한정.

## 변경 3: wash 모션 위젯

`lib/skins/wash/wash_motion_widget.dart`, 새 파일 `lib/skins/wash/wash_motion_logic.dart`

- 4개 GIF(blink/start/activate/stop)·내부 `IndexedStack`·`GifController` 구조는 유지.
- 마운트 시 `isStarted`로 초기 상태 유도: 작동 중이면 activate 루프, 아니면 blink. (현재는 중간 진입 시 start 전환 모션부터 재생 — 제거)
- 상태 전이를 순수함수로 통합: `washNextState(끝난 모션, isStarted) → 다음 모션`을 `wash_motion_logic.dart`에 정의하고, 4개 콜백은 이 함수를 호출만 한다.
- 직전 `isStarted`를 기억해, 보이는 중 값이 바뀌면 전환 모션 재생 (false→true: start, true→false: stop).

## 테스트

- `test/skins/apple/`: `appleSegment` 경계값(정확히 2/3·1/3·0·시작 직후), 구간→인트로/blink 매핑. 기존 apple 로직 테스트 유지.
- `test/skins/wash/`: `washNextState` 전이표 전체 케이스.
- 기존 테스트(레지스트리, 에셋 경로, 스킨 설정) 전부 통과가 회귀 기준.
- 스킨 전환 중간 진입의 실기기 확인은 사용자가 직접 수행 (앱 실행은 사용자 몫).

## 범위 제외 (YAGNI)

- 프레임 단위 정밀 동기화 (GifController.seek 기반) — 필요해지면 그때.
- 모션 타임라인 공용 인터페이스 추상화 — 스킨 3개에는 과설계. GIF 스킨이 더 늘면 이번 구조에서 자연스럽게 추출.
- apple 렌더링의 GifView 전환.
