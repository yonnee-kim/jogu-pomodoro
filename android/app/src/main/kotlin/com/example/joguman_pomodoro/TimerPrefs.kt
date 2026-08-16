package com.joguman.pomodoro

import android.content.Context
import android.content.SharedPreferences

/// 진행형 알림의 단일 진실 저장소. 앱 프로세스가 죽어도 Receiver가 이 값으로 동작한다.
object TimerPrefs {
    private const val FILE = "joguman_timer_notification"

    const val KEY_STATE = "state" // "running" | "paused" | ""(비활성)
    const val KEY_END_DATE_MS = "endDateMs"
    const val KEY_REMAINING_MS = "remainingMs"
    const val KEY_TOTAL_LABEL = "totalLabel"
    const val KEY_NOTIF_TITLE = "notifTitle"
    const val KEY_NOTIF_BODY = "notifBody"
    const val KEY_PAUSE_LABEL = "pauseLabel"
    const val KEY_RESUME_LABEL = "resumeLabel"
    const val KEY_CANCEL_LABEL = "cancelLabel"

    // 종료 알림 게시 주체: "plugin"(Dart 예약분이 울림) | "native"(TimerFinishReceiver가 게시)
    const val KEY_END_NOTIF_OWNER = "endNotifOwner"

    // Dart consumeSync가 소비하는 1회성 스냅샷 (iOS App Group 키와 동일 규약)
    const val KEY_SYNC_ACTION = "la_sync_action"
    const val KEY_SYNC_END_DATE_MS = "la_sync_end_date_ms"
    const val KEY_SYNC_REMAINING_MS = "la_sync_remaining_ms"

    fun get(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
}
