import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/skins/apple/apple_motion_logic.dart';

void main() {
  group('getGifDurationMilliSec', () {
    test('apple_01.gif는 1프레임 = 0초 (반올림)', () {
      expect(getGifDurationMilliSec('assets/gif/apple/apple_01.gif'), 0);
    });

    test('apple_01_blink.gif는 46프레임', () {
      // 0.04 * 46 = 1.84 → round() = 2 → * 1000 = 2000
      expect(getGifDurationMilliSec('assets/gif/apple/apple_01_blink.gif'), 2000);
    });

    test('apple_02.gif는 72프레임', () {
      // 0.04 * 72 = 2.88 → round() = 3 → * 1000 = 3000
      expect(getGifDurationMilliSec('assets/gif/apple/apple_02.gif'), 3000);
    });

    test('apple_04.gif는 80프레임', () {
      // 0.04 * 80 = 3.2 → round() = 3 → * 1000 = 3000
      expect(getGifDurationMilliSec('assets/gif/apple/apple_04.gif'), 3000);
    });

    test('알 수 없는 GIF 경로는 0 반환', () {
      expect(getGifDurationMilliSec('assets/gif/unknown.gif'), 0);
    });
  });

  group('getAppleGifForPause', () {
    const int startSec = 60;

    test('2/3 이상 남았을 때 → apple_02_blink.gif', () {
      final result = getAppleGifForPause(
        startSec: startSec,
        currentMilliSec: 50000,
      );
      expect(result, 'assets/gif/apple/apple_02_blink.gif');
    });

    test('1/3~2/3 남았을 때 → apple_03_blink.gif', () {
      final result = getAppleGifForPause(
        startSec: startSec,
        currentMilliSec: 30000,
      );
      expect(result, 'assets/gif/apple/apple_03_blink.gif');
    });

    test('0~1/3 남았을 때 → apple_04_blink.gif', () {
      final result = getAppleGifForPause(
        startSec: startSec,
        currentMilliSec: 10000,
      );
      expect(result, 'assets/gif/apple/apple_04_blink.gif');
    });

    test('타이머 완료 → apple_01_blink.gif', () {
      final result = getAppleGifForPause(
        startSec: startSec,
        currentMilliSec: 0,
      );
      expect(result, 'assets/gif/apple/apple_01_blink.gif');
    });
  });

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

  group('isWitnessedTick', () {
    test('직전 값 없음(마운트 직후) → false', () {
      expect(isWitnessedTick(lastMilliSec: null, currentMilliSec: 40000), false);
    });

    test('정상 1초 틱 → true', () {
      expect(isWitnessedTick(lastMilliSec: 40000, currentMilliSec: 39000), true);
    });

    test('큰 시간 점프(백그라운드 복귀) → false', () {
      expect(isWitnessedTick(lastMilliSec: 40000, currentMilliSec: 20000), false);
    });

    test('시간 증가(다이얼 재설정 등) → false', () {
      expect(isWitnessedTick(lastMilliSec: 20000, currentMilliSec: 40000), false);
    });

    test('경계 1500ms까지 허용', () {
      expect(isWitnessedTick(lastMilliSec: 40000, currentMilliSec: 38500), true);
      expect(isWitnessedTick(lastMilliSec: 40000, currentMilliSec: 38499), false);
    });
  });

  group('isDialAdjusted', () {
    test('직전 값 없음(마운트 직후) → false', () {
      expect(isDialAdjusted(lastMilliSec: null, currentMilliSec: 1800000), false);
    });

    test('분 단위 스냅 점프(다이얼 조작) → true', () {
      // 0분 → 30분으로 늘리기
      expect(isDialAdjusted(lastMilliSec: 0, currentMilliSec: 1800000), true);
      // 30분 → 29분으로 줄이기
      expect(isDialAdjusted(lastMilliSec: 1800000, currentMilliSec: 1740000), true);
    });

    test('재생 중 일시정지 시 1초 미만 드리프트 → false', () {
      // 초당 알림 사이에 정지하면 마지막 목격값과 수백 ms 차이가 난다
      expect(isDialAdjusted(lastMilliSec: 40000, currentMilliSec: 39300), false);
    });

    test('경계 2000ms 미만 델타는 조작으로 보지 않음', () {
      expect(isDialAdjusted(lastMilliSec: 40000, currentMilliSec: 38001), false);
      expect(isDialAdjusted(lastMilliSec: 40000, currentMilliSec: 38000), true);
    });
  });
}
