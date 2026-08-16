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

  // AlarmKit(iOS 26+) 경로: 사용 가능 + 권한 허용일 때만 라우팅. 권한이 미결정이면
  // 타이머 첫 시작 시 _ensureAlarmKit()이 시스템 프롬프트로 요청하고, 거부 시
  // 기존 live_activities 경로로 폴백한다.
  bool _alarmkitAvailable = false;
  bool? _alarmkitAuthorized;

  bool get _alarmkitMode => _alarmkitAvailable && _alarmkitAuthorized == true;

  Future<void> init() async {
    if (!Platform.isIOS) return; // Android는 사전 초기화 불필요(상태는 네이티브 prefs가 소유)
    try {
      await _plugin.init(appGroupId: appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('[LA] init 실패: $e');
    }
    try {
      _alarmkitAvailable =
          await _syncChannel.invokeMethod<bool>('alarmkitAvailable') ?? false;
      if (_alarmkitAvailable) {
        final state =
            await _syncChannel.invokeMethod<String>('alarmkitAuthState');
        if (state == 'authorized') _alarmkitAuthorized = true;
        if (state == 'denied') _alarmkitAuthorized = false;
      }
    } catch (e) {
      debugPrint('[LA] AlarmKit 상태 조회 실패: $e');
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

  /// AlarmKit 권한 확인(미결정이면 시스템 프롬프트). 결과를 캐시한다.
  Future<bool> _ensureAlarmKit() async {
    if (!_alarmkitAvailable) return false;
    if (_alarmkitAuthorized != null) return _alarmkitAuthorized!;
    try {
      _alarmkitAuthorized =
          await _syncChannel.invokeMethod<bool>('alarmkitEnsureAuth') ?? false;
    } catch (e) {
      debugPrint('[LA] AlarmKit 권한 요청 실패: $e');
      _alarmkitAuthorized = false;
    }
    return _alarmkitAuthorized!;
  }

  /// 실행 중 상태로 시작(없으면 생성) 또는 갱신.
  /// 반환값 true = 네이티브(AlarmKit)가 0초 종료 알럿을 전담하므로
  /// 호출 측은 로컬 종료 알림을 예약하지 않아야 한다.
  /// totalLabel/cancelLabel은 Android 알림 표시용, stopLabel은 AlarmKit 알럿용.
  Future<bool> startOrUpdateRunning({
    required DateTime endDate,
    required int totalSeconds,
    required String label,
    required String notifTitle,
    required String notifBody,
    String totalLabel = '',
    String pauseLabel = '',
    String resumeLabel = '',
    String cancelLabel = '',
    String stopLabel = '',
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
      return false;
    }
    if (!Platform.isIOS) return false;
    // 앱 내 시작 시점의 미소비 sync 스냅샷은 정의상 stale — 복귀 시 낡은 스냅샷이
    // 새 타이머를 덮어쓰지 않도록 폐기한다 (Android는 네이티브 start 핸들러에서 동일 처리).
    await consumeSync();
    if (await _ensureAlarmKit()) {
      try {
        final ok = await _syncChannel.invokeMethod<bool>('alarmkitStart', {
          'endDateMs': endDate.millisecondsSinceEpoch,
          'label': label,
          'alertTitle': notifBody,
          'stopLabel': stopLabel,
          'pauseLabel': pauseLabel,
          'resumeLabel': resumeLabel,
        });
        if (ok == true) return true;
      } catch (e) {
        debugPrint('[LA] AlarmKit 시작 실패: $e');
      }
      // 실패 시 기존 경로로 폴백
    }
    if (!await _enabled()) return false;
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
    return false;
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
    if (!Platform.isIOS) return;
    if (_alarmkitMode) {
      try {
        await _syncChannel.invokeMethod('alarmkitPause');
      } catch (e) {
        debugPrint('[LA] AlarmKit 일시정지 실패: $e');
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
  /// natural이 true(0초 자연종료)면 AlarmKit 경로에서는 알람을 건드리지 않는다 —
  /// 만료 시각에 시스템 알럿이 울려야 하고, 중지 시 위젯 정리도 시스템이 한다.
  Future<void> end({bool natural = false}) async {
    if (Platform.isAndroid) {
      try {
        await _syncChannel.invokeMethod('end');
      } catch (e) {
        debugPrint('[LA] Android 알림 종료 실패: $e');
      }
      return;
    }
    if (!Platform.isIOS) return;
    // 앱 내 종료 시점의 미소비 스냅샷도 stale — start와 동일하게 폐기.
    await consumeSync();
    if (_alarmkitMode) {
      if (natural) return;
      try {
        await _syncChannel.invokeMethod('alarmkitCancel');
      } catch (e) {
        debugPrint('[LA] AlarmKit 취소 실패: $e');
      }
      return;
    }
    if (_activityId == null) return;
    final id = _activityId!;
    _activityId = null;
    await _plugin.endActivity(id);
  }
}
