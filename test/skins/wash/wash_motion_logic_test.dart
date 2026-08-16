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
