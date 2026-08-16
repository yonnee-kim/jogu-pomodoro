package com.joguman.pomodoro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// 네이티브 알람이 종료 시각에 발화 — 진행형 알림을 정리하고,
/// 잠금화면 재개 경로(endNotifOwner=native)라면 종료 알림도 게시한다.
/// sync 키는 지우지 않는다: 미소비 resume 스냅샷은 Dart가 finishedAway로 해석해야 한다.
class TimerFinishReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = TimerPrefs.get(context)
        if ((prefs.getString(TimerPrefs.KEY_STATE, "") ?: "") != "running") return
        TimerNotificationManager.cancelOngoing(context)
        if (prefs.getString(TimerPrefs.KEY_END_NOTIF_OWNER, "") == "native") {
            TimerNotificationManager.showFinished(context)
        }
        prefs.edit().putString(TimerPrefs.KEY_STATE, "").apply()
    }
}
