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

  group('getAppleGifForProgress', () {
    // 60초 타이머 기준: 2/3 마일스톤 = 40초(40000ms), 1/3 마일스톤 = 20초(20000ms)
    const int startSec = 60;

    test('시작 직후 (currMilliSec == startSec * 1000) → apple_02.gif', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 60000,
        currentGif: 'assets/gif/apple/apple_01_blink.gif',
      );
      expect(result, 'assets/gif/apple/apple_02.gif');
    });

    test('2/3~1 구간에서 GIF 재생 완료 후 → apple_02_blink.gif', () {
      // apple_02.gif 재생시간(3000ms) 경과 후
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 60000 - 3000 - 100, // GIF 재생시간 + 100ms 경과
        currentGif: 'assets/gif/apple/apple_02.gif',
      );
      expect(result, 'assets/gif/apple/apple_02_blink.gif');
    });

    test('이미 blink 상태면 변경하지 않음 (apple_02_blink)', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 50000,
        currentGif: 'assets/gif/apple/apple_02_blink.gif',
      );
      expect(result, 'assets/gif/apple/apple_02_blink.gif');
    });

    test('2/3 마일스톤 도달 → apple_03.gif', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 40000, // (60 * 2/3).round() * 1000
        currentGif: 'assets/gif/apple/apple_02_blink.gif',
      );
      expect(result, 'assets/gif/apple/apple_03.gif');
    });

    test('1/3~2/3 구간에서 GIF 재생 완료 후 → apple_03_blink.gif', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 40000 - 3000 - 100,
        currentGif: 'assets/gif/apple/apple_03.gif',
      );
      expect(result, 'assets/gif/apple/apple_03_blink.gif');
    });

    test('1/3 마일스톤 도달 → apple_04.gif', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 20000, // (60 * 1/3).round() * 1000
        currentGif: 'assets/gif/apple/apple_03_blink.gif',
      );
      expect(result, 'assets/gif/apple/apple_04.gif');
    });

    test('0~1/3 구간에서 GIF 재생 완료 후 → apple_04_blink.gif (버그 수정 검증)', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 20000 - 3000 - 100,
        currentGif: 'assets/gif/apple/apple_04.gif',
      );
      expect(result, 'assets/gif/apple/apple_04_blink.gif');
    });

    test('이미 apple_04_blink 상태면 변경하지 않음', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 10000,
        currentGif: 'assets/gif/apple/apple_04_blink.gif',
      );
      expect(result, 'assets/gif/apple/apple_04_blink.gif');
    });

    test('완료 (currMilliSec <= 0) → apple_01.gif', () {
      final result = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: 0,
        currentGif: 'assets/gif/apple/apple_04_blink.gif',
      );
      expect(result, 'assets/gif/apple/apple_01.gif');
    });

    test('홀수 초 타이머에서도 마일스톤 정확히 계산', () {
      // 45초 타이머: 2/3 = 30초, 1/3 = 15초
      final result = getAppleGifForProgress(
        startSec: 45,
        currentMilliSec: 30000,
        currentGif: 'assets/gif/apple/apple_02_blink.gif',
      );
      expect(result, 'assets/gif/apple/apple_03.gif');
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
}
