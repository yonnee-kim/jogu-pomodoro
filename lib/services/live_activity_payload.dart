/// Live Activity 페이로드 생성 및 딥링크 파싱 (순수 함수).
/// App Group UserDefaults는 문자열만 저장하므로 모든 값을 문자열로 변환한다.

enum LiveActivityAction { pause, resume, cancel, unknown }

/// 실행 중(카운트다운) 상태 페이로드.
Map<String, dynamic> buildRunningPayload({
  required DateTime endDate,
  required String label,
}) {
  return {
    'endDateMs': endDate.millisecondsSinceEpoch.toString(),
    'isPaused': 'false',
    'remainingSeconds': '0',
    'label': label,
  };
}

/// 일시정지 상태 페이로드. remainingSeconds로 고정 표시.
Map<String, dynamic> buildPausedPayload({
  required int remainingSeconds,
  required String label,
}) {
  return {
    'endDateMs': '0',
    'isPaused': 'true',
    'remainingSeconds': remainingSeconds.toString(),
    'label': label,
  };
}

/// 딥링크 path(예: '/pause')를 액션으로 변환.
LiveActivityAction parseLiveActivityAction(String path) {
  switch (path) {
    case '/pause':
      return LiveActivityAction.pause;
    case '/resume':
      return LiveActivityAction.resume;
    case '/cancel':
      return LiveActivityAction.cancel;
    default:
      return LiveActivityAction.unknown;
  }
}
