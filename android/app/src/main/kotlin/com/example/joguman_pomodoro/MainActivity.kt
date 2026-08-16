package com.joguman.pomodoro

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private var channel: MethodChannel? = null

        /// Receiver가 상태를 바꿨을 때 포그라운드 Dart에 알리는 핑(iOS NotificationCenter 옵저버 역할).
        /// 액티비티(엔진)가 없으면 no-op — resumed 시 consumeSync가 처리한다.
        fun pingSync() {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("syncRequested", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.joguman.pomodoro/live_activity",
        )
        channel = ch
        ch.setMethodCallHandler { call, result ->
            val prefs = TimerPrefs.get(this)
            when (call.method) {
                "start" -> {
                    val endDateMs = call.argument<Number>("endDateMs")?.toLong()
                    if (endDateMs == null) {
                        result.error("BAD_ARGS", "endDateMs 누락", null)
                        return@setMethodCallHandler
                    }
                    prefs.edit()
                        .putString(TimerPrefs.KEY_STATE, "running")
                        .putLong(TimerPrefs.KEY_END_DATE_MS, endDateMs)
                        .putLong(TimerPrefs.KEY_REMAINING_MS, 0)
                        .putString(TimerPrefs.KEY_TOTAL_LABEL, call.argument("totalLabel") ?: "")
                        .putString(TimerPrefs.KEY_NOTIF_TITLE, call.argument("notifTitle") ?: "")
                        .putString(TimerPrefs.KEY_NOTIF_BODY, call.argument("notifBody") ?: "")
                        .putString(TimerPrefs.KEY_PAUSE_LABEL, call.argument("pauseLabel") ?: "")
                        .putString(TimerPrefs.KEY_RESUME_LABEL, call.argument("resumeLabel") ?: "")
                        .putString(TimerPrefs.KEY_CANCEL_LABEL, call.argument("cancelLabel") ?: "")
                        .putString(TimerPrefs.KEY_END_NOTIF_OWNER, "plugin") // 종료 알림은 Dart 예약분
                        // 앱 내 시작 시점의 미소비 스냅샷은 stale — 새 타이머 하이재킹 방지
                        .remove(TimerPrefs.KEY_SYNC_ACTION)
                        .remove(TimerPrefs.KEY_SYNC_END_DATE_MS)
                        .remove(TimerPrefs.KEY_SYNC_REMAINING_MS)
                        .apply()
                    // 자체 알람은 진행형 알림 정리용으로 항상 예약(플러그인 알람은 Dart 소유 — 불가침)
                    TimerAlarm.cancel(this)
                    TimerAlarm.schedule(this, endDateMs)
                    TimerNotificationManager.showRunning(this, endDateMs)
                    result.success(null)
                }
                "updatePaused" -> {
                    val remainingSeconds = call.argument<Number>("remainingSeconds")?.toLong() ?: 0
                    val remainingMs = remainingSeconds * 1000
                    prefs.edit()
                        .putString(TimerPrefs.KEY_STATE, "paused")
                        .putLong(TimerPrefs.KEY_REMAINING_MS, remainingMs)
                        .putLong(TimerPrefs.KEY_END_DATE_MS, 0)
                        .apply()
                    TimerAlarm.cancel(this)
                    TimerNotificationManager.showPaused(this, remainingMs)
                    result.success(null)
                }
                "end" -> {
                    TimerAlarm.cancel(this)
                    TimerNotificationManager.cancelOngoing(this)
                    prefs.edit()
                        .putString(TimerPrefs.KEY_STATE, "")
                        // 앱 내 종료 시점의 미소비 스냅샷은 stale — 새 타이머 하이재킹 방지
                        .remove(TimerPrefs.KEY_SYNC_ACTION)
                        .remove(TimerPrefs.KEY_SYNC_END_DATE_MS)
                        .remove(TimerPrefs.KEY_SYNC_REMAINING_MS)
                        .apply()
                    result.success(null)
                }
                "consumeSync" -> {
                    val action = prefs.getString(TimerPrefs.KEY_SYNC_ACTION, null)
                    if (action.isNullOrEmpty()) {
                        result.success(null)
                    } else {
                        val snapshot = mapOf(
                            "action" to action,
                            "endDateMs" to prefs.getLong(TimerPrefs.KEY_SYNC_END_DATE_MS, 0).toString(),
                            "remainingMs" to prefs.getLong(TimerPrefs.KEY_SYNC_REMAINING_MS, 0).toString(),
                        )
                        prefs.edit()
                            .remove(TimerPrefs.KEY_SYNC_ACTION)
                            .remove(TimerPrefs.KEY_SYNC_END_DATE_MS)
                            .remove(TimerPrefs.KEY_SYNC_REMAINING_MS)
                            .apply()
                        result.success(snapshot)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
    }
}
