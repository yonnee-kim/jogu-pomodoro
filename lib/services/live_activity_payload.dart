/// Live Activity 페이로드 생성, 제어 액션 파싱, 네이티브 동기화 해석 (순수 함수).
/// App Group UserDefaults는 문자열만 저장하므로 모든 값을 문자열로 변환한다.

enum LiveActivityAction { pause, resume, cancel, unknown }

enum ReconcileKind { none, pausedAway, runningAway, finishedAway, cancelledAway }

class ReconcileResult {
  final ReconcileKind kind;
  final int newMillisec;
  const ReconcileResult(this.kind, this.newMillisec);
}

/// 실행 중(카운트다운) 상태 페이로드.
/// notifTitle/notifBody는 위젯 버튼(재개)이 앱 프로세스의 Swift Intent에서
/// 종료 알림을 재예약할 때 사용한다.
Map<String, dynamic> buildRunningPayload({
  required DateTime endDate,
  required int totalSeconds,
  required String label,
  required String doneLabel,
  required String notifTitle,
  required String notifBody,
}) {
  return {
    'endDateMs': endDate.millisecondsSinceEpoch.toString(),
    'isPaused': 'false',
    'remainingSeconds': '0',
    'totalSeconds': totalSeconds.toString(),
    'label': label,
    'doneLabel': doneLabel,
    'notifTitle': notifTitle,
    'notifBody': notifBody,
  };
}

/// 일시정지 상태 페이로드. remainingSeconds로 고정 표시.
Map<String, dynamic> buildPausedPayload({
  required int remainingSeconds,
  required int totalSeconds,
  required String label,
}) {
  return {
    'endDateMs': '0',
    'isPaused': 'true',
    'remainingSeconds': remainingSeconds.toString(),
    'totalSeconds': totalSeconds.toString(),
    'label': label,
  };
}

/// 네이티브가 전달한 액션명('pause'|'resume'|'cancel')을 변환.
LiveActivityAction parseLiveActivityAction(String name) {
  switch (name) {
    case 'pause':
      return LiveActivityAction.pause;
    case 'resume':
      return LiveActivityAction.resume;
    case 'cancel':
      return LiveActivityAction.cancel;
    default:
      return LiveActivityAction.unknown;
  }
}

/// Swift Intent가 남긴 동기화 스냅샷을 Dart 타이머 상태 변화로 해석한다.
ReconcileResult reconcileFromSync({
  required LiveActivityAction action,
  required int endDateMs,
  required int remainingMs,
  required DateTime now,
}) {
  switch (action) {
    case LiveActivityAction.pause:
      return ReconcileResult(ReconcileKind.pausedAway, remainingMs);
    case LiveActivityAction.resume:
      final remaining = endDateMs - now.millisecondsSinceEpoch;
      if (remaining > 0) {
        return ReconcileResult(ReconcileKind.runningAway, remaining);
      }
      return const ReconcileResult(ReconcileKind.finishedAway, 0);
    case LiveActivityAction.cancel:
      return const ReconcileResult(ReconcileKind.cancelledAway, 0);
    case LiveActivityAction.unknown:
      return const ReconcileResult(ReconcileKind.none, 0);
  }
}

/// Android 진행형 알림 시작 페이로드 (MethodChannel 'start' 인자).
/// iOS와 달리 UserDefaults 문자열 제약이 없으므로 원 타입 그대로 전달한다.
Map<String, dynamic> buildAndroidStartPayload({
  required DateTime endDate,
  required String label,
  required String notifTitle,
  required String notifBody,
  required String totalLabel,
  required String pauseLabel,
  required String resumeLabel,
  required String cancelLabel,
}) {
  return {
    'endDateMs': endDate.millisecondsSinceEpoch,
    'label': label,
    'notifTitle': notifTitle,
    'notifBody': notifBody,
    'totalLabel': totalLabel,
    'pauseLabel': pauseLabel,
    'resumeLabel': resumeLabel,
    'cancelLabel': cancelLabel,
  };
}

/// Android 진행형 알림 일시정지 페이로드 (MethodChannel 'updatePaused' 인자).
Map<String, dynamic> buildAndroidPausedPayload({
  required int remainingSeconds,
  required String label,
}) {
  return {
    'remainingSeconds': remainingSeconds,
    'label': label,
  };
}
