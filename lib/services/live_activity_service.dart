import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_state.dart';

import 'live_activity_payload.dart';

/// live_activities 패키지 래퍼. iOS 외/미지원 환경에서는 모든 메서드가 no-op.
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const String appGroupId = 'group.com.joguman.pomodoro';

  static const MethodChannel _syncChannel =
      MethodChannel('com.joguman.pomodoro/live_activity');

  final LiveActivities _plugin = LiveActivities();
  String? _activityId;
  bool _initialized = false;

  Future<void> init() async {
    if (!Platform.isIOS) return; // Android는 사전 초기화 불필요(상태는 네이티브 prefs가 소유)
    try {
      await _plugin.init(appGroupId: appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('[LA] init 실패: $e');
    }
    // _activityId는 프로세스 메모리에만 있어 재시작 시 null로 초기화된다.
    // Live Activity 자체는 앱 종료 후에도 살아남으므로, 기존 활동을 입양하지 않으면
    // startOrUpdateRunning이 중복 활동을 만들고 end()/updatePaused가 no-op이 된다.
    try {
      final existing = await _plugin.getAllActivities();
      for (final entry in existing.entries) {
        if (entry.value == LiveActivityState.active) {
          _activityId = entry.key;
          break;
        }
      }
    } catch (e) {
      debugPrint('[LA] 기존 활동 입양 실패: $e');
    }
  }

  /// 네이티브(iOS Swift Intent / Android Receiver)가 남긴 동기화 스냅샷을 읽고 비운다. 없으면 null.
  Future<Map<String, String>?> consumeSync() async {
    if (!Platform.isIOS && !Platform.isAndroid) return null;
    try {
      final raw = await _syncChannel.invokeMethod<Map>('consumeSync');
      return raw?.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      debugPrint('[LA] consumeSync 실패: $e');
      return null;
    }
  }

  /// 앱 실행 중 버튼이 눌렸을 때 네이티브가 보내는 핑 수신.
  void setNativePingListener(void Function()? onPing) {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    _syncChannel.setMethodCallHandler((call) async {
      if (call.method == 'syncRequested') onPing?.call();
    });
  }

  Future<bool> _enabled() async {
    if (!Platform.isIOS || !_initialized) return false;
    return _plugin.areActivitiesEnabled();
  }

  /// 실행 중 상태로 시작(없으면 생성) 또는 갱신.
  /// totalLabel/pauseLabel/resumeLabel/cancelLabel은 Android 알림 표시용(iOS 경로에서는 무시).
  Future<void> startOrUpdateRunning({
    required DateTime endDate,
    required int totalSeconds,
    required String label,
    required String notifTitle,
    required String notifBody,
    String totalLabel = '',
    String pauseLabel = '',
    String resumeLabel = '',
    String cancelLabel = '',
  }) async {
    if (Platform.isAndroid) {
      try {
        await _syncChannel.invokeMethod(
          'start',
          buildAndroidStartPayload(
            endDate: endDate,
            label: label,
            notifTitle: notifTitle,
            notifBody: notifBody,
            totalLabel: totalLabel,
            pauseLabel: pauseLabel,
            resumeLabel: resumeLabel,
            cancelLabel: cancelLabel,
          ),
        );
      } catch (e) {
        debugPrint('[LA] Android 알림 시작 실패: $e');
      }
      return;
    }
    if (!await _enabled()) return;
    final data = buildRunningPayload(
      endDate: endDate,
      totalSeconds: totalSeconds,
      label: label,
      notifTitle: notifTitle,
      notifBody: notifBody,
    );
    try {
      if (_activityId == null) {
        _activityId = await _plugin.createActivity(
          DateTime.now().millisecondsSinceEpoch.toString(),
          data,
        );
      } else {
        await _plugin.updateActivity(_activityId!, data);
      }
    } catch (e) {
      debugPrint('[LA] 활동 생성/갱신 실패: $e');
    }
  }

  /// 일시정지 상태로 갱신.
  Future<void> updatePaused({
    required int remainingSeconds,
    required int totalSeconds,
    required String label,
  }) async {
    if (Platform.isAndroid) {
      try {
        await _syncChannel.invokeMethod(
          'updatePaused',
          buildAndroidPausedPayload(
              remainingSeconds: remainingSeconds, label: label),
        );
      } catch (e) {
        debugPrint('[LA] Android 알림 일시정지 실패: $e');
      }
      return;
    }
    if (!await _enabled() || _activityId == null) return;
    await _plugin.updateActivity(
      _activityId!,
      buildPausedPayload(
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          label: label),
    );
  }

  /// 활동 종료 및 제거.
  Future<void> end() async {
    if (Platform.isAndroid) {
      try {
        await _syncChannel.invokeMethod('end');
      } catch (e) {
        debugPrint('[LA] Android 알림 종료 실패: $e');
      }
      return;
    }
    if (!Platform.isIOS || _activityId == null) return;
    final id = _activityId!;
    _activityId = null;
    await _plugin.endActivity(id);
  }
}
