package com.joguman.pomodoro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.text.DateFormat
import java.util.Date

object TimerNotificationManager {
    const val ONGOING_NOTIFICATION_ID = 1001
    const val END_NOTIFICATION_ID = 0 // flutter_local_notifications 예약 알림과 동일 id
    private const val ONGOING_CHANNEL_ID = "timer_ongoing"
    private const val END_CHANNEL_ID = "end_alarm" // 플러그인이 만드는 채널과 동일 id 재사용

    fun showRunning(context: Context, endDateMs: Long) {
        notify(context, buildOngoing(context, running = true, endDateMs = endDateMs, remainingMs = 0))
    }

    fun showPaused(context: Context, remainingMs: Long) {
        notify(context, buildOngoing(context, running = false, endDateMs = 0, remainingMs = remainingMs))
    }

    fun cancelOngoing(context: Context) {
        manager(context).cancel(ONGOING_NOTIFICATION_ID)
    }

    /// 재개 경로(endNotifOwner=native)에서 TimerFinishReceiver가 호출하는 종료 알림.
    fun showFinished(context: Context) {
        val prefs = TimerPrefs.get(context)
        ensureEndChannel(context)
        val notification = NotificationCompat.Builder(context, END_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(prefs.getString(TimerPrefs.KEY_NOTIF_TITLE, "") ?: "")
            .setContentText(prefs.getString(TimerPrefs.KEY_NOTIF_BODY, "") ?: "")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(launchAppIntent(context))
            .build()
        manager(context).notify(END_NOTIFICATION_ID, notification)
    }

    private fun notify(context: Context, notification: Notification) {
        ensureOngoingChannel(context)
        try {
            manager(context).notify(ONGOING_NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS 미허용(Android 13+) — 알림 없이 타이머만 동작
        }
    }

    private fun buildOngoing(
        context: Context,
        running: Boolean,
        endDateMs: Long,
        remainingMs: Long,
    ): Notification {
        return NotificationCompat.Builder(context, ONGOING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(buildViews(context, R.layout.notification_timer_collapsed, running, endDateMs, remainingMs, withButtons = false))
            .setCustomBigContentView(buildViews(context, R.layout.notification_timer_expanded, running, endDateMs, remainingMs, withButtons = true))
            .setContentIntent(launchAppIntent(context))
            .build()
    }

    private fun buildViews(
        context: Context,
        layoutId: Int,
        running: Boolean,
        endDateMs: Long,
        remainingMs: Long,
        withButtons: Boolean,
    ): RemoteViews {
        val prefs = TimerPrefs.get(context)
        val views = RemoteViews(context.packageName, layoutId)
        val totalLabel = prefs.getString(TimerPrefs.KEY_TOTAL_LABEL, "") ?: ""
        if (running) {
            views.setViewVisibility(R.id.timer_chrono, View.VISIBLE)
            views.setViewVisibility(R.id.timer_paused_text, View.GONE)
            views.setChronometerCountDown(R.id.timer_chrono, true)
            views.setChronometer(
                R.id.timer_chrono,
                SystemClock.elapsedRealtime() + (endDateMs - System.currentTimeMillis()),
                null,
                true,
            )
            val endTime = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(endDateMs))
            views.setTextViewText(R.id.timer_subtext, "$totalLabel / $endTime")
        } else {
            views.setViewVisibility(R.id.timer_chrono, View.GONE)
            views.setViewVisibility(R.id.timer_paused_text, View.VISIBLE)
            views.setTextViewText(R.id.timer_paused_text, formatMmSs(remainingMs))
            views.setTextViewText(R.id.timer_subtext, totalLabel)
        }
        if (withButtons) {
            views.setTextViewText(
                R.id.btn_cancel, prefs.getString(TimerPrefs.KEY_CANCEL_LABEL, "") ?: "")
            views.setOnClickPendingIntent(
                R.id.btn_cancel,
                TimerActionReceiver.pendingBroadcast(context, TimerActionReceiver.ACTION_CANCEL, 2),
            )
            if (running) {
                views.setTextViewText(
                    R.id.btn_toggle, prefs.getString(TimerPrefs.KEY_PAUSE_LABEL, "") ?: "")
                views.setOnClickPendingIntent(
                    R.id.btn_toggle,
                    TimerActionReceiver.pendingBroadcast(context, TimerActionReceiver.ACTION_PAUSE, 3),
                )
            } else {
                views.setTextViewText(
                    R.id.btn_toggle, prefs.getString(TimerPrefs.KEY_RESUME_LABEL, "") ?: "")
                views.setOnClickPendingIntent(
                    R.id.btn_toggle,
                    TimerActionReceiver.pendingBroadcast(context, TimerActionReceiver.ACTION_RESUME, 3),
                )
            }
        }
        return views
    }

    private fun formatMmSs(remainingMs: Long): String {
        val totalSec = (remainingMs + 999) / 1000 // 올림 — Dart의 (ms/1000).ceil()과 동일
        return "%02d:%02d".format(totalSec / 60, totalSec % 60)
    }

    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun ensureOngoingChannel(context: Context) {
        // IMPORTANCE_LOW(무음 분류)는 Android 16 잠금화면에서 숨겨진다.
        // DEFAULT + 무음 사운드로 잠금화면 표시를 보장한다(소리·진동은 계속 없음).
        val channel = NotificationChannel(
            ONGOING_CHANNEL_ID, "Timer", NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        manager(context).createNotificationChannel(channel) // 이미 있으면 no-op
    }

    /// 플러그인(end_alarm 채널)이 아직 채널을 안 만들었을 때를 대비해 동일 규약으로 생성.
    private fun ensureEndChannel(context: Context) {
        val channel = NotificationChannel(
            END_CHANNEL_ID, "alarm", NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            setSound(
                Uri.parse("android.resource://${context.packageName}/raw/bip"),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
            )
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        manager(context).createNotificationChannel(channel)
    }

    private fun manager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
