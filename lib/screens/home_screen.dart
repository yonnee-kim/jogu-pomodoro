import 'dart:async';
import 'dart:math' as math;

import 'package:alarm/alarm.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:joguman_pomodoro/skins/skin_registry.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/providers/theme_provider.dart';
import 'package:joguman_pomodoro/widgets/pomodoro_cast.dart';
import 'package:joguman_pomodoro/widgets/timer_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utility.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ── 디버그: 화면 비율 조절 ──
  static const bool _debugAspectRatio = false; // false로 바꾸면 슬라이더 숨김
  double _aspectRatio = 1 / 1.95;

  NeverScrollableScrollPhysics? pageScrollPhysics = const NeverScrollableScrollPhysics();
  bool isGranted = false;
  bool isLongPressed = false;
  bool isLoaded = false;
  bool isComplete = false;
  int themeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    initFunc();
  }

  initFunc() async {
    isGranted = await Permission.notification.isGranted;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        final skin = context.read<ThemeProvider>().currentSkin;
        try {
          await Future.wait([
            checkSoundMode(),
            precacheImages(context, skin),
            prefetchGifImages(skin),
          ]);
        } catch (e) {
          print('initialization error: $e');
        } finally {
          setState(() {
            isLoaded = true;
          });
        }
      },
    );
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive) {
      int? leaveMillisec = context.read<DataProvider>().leaveMillisec;
      if (leaveMillisec != null) return;
      int currMillisec = context.read<DataProvider>().currMillisec;
      context.read<DataProvider>().setLeaveDateTime(currMillisec);
    }
    if (state == AppLifecycleState.resumed) {
      final skin = context.read<ThemeProvider>().currentSkin;
      setTimerByLifecycle(context, state, skin);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await precacheImages(context, skin);
      });
      if (isGranted != await Permission.notification.isGranted) {
        isGranted = await Permission.notification.isGranted;
        setState(() {});
      }
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await WakelockPlus.disable();
    super.dispose();
  }

  setAlarmCallBack() {
    Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        String bodyText = '🦕 : 끝! 잠깐 쉬어가요.';
        setShowNotification(body: bodyText);
        // showDialog(
        //   context: context,
        //   useSafeArea: false,
        //   builder: (context) => Scaffold(
        //     backgroundColor: Colors.black.withValues(alpha: 0.2),
        //     body: Center(
        //       child: GestureDetector(
        //         onTap: () async {
        //           HapticFeedback.lightImpact();
        //           Navigator.of(context, rootNavigator: true).pop();
        //           await Alarm.stopAll();
        //         },
        //         child: Container(
        //           alignment: Alignment.center,
        //           height: 60,
        //           width: 60.w,
        //           decoration: BoxDecoration(
        //             color: const Color.fromRGBO(255, 211, 0, 1),
        //             borderRadius: BorderRadius.circular(100),
        //           ),
        //           child: const Text('알림 종료', style: TextStyle(fontFamily: 'Pretendard-Bold', fontSize: 20, color: Colors.white)),
        //         ),
        //       ),
        //     ),
        //   ),
        // );
      }
    });
  }

  Widget _buildContent(BuildContext context, double clockSize) {
    final skin = context.watch<ThemeProvider>().currentSkin;
    themeIndex = context.watch<ThemeProvider>().themeIndex;

    List<Widget> pomodoroList = skinConfigs.map((config) {
      Widget motionWidget = config.motionWidgetBuilder();
      if (config.centerAnimationScale != null) {
        motionWidget = Transform.scale(scale: config.centerAnimationScale!, child: motionWidget);
      }

      return PomodoroCast(
        dialImage: config.dialImageAsset ?? 'assets/img/chrono.png',
        dialImageOffset: config.dialImageOffset,
        dialImageScale: config.dialImageScale,
        clockSize: clockSize,
        clockHandHeight: clockSize * (7.8 / 10) / 2 - 5,
        clockHandWidth: 5,
        clockHandColor: const Color.fromARGB(255, 222, 37, 49),
        leftTimeColor: config.leftTimeColor,
        dialCircleColor: config.dialCircleColor,
        dialShadowColor: config.dialShadowColor,
        clockHandFootYOffset: config.clockHandFootOffset * clockSize,
        clockHandFootRotatesWithDial: config.clockHandFootRotatesWithDial,
        clockHandFoot: Image.asset(config.clockHandFootAsset, width: config.clockHandFootWidth * clockSize),
        centerAnimation: Container(
          width: (clockSize) * 0.75 - 40,
          height: (clockSize) * 0.75 - 40,
          clipBehavior: config.centerClipBehavior,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.centerBackgroundColor,
            boxShadow: [BoxShadow(color: config.centerShadowColor, blurRadius: config.centerShadowBlur, spreadRadius: config.centerShadowSpread)],
          ),
          child: motionWidget,
        ),
        timerPainterBuilder: config.timerPainterBuilder,
        dialOverlayBuilder: config.dialOverlayBuilder,
        dialBackgroundBuilder: config.dialBackgroundBuilder,
      );
    }).toList();

    return Stack(
      children: [
        if (skin.backgroundBuilder != null) Positioned.fill(child: skin.backgroundBuilder!()),
        SafeArea(
          top: true,
          child: Center(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Column(
                  children: [
                    const Spacer(flex: 4),
                    Transform.translate(
                      offset: Offset(0, skin.timerOffsetY),
                      child: const TimerWidget(),
                    ),
                    const Spacer(flex: 1),
                    IndexedStack(
                      index: themeIndex,
                      alignment: Alignment.center,
                      children: pomodoroList,
                    ),
                    const Spacer(flex: 7),
                    const BottomButtonWidet(),
                    const Spacer(flex: 7),
                  ],
                ),
                if (!isGranted)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(200),
                          ),
                          onPressed: () async {
                            await getPermissionWithNotification();
                          },
                          icon: const Icon(Icons.notifications, color: Color.fromARGB(255, 149, 149, 149), size: 30),
                        )
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<ThemeProvider>().currentSkin;

    if (!_debugAspectRatio) {
      // 기존 동작: responsive_sizer 기반
      double maxHeight = 100.h;
      double maxWidth = 100.w;
      late double clockSize;
      if (maxWidth < maxHeight) {
        clockSize = maxWidth * 0.9;
      } else {
        clockSize = maxHeight * 0.9;
      }

      return Scaffold(
        backgroundColor: skin.backgroundColor,
        body:
            !isLoaded ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 189, 189, 189))) : _buildContent(context, clockSize),
      );
    }

    // 디버그 모드: AspectRatio + LayoutBuilder로 화면비율 테스트
    return Scaffold(
      backgroundColor: skin.backgroundColor,
      body: !isLoaded
          ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 189, 189, 189)))
          : Stack(
              children: [
                SafeArea(
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 1.5),
                      ),
                      child: AspectRatio(
                        aspectRatio: _aspectRatio,
                        child: LayoutBuilder(builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;
                          final clockSize = math.min(w, h) * 0.9;

                          return _buildContent(context, clockSize);
                        }),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 4,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '1:${(1 / _aspectRatio).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: _aspectRatio,
                            min: 0.35,
                            max: 0.75,
                            onChanged: (v) => setState(() => _aspectRatio = v),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _aspectRatio = 1 / 1.95),
                          child: const Text(
                            '초기화',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class BottomButtonWidet extends StatefulWidget {
  const BottomButtonWidet({super.key});

  @override
  State<BottomButtonWidet> createState() => _BottomButtonWidetState();
}

class _BottomButtonWidetState extends State<BottomButtonWidet> {
  DateTime limitDate = DateTime(2025, 5, 24);
  final player = AudioPlayer();
  bool isTapped = false;

  @override
  Future<void> dispose() async {
    await player.dispose();
    super.dispose();
  }

  Future<void> setSource() async {
    if (DateTime.now().isBefore(limitDate)) {
      await player.setAudioSource(AudioSource.asset(
        'assets/audio/bedroom_guitar.mp3',
        tag: const MediaItem(
          // Specify a unique ID for each media item:
          id: '1',
          // Metadata to display in the notification:
          album: "조구만 뽀모도로",
          title: "조구만 뽀모도로",
          // artUri: Uri.parse('https://example.com/albumart.jpg'),
        ),
      ));
      await player.setLoopMode(LoopMode.one);
    }
  }

  @override
  Widget build(BuildContext context) {
    Timer? myTimer = context.watch<DataProvider>().myTimer;
    final skin = context.watch<ThemeProvider>().currentSkin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 스타트 스탑
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (myTimer != null && myTimer.isActive) {
                context.read<DataProvider>().cancleTimer();
                context.read<DataProvider>().setIsStarted(false);
              } else {
                context.read<DataProvider>().setMyTimer(context);
                if (context.read<DataProvider>().startSec > 0) {
                  context.read<DataProvider>().setIsStarted(true);
                }
              }
            },
            child: Image.asset(
              myTimer != null && myTimer.isActive ? (skin.stopButtonAsset ?? 'assets/img/stop.png') : (skin.playButtonAsset ?? 'assets/img/play.png'),
              width: 60,
            ),
          ),
          // 테스트 버튼
          if (false)
            GestureDetector(
              onTap: () async {
                String bodyText = 'end_message'.tr();
                DateTime alarmDate = DateTime.now().add(const Duration(seconds: 3));
                // waitMS(1 * 1000).then(
                //   (value) async {
                //     setVibration();
                //   },
                // );
                await setScheduleNotification(dateTime: alarmDate, title: 'app_name'.tr(), body: bodyText, type: 'alarm');
                // setShowNotification(title: 'app_name'.tr(), body: 'end_message'.tr(), playSound: true);
              },
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: const Color.fromARGB(255, 213, 213, 213),
                ),
                child: Center(
                  child: Text(
                    isTapped ? '❌' : '🎵',
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
              ),
            ),

          // 테마 변경
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await context.read<ThemeProvider>().addThemeIndex();
            },
            child: Image.asset(skin.changeButtonAsset ?? 'assets/img/change.png', width: 60),
          ),
        ],
      ),
    );
  }
}
