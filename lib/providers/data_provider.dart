import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:joguman_pomodoro/providers/angle_provider.dart';
import 'package:provider/provider.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

import '../services/live_activity_service.dart';
import '../utility.dart';

class DataProvider with ChangeNotifier {
  int startSec = 0;
  int? leaveMillisec;
  int currSec = 0;
  int currMillisec = 0;
  DateTime? startDate;
  DateTime? leaveDate;
  DateTime? alarmDate;
  bool isStarted = false;
  Timer? myTimer;
  bool isAlarm = false;
  AppLifecycleState lifecycleState = AppLifecycleState.resumed;

  setLifecycleState(AppLifecycleState state) {
    lifecycleState = state;
  }

  setIsAlarm(bool value) {
    isAlarm = value;
    notifyListeners();
  }

  setIsStarted(bool value) {
    isStarted = value;
    notifyListeners();
  }

  cancleTimer() async {
    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    plugin.cancel(0);
    alarmDate = null;
    // await Alarm.stop(1);
    isStarted = false;
    if (myTimer != null) {
      myTimer!.cancel();
    }
  }

  /// 일시정지: 타이머 정지(남은 시간 유지) + Live Activity를 일시정지 상태로 갱신.
  Future<void> pauseTimer() async {
    cancleTimer();
    notifyListeners();
    await LiveActivityService.instance.updatePaused(
      remainingSeconds: (currMillisec / 1000).ceil(),
      totalSeconds: startSec,
      label: 'live_activity_title'.tr(),
    );
  }

  /// 취소: 타이머 종료 + 남은 시간을 시작값(startSec)으로 복원 + Live Activity 제거.
  /// 다이얼 각도 복원은 context를 가진 호출 측에서 처리한다.
  Future<void> cancelAndReset() async {
    cancleTimer();
    currSec = startSec;
    currMillisec = startSec * 1000;
    notifyListeners();
    await LiveActivityService.instance.end();
  }

  Future<void> setMyTimer(BuildContext context) async {
    double angle = context.read<AngleProvider>().angle;
    if (myTimer != null) cancleTimer();
    isStarted = true;
    if (currMillisec > 0) {
      DateTime alarmDate = DateTime.now().add(Duration(milliseconds: currMillisec));
      myTimer = Timer.periodic(
        const Duration(milliseconds: 100), // 0.1초 간격
        (timer) async {
          int newMillisec = currMillisec - 100;
          if ((newMillisec / 1000).ceil() < (currMillisec / 1000).ceil()) {
            currSec--;
            angle -= pi / (1800);
            context.read<AngleProvider>().setAngle(angle);
            notifyListeners();
          }
          currMillisec = newMillisec;
          if (currMillisec == 1000) {
            if (lifecycleState == AppLifecycleState.resumed) {
              DateTime now = DateTime.now();
              await checkSoundMode();
              if (ringerStatus == RingerModeStatus.vibrate) {
                final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
                plugin.cancel(0);
                setScheduleNotification(
                    dateTime: now.add(const Duration(milliseconds: 1000)),
                    title: 'app_name'.tr(),
                    body: 'end_message'.tr(),
                    type: 'alarm',
                    playSound: false);
                waitMS(1000).then((value) => setVibration());
              }
            }
          }
          if (currMillisec <= 0) {
            isStarted = false;
            LiveActivityService.instance.end();
            timer.cancel();
          }
        },
      );
      bool isGranted = await checkIsGrantedForNotification();
      if (isGranted) setScheduleNotification(dateTime: alarmDate, title: 'app_name'.tr(), body: 'end_message'.tr(), type: 'alarm');
      LiveActivityService.instance.startOrUpdateRunning(
        endDate: alarmDate,
        totalSeconds: startSec,
        label: 'live_activity_title'.tr(),
        doneLabel: 'la_done'.tr(),
        notifTitle: 'app_name'.tr(),
        notifBody: 'end_message'.tr(),
        totalLabel:
            'la_minutes'.tr(args: [(startSec / 60).round().toString()]),
        pauseLabel: 'la_pause'.tr(),
        resumeLabel: 'la_resume'.tr(),
        cancelLabel: 'la_cancel'.tr(),
      );
    } else {
      currSec = 0;
      if (myTimer != null) cancleTimer();
    }
    notifyListeners();
  }

  setNotification(int millisec) async {
    alarmDate = DateTime.now().add(Duration(milliseconds: millisec));
    await waitMS(millisec);
    if (alarmDate != null && DateTime.now().difference(alarmDate!).inMilliseconds.abs() < 10) {
      bool isVibrate = await checkSoundMode() == 'vibrate';
      print('isVibrate = $isVibrate');
      setShowNotification(title: 'app_name'.tr(), body: 'end_message'.tr(), playSound: !isVibrate);
    }
  }

  void setCurrSec(int seconds, {int? milliseconds}) {
    currSec = seconds;
    currMillisec = milliseconds ?? seconds * 1000;
    notifyListeners();
  }

  void setStartSec(int seconds) {
    startSec = seconds;
    startDate = DateTime.now();
  }

  void setLeaveDateTime(int? milliseconds) {
    leaveMillisec = milliseconds;
    if (milliseconds != null) leaveDate = DateTime.now();
  }
}
