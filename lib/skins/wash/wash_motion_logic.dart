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
