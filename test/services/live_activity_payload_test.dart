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
