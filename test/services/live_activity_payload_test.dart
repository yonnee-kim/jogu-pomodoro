import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/services/live_activity_payload.dart';

void main() {
  group('buildRunningPayload', () {
    test('종료시각을 epoch ms 문자열로, isPaused는 false로 담는다', () {
      final end = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final map = buildRunningPayload(
        endDate: end,
        label: '집중',
        notifTitle: '알림제목',
        notifBody: '알림본문',
      );

      expect(map['endDateMs'], '1700000000000');
      expect(map['isPaused'], 'false');
      expect(map['label'], '집중');
      expect(map['remainingSeconds'], '0');
      // 모든 값은 문자열이어야 한다 (App Group UserDefaults 제약)
      expect(map.values.every((v) => v is String), isTrue);
    });

    test('알림 제목/본문 키를 포함한다', () {
      final payload = buildRunningPayload(
        endDate: DateTime.fromMillisecondsSinceEpoch(1000),
        label: '집중',
        notifTitle: '조구만 뽀모도로',
        notifBody: '끝!',
      );
      expect(payload['notifTitle'], '조구만 뽀모도로');
      expect(payload['notifBody'], '끝!');
      expect(payload['endDateMs'], '1000');
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
    test('bare 액션명을 파싱한다', () {
      expect(parseLiveActivityAction('pause'), LiveActivityAction.pause);
      expect(parseLiveActivityAction('resume'), LiveActivityAction.resume);
      expect(parseLiveActivityAction('cancel'), LiveActivityAction.cancel);
    });
    test('알 수 없는 입력은 unknown', () {
      expect(parseLiveActivityAction('/pause'), LiveActivityAction.unknown);
      expect(parseLiveActivityAction(''), LiveActivityAction.unknown);
    });
  });

  group('reconcileFromSync', () {
    final now = DateTime.fromMillisecondsSinceEpoch(100000);

    test('pause → pausedAway, 남은 시간 유지', () {
      final r = reconcileFromSync(
          action: LiveActivityAction.pause, endDateMs: 0, remainingMs: 65000, now: now);
      expect(r.kind, ReconcileKind.pausedAway);
      expect(r.newMillisec, 65000);
    });
    test('resume + 종료 시각 미래 → runningAway, 남은 시간 재계산', () {
      final r = reconcileFromSync(
          action: LiveActivityAction.resume, endDateMs: 160000, remainingMs: 0, now: now);
      expect(r.kind, ReconcileKind.runningAway);
      expect(r.newMillisec, 60000);
    });
    test('resume + 종료 시각 경과 → finishedAway', () {
      final r = reconcileFromSync(
          action: LiveActivityAction.resume, endDateMs: 90000, remainingMs: 0, now: now);
      expect(r.kind, ReconcileKind.finishedAway);
      expect(r.newMillisec, 0);
    });
    test('cancel → cancelledAway', () {
      final r = reconcileFromSync(
          action: LiveActivityAction.cancel, endDateMs: 0, remainingMs: 0, now: now);
      expect(r.kind, ReconcileKind.cancelledAway);
    });
    test('unknown → none', () {
      final r = reconcileFromSync(
          action: LiveActivityAction.unknown, endDateMs: 0, remainingMs: 0, now: now);
      expect(r.kind, ReconcileKind.none);
    });
  });

  group('buildAndroidStartPayload', () {
    test('MethodChannel용 타입 그대로 담는다 (endDateMs는 int)', () {
      final payload = buildAndroidStartPayload(
        endDate: DateTime.fromMillisecondsSinceEpoch(1234567890000),
        label: '집중',
        notifTitle: '조구만 뽀모도로 타이머',
        notifBody: '끝!',
        totalLabel: '50분',
        pauseLabel: '일시정지',
        resumeLabel: '재개',
        cancelLabel: '취소',
      );
      expect(payload, {
        'endDateMs': 1234567890000,
        'label': '집중',
        'notifTitle': '조구만 뽀모도로 타이머',
        'notifBody': '끝!',
        'totalLabel': '50분',
        'pauseLabel': '일시정지',
        'resumeLabel': '재개',
        'cancelLabel': '취소',
      });
    });
  });

  group('buildAndroidPausedPayload', () {
    test('remainingSeconds는 int로 담는다', () {
      final payload =
          buildAndroidPausedPayload(remainingSeconds: 2700, label: '집중');
      expect(payload, {'remainingSeconds': 2700, 'label': '집중'});
    });
  });
}
