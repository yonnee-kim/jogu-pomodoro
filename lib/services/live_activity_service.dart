import 'dart:io';

import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/url_scheme_data.dart';

import 'live_activity_payload.dart';

/// live_activities 패키지 래퍼. iOS 외/미지원 환경에서는 모든 메서드가 no-op.
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const String appGroupId = 'group.com.joguman.pomodoro';
  static const String urlScheme = 'joguman';

  final LiveActivities _plugin = LiveActivities();
  String? _activityId;
  bool _initialized = false;

  Future<void> init() async {
    if (!Platform.isIOS) return;
    await _plugin.init(appGroupId: appGroupId, urlScheme: urlScheme);
    _initialized = true;
  }

  Stream<UrlSchemeData> get urlSchemeStream => Platform.isIOS
      ? _plugin.urlSchemeStream()
      : const Stream<UrlSchemeData>.empty();

  Future<bool> _enabled() async {
    if (!Platform.isIOS || !_initialized) return false;
    return _plugin.areActivitiesEnabled();
  }

  /// 실행 중 상태로 시작(없으면 생성) 또는 갱신.
  Future<void> startOrUpdateRunning({
    required DateTime endDate,
    required String label,
  }) async {
    if (!await _enabled()) return;
    final data = buildRunningPayload(endDate: endDate, label: label);
    if (_activityId == null) {
      _activityId = await _plugin.createActivity(
        DateTime.now().millisecondsSinceEpoch.toString(),
        data,
      );
    } else {
      await _plugin.updateActivity(_activityId!, data);
    }
  }

  /// 일시정지 상태로 갱신.
  Future<void> updatePaused({
    required int remainingSeconds,
    required String label,
  }) async {
    if (!await _enabled() || _activityId == null) return;
    await _plugin.updateActivity(
      _activityId!,
      buildPausedPayload(remainingSeconds: remainingSeconds, label: label),
    );
  }

  /// 활동 종료 및 제거.
  Future<void> end() async {
    if (!Platform.isIOS || _activityId == null) return;
    final id = _activityId!;
    _activityId = null;
    await _plugin.endActivity(id);
  }
}
