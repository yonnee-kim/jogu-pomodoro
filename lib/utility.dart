// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gif_view/gif_view.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/models/skin_configs.dart';

RingerModeStatus ringerStatus = RingerModeStatus.unknown;

Future<void> precacheImages(BuildContext context, SkinConfig skin) async {
  for (String path in [...sharedImagePaths, ...skin.precacheImagePaths]) {
    await precacheImage(AssetImage(path), context);
  }
}

Future<void> prefetchGifImages(SkinConfig skin) async {
  if (skin.prefetchGifPaths.isEmpty) return;
  await Future.wait(
    skin.prefetchGifPaths.map((path) => GifView.preFetchImage(AssetImage(path))),
  );
}

// 라이프사이클 관련
Future<void> setTimerByLifecycle(BuildContext context, AppLifecycleState state, SkinConfig skin) async {
  Timer? myTimer = context.read<DataProvider>().myTimer;
  DateTime? leaveDate = context.read<DataProvider>().leaveDate;
  int? leaveMillisec = context.read<DataProvider>().leaveMillisec;
  if (leaveDate != null && leaveMillisec != null && myTimer != null && myTimer.isActive) {
    int milliDifference = DateTime.now().difference(leaveDate).inMilliseconds;
    int newSec = ((leaveMillisec - milliDifference) / 1000).ceil();
    int newMillisec = leaveMillisec - milliDifference;
    context.read<DataProvider>().setLeaveDateTime(null);
    if (newSec <= 0) {
      newSec = 0;
      context.read<DataProvider>().setCurrSec(newSec, milliseconds: newMillisec);
    } else {
      context.read<DataProvider>().setCurrSec(newSec, milliseconds: newMillisec);
      context.read<DataProvider>().setMyTimer(context);
    }
  }
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    precacheImages(context, skin);
  });
}

// 알림 관련
Future<void> setSceduledAlarm({
  required DateTime dateTime,
  int id = 1,
  String title = '조구만 뽀모도로',
  String body = '종료',
}) async {
  final alarmSettings = AlarmSettings(
    id: id,
    dateTime: dateTime,
    assetAudioPath: 'assets/audio/bipbip.mp3',
    loopAudio: false,
    vibrate: false,
    warningNotificationOnKill: Platform.isIOS,
    androidFullScreenIntent: false,
    iOSBackgroundAudio: true,
    volumeSettings: const VolumeSettings.fixed(
      volume: 0.5,
    ),
    notificationSettings: NotificationSettings(
      title: title,
      body: body,
      stopButton: 'Stop',
      icon: 'notification_icon',
    ),
  );
  // await Alarm.stop(1);
  await Alarm.set(alarmSettings: alarmSettings);
}

Future<void> setScheduleNotification({
  required DateTime dateTime,
  String title = '조구만 뽀모도로',
  required String body,
  required String? type,
  bool playSound = true,
  String? subType,
  int id = 0,
  bool presentBanner = true,
}) async {
  String iosSound = 'bip.wav';
  AndroidNotificationSound androidSound = const RawResourceAndroidNotificationSound('bip');

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  plugin.cancel(id);

  NotificationDetails details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: playSound,
      presentBanner: presentBanner,
      interruptionLevel: InterruptionLevel.critical,
      sound: iosSound,
    ),
    android: AndroidNotificationDetails(
      "end_alarm", // 채널 id
      type ?? '', // 채널 name
      importance: Importance.max,
      priority: Priority.high,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: androidSound,
      playSound: playSound,
      channelShowBadge: false,
    ),
  );

  tz.TZDateTime schedule = tz.TZDateTime.from(dateTime, tz.local);
  await plugin.zonedSchedule(
    id, // 알림 ID
    title,
    body,
    schedule,
    details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: null,
  );
}

Future<void> setShowNotification({
  int id = 0,
  String type = 'alarm',
  String title = '조구만 뽀모도로',
  String body = '종료',
  bool playSound = true,
  int milliSec = 0,
}) async {
  String iosSound = 'bip.wav';
  AndroidNotificationSound androidSound = const RawResourceAndroidNotificationSound('bip');

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  plugin.cancel(id);

  NotificationDetails details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: playSound,
      presentBanner: true,
      interruptionLevel: InterruptionLevel.critical,
      sound: iosSound,
    ),
    android: AndroidNotificationDetails(
      "alarm", // 채널 id
      type, // 채널 name
      importance: Importance.max,
      priority: Priority.high,
      sound: androidSound,
      playSound: playSound,
    ),
  );

  await plugin.show(
    id, // 알림 ID
    title,
    body,
    details,
  );
}

Future<void> checkVibration({String type = 'alarm'}) async {
  if (await Vibration.hasVibrator()) {
    print('vibration 가능');
  }
  await waitMS(1000);
  if (await Vibration.hasAmplitudeControl()) {
    print('vibration 진폭 조절 가능');
    print('amplitude: 1');
    await Vibration.vibrate(amplitude: 1);
    await waitMS(1500);
    print('amplitude: 128');
    await Vibration.vibrate(amplitude: 128);
    await waitMS(1500);
    print('amplitude: 255');
    await Vibration.vibrate(amplitude: 255);
    await waitMS(1500);
  }
  await waitMS(1000);
  if (await Vibration.hasCustomVibrationsSupport()) {
    print('vibration 커스텀 가능');
    Vibration.vibrate(pattern: [500, 1000, 500, 2000], intensities: [1, 255]);
  }
}

Future<void> setVibration({String type = 'alarm'}) async {
  try {
    print('시작');
    // await Vibration.vibrate(duration: 400, amplitude: 255);
    if (ringerStatus == RingerModeStatus.vibrate) {
      await Vibration.vibrate(duration: 400, amplitude: 255);
      await waitMS(600);
      await Vibration.vibrate(duration: 400, amplitude: 255);
      await waitMS(600);
      await Vibration.vibrate(duration: 400, amplitude: 255);
      // await waitMS(800);
      // await Vibration.vibrate(duration: 400, amplitude: 255);
    }
  } catch (e) {}
}

Future<String> checkSoundMode() async {
  String result = '';
  ringerStatus = await SoundMode.ringerModeStatus;
  print(ringerStatus);
  if (ringerStatus == RingerModeStatus.vibrate) {
    result = 'vibrate';
  }
  return result;
}

// 권한요청 관련
Future<void> getPermissionWithNotification() async {
  if (!await Permission.notification.isGranted) {
    await Permission.notification.request();
  }
  if (await Permission.notification.isPermanentlyDenied) {
    openAppSettings();
  }
  if (Platform.isAndroid) {
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }
}

Future<bool> checkIsGrantedForNotification() async {
  bool result = false;
  if (await Permission.notification.isGranted) {
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.status.isGranted) {
      result = false;
    } else {
      result = true;
    }
  }
  return result;
}

// 기타
Future<void> waitMS(int milliSeconds) async {
  await Future.delayed(Duration(milliseconds: milliSeconds));
}
