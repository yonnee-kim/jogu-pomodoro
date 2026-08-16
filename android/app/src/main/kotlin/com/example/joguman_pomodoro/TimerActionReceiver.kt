package com.joguman.pomodoro

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// 알림 버튼 탭을 순수 네이티브로 완결한다(iOS AppIntent와 동일 역할).
/// 앱 프로세스·Flutter 엔진이 없어도 동작하며, Dart는 resumed 시 sync 스냅샷으로 정합을 맞춘다.
class TimerActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PAUSE = "com.joguman.pomodoro.TIMER_PAUSE"
        const val ACTION_RESUME = "com.joguman.pomodoro.TIMER_RESUME"
        const val ACTION_CANCEL = "com.joguman.pomodoro.TIMER_CANCEL"

        fun pendingBroadcast(context: Context, action: String, requestCode: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, TimerActionReceiver::class.java).setAction(action),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = TimerPrefs.get(context)
        val state = prefs.getString(TimerPrefs.KEY_STATE, "") ?: ""
        val now = System.currentTimeMillis()
        when (intent.action) {
            ACTION_PAUSE -> {
                val endMs = prefs.getLong(TimerPrefs.KEY_END_DATE_MS, 0)
                if (state != "running" || endMs <= now) return // 중복 탭·만료 가드
                val remaining = endMs - now
                prefs.edit()
                    .putString(TimerPrefs.KEY_STATE, "paused")
                    .putLong(TimerPrefs.KEY_REMAINING_MS, remaining)
                    .putLong(TimerPrefs.KEY_END_DATE_MS, 0)
                    .putString(TimerPrefs.KEY_SYNC_ACTION, "pause")
                    .putLong(TimerPrefs.KEY_SYNC_REMAINING_MS, remaining)
                    .apply()
                cancelPluginAlarm(context) // 앱 밖 시점 — 예외적으로 플러그인 알람을 네이티브가 취소
                TimerAlarm.cancel(context)
                TimerNotificationManager.showPaused(context, remaining)
                MainActivity.pingSync()
            }
            ACTION_RESUME -> {
                val remaining = prefs.getLong(TimerPrefs.KEY_REMAINING_MS, 0)
                if (state != "paused" || remaining <= 0) return
                val endMs = now + remaining
                prefs.edit()
                    .putString(TimerPrefs.KEY_STATE, "running")
                    .putLong(TimerPrefs.KEY_END_DATE_MS, endMs)
                    .putLong(TimerPrefs.KEY_REMAINING_MS, 0)
                    .putString(TimerPrefs.KEY_END_NOTIF_OWNER, "native")
                    .putString(TimerPrefs.KEY_SYNC_ACTION, "resume")
                    .putLong(TimerPrefs.KEY_SYNC_END_DATE_MS, endMs)
                    .apply()
                TimerAlarm.schedule(context, endMs)
                TimerNotificationManager.showRunning(context, endMs)
                MainActivity.pingSync()
            }
            ACTION_CANCEL -> {
                if (state.isEmpty()) return
                prefs.edit()
                    .putString(TimerPrefs.KEY_STATE, "")
                    .putString(TimerPrefs.KEY_SYNC_ACTION, "cancel")
                    .apply()
                cancelPluginAlarm(context)
                TimerAlarm.cancel(context)
                TimerNotificationManager.cancelOngoing(context)
                MainActivity.pingSync()
            }
        }
    }

    /// flutter_local_notifications가 예약한 종료 알람(id 0) 취소.
    /// 취소는 component+requestCode 매칭만 필요해 플러그인 내부 페이로드에 의존하지 않는다.
    private fun cancelPluginAlarm(context: Context) {
        val intent = Intent(
            context,
            com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver::class.java,
        )
        val pi = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
        pi.cancel()
    }
}
