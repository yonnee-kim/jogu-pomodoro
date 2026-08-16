import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:alarm/alarm.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/screens/landscape_layout.dart';
import 'package:joguman_pomodoro/skins/skin_registry.dart';
import 'package:joguman_pomodoro/providers/angle_provider.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/providers/theme_provider.dart';
import 'package:joguman_pomodoro/services/live_activity_service.dart';
import 'package:joguman_pomodoro/services/live_activity_payload.dart';
import 'package:joguman_pomodoro/widgets/pomodoro_cast.dart';
import 'package:joguman_pomodoro/widgets/timer_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
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

  // ── 가로모드 전용 크기 배수 (세로에는 영향 없음, 상세값은 조절) ──
  static const double _lsFootScale = 0.97; // head.png(공룡 머리) — 낮추면 축소
  static const double _lsSchoolOverlayScale = 0.85; // school 건물 이미지 — 낮추면 축소
  static const double _lsSchoolOverlayLift =
      0.05; // school 건물 위로 밀기(clockSize 비율) — 키우면 중심에서 멀어짐

  NeverScrollableScrollPhysics? pageScrollPhysics =
      const NeverScrollableScrollPhysics();
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
    LiveActivityService.instance.setNativePingListener(() {
      // 백그라운드 상태에서 소비하면 스냅샷이 사라져 이후 resumed 복원이 불가능해진다.
      // 포그라운드일 때만 즉시 소비하고, 그 외에는 resumed의 _syncFromNative에 맡긴다.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
        return;
      _syncFromNative();
    });
  }

  initFunc() async {
    isGranted = await Permission.notification.isGranted;
    if (Platform.isAndroid && !isGranted) {
      // Android 13+ 진행형 알림은 POST_NOTIFICATIONS 미허용이면 조용히 표시되지 않으므로 앱 시작 시 요청.
      // (iOS는 main.dart 초기화에서 이미 요청하므로 건드리지 않음. scheduleExactAlarm 등은 종 버튼 UX로 유지.)
      isGranted = (await Permission.notification.request()).isGranted;
    }
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
      await _syncFromNative();
      if (!mounted) return;
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
    LiveActivityService.instance.setNativePingListener(null);
    await WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _syncFromNative() async {
    final sync = await LiveActivityService.instance.consumeSync();
    if (sync == null || !mounted) return;
    final result = reconcileFromSync(
      action: parseLiveActivityAction(sync['action'] ?? ''),
      endDateMs: int.tryParse(sync['endDateMs'] ?? '') ?? 0,
      remainingMs: int.tryParse(sync['remainingMs'] ?? '') ?? 0,
      now: DateTime.now(),
    );
    if (result.kind == ReconcileKind.none) return;
    final data = context.read<DataProvider>();
    data.setLeaveDateTime(null); // 이후 setTimerByLifecycle의 중복 복원 차단
    switch (result.kind) {
      case ReconcileKind.pausedAway:
        data.cancleTimer();
        data.setCurrSec((result.newMillisec / 1000).ceil(),
            milliseconds: result.newMillisec);
        context
            .read<AngleProvider>()
            .setAngle(result.newMillisec / 3600000 * 2 * math.pi);
        break;
      case ReconcileKind.runningAway:
        data.setCurrSec((result.newMillisec / 1000).ceil(),
            milliseconds: result.newMillisec);
        context
            .read<AngleProvider>()
            .setAngle(result.newMillisec / 3600000 * 2 * math.pi);
        data.setMyTimer(context);
        break;
      case ReconcileKind.finishedAway:
        data.cancleTimer();
        data.setCurrSec(0, milliseconds: 0);
        context.read<AngleProvider>().setAngle(0);
        LiveActivityService.instance.end();
        break;
      case ReconcileKind.cancelledAway:
        data.cancelAndReset();
        context
            .read<AngleProvider>()
            .setAngle(data.startSec / 3600 * 2 * math.pi);
        break;
      case ReconcileKind.none:
        break;
    }
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

  Widget _buildDial(BuildContext context, double clockSize,
      {double footScale = 1.0,
      double overlayScale = 1.0,
      double overlayLift = 0.0}) {
    themeIndex = context.watch<ThemeProvider>().themeIndex; // 기존 State 필드 재사용

    final pomodoroList = skinConfigs.map((config) {
      Widget motionWidget = config.motionWidgetBuilder();
      if (config.centerAnimationScale != null) {
        motionWidget = Transform.scale(
            scale: config.centerAnimationScale!, child: motionWidget);
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
        clockHandFoot: Image.asset(config.clockHandFootAsset,
            width: config.clockHandFootWidth * clockSize * footScale),
        centerAnimation: Container(
          width: (clockSize) * 0.75 - 40,
          height: (clockSize) * 0.75 - 40,
          clipBehavior: config.centerClipBehavior,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.centerBackgroundColor,
            boxShadow: [
              BoxShadow(
                  color: config.centerShadowColor,
                  blurRadius: config.centerShadowBlur,
                  spreadRadius: config.centerShadowSpread)
            ],
          ),
          child: motionWidget,
        ),
        timerPainterBuilder: config.timerPainterBuilder,
        dialOverlayBuilder: config.dialOverlayBuilder == null
            ? null
            : (cs) => Transform.translate(
                offset: Offset(0, -overlayLift * cs), // 양수=위로(중심에서 멀어짐)
                child: Transform.scale(
                    scale: overlayScale,
                    child: config.dialOverlayBuilder!(cs))),
        dialBackgroundBuilder: config.dialBackgroundBuilder,
      );
    }).toList();

    return IndexedStack(
      index: themeIndex,
      alignment: Alignment.center,
      children: pomodoroList,
    );
  }

  Widget _notificationButton() {
    return Padding(
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
            icon: const Icon(Icons.notifications,
                color: Color.fromARGB(255, 149, 149, 149), size: 30),
          )
        ],
      ),
    );
  }

  /// 배경 이미지(cover) 좌표에 다이얼/타이머/버튼을 앵커링하는 가로 레이아웃.
  /// 모든 스킨이 sharedLandscapeAnchors 하나로 배치되어, 기기 크기와 무관하게
  /// 배경의 부품 위치(검은 박스 등)와 정렬이 유지된다.
  Widget _buildLandscapeContent(BuildContext context) {
    const LandscapeAnchors anchors = sharedLandscapeAnchors;
    final Size screen = MediaQuery.of(context).size;
    final CoverGeometry bg = computeCoverGeometry(
      screenWidth: screen.width,
      screenHeight: screen.height,
      imageAspect: anchors.imageAspect,
    );
    final double dialSize = anchors.dialHeightFactor * bg.height;
    final double numberHeight = anchors.numberHeightFactor * bg.height;
    final double buttonSize = anchors.buttonSizeFactor * bg.height;
    final double buttonGap = anchors.buttonGapFactor * bg.height;
    final double buttonsWidth = buttonSize * 2 + buttonGap;
    // 타이머 박스: 숫자 4자리+콜론이 들어갈 만큼만 잡고 내부에서 중앙정렬
    final double timerBoxWidth = numberHeight * 6;
    final double timerBoxHeight = numberHeight * 1.5;

    return Stack(
      children: [
        _buildLandscapeBackground(context.watch<ThemeProvider>().currentSkin),
        Positioned(
          left: bg.mapX(anchors.dialCenter.dx) - dialSize / 2,
          top: bg.mapY(anchors.dialCenter.dy) - dialSize / 2,
          width: dialSize,
          height: dialSize,
          child: _buildDial(context, dialSize,
              footScale: _lsFootScale,
              overlayScale: _lsSchoolOverlayScale,
              overlayLift: _lsSchoolOverlayLift),
        ),
        Positioned(
          left: bg.mapX(anchors.timerCenter.dx) - timerBoxWidth / 2,
          top: bg.mapY(anchors.timerCenter.dy) - timerBoxHeight / 2,
          width: timerBoxWidth,
          height: timerBoxHeight,
          child: Center(
            child: TimerWidget(numberHeight: numberHeight, landscape: true),
          ),
        ),
        Positioned(
          left: bg.mapX(anchors.buttonsCenter.dx) - buttonsWidth / 2,
          top: bg.mapY(anchors.buttonsCenter.dy) - buttonSize / 2,
          width: buttonsWidth,
          height: buttonSize,
          child: BottomButtonWidet(
              landscape: true, buttonSize: buttonSize, buttonGap: buttonGap),
        ),
        if (!isGranted)
          SafeArea(
            child: Align(
                alignment: Alignment.topRight, child: _notificationButton()),
          ),
      ],
    );
  }

  Widget _buildLandscapeBackground(SkinConfig skin) {
    if (skin.landscapeBackgroundBuilder != null) {
      return Positioned.fill(
        child: Selector<DataProvider, bool>(
          selector: (context, dataProvider) => dataProvider.isStarted,
          builder: (context, isStarted, child) =>
              skin.landscapeBackgroundBuilder!(isStarted),
        ),
      );
    }
    if (skin.backgroundBuilder != null) {
      return Positioned.fill(child: skin.backgroundBuilder!());
    }
    // 배경이 없어도 Positioned.fill을 유지해야 Stack이 0×0으로 붕괴하지 않는다
    // (non-positioned 자식이 없으면 Stack은 주어진 constraints 크기로 확장됨)
    return const Positioned.fill(child: SizedBox.shrink());
  }

  Widget _buildContent(BuildContext context, double clockSize) {
    final skin = context.watch<ThemeProvider>().currentSkin;

    return Stack(
      children: [
        if (skin.backgroundBuilder != null)
          Positioned.fill(child: skin.backgroundBuilder!()),
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
                    _buildDial(context, clockSize),
                    const Spacer(flex: 7),
                    const BottomButtonWidet(),
                    const Spacer(flex: 7),
                  ],
                ),
                if (!isGranted) _notificationButton(),
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
      // 방향/크기 판별은 MediaQuery를 신뢰 (responsive_sizer의 .w/.h는 회전 후 갱신이 늦음)
      final Size screen = MediaQuery.of(context).size;
      final double maxWidth = screen.width;
      final double maxHeight = screen.height;

      if (maxWidth < maxHeight) {
        // 세로: 기존 동작 유지
        final double clockSize = maxWidth * 0.9;
        return Scaffold(
          backgroundColor: skin.backgroundColor,
          body: !isLoaded
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 189, 189, 189)))
              : _buildContent(context, clockSize),
        );
      }

      // 가로: 배경 이미지 앵커 레이아웃 (다이얼 왼쪽 / 타이머+버튼 오른쪽)
      return Scaffold(
        backgroundColor: skin.backgroundColor,
        body: !isLoaded
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color.fromARGB(255, 189, 189, 189)))
            : _buildLandscapeContent(context),
      );
    }

    // 디버그 모드: AspectRatio + LayoutBuilder로 화면비율 테스트
    return Scaffold(
      backgroundColor: skin.backgroundColor,
      body: !isLoaded
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 189, 189, 189)))
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '1:${(1 / _aspectRatio).toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
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
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11),
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
  const BottomButtonWidet(
      {super.key, this.landscape = false, this.buttonSize, this.buttonGap});

  final bool landscape;

  /// 지정 시 기본 상수(_lsButtonSize/_lsButtonGap) 대신 사용 — 앵커 레이아웃에서
  /// 배경 이미지 크기에 비례해 넘겨준다.
  final double? buttonSize;
  final double? buttonGap;

  @override
  State<BottomButtonWidet> createState() => _BottomButtonWidetState();
}

class _BottomButtonWidetState extends State<BottomButtonWidet> {
  static const double _lsButtonGap = 55; // 가로모드 버튼 사이 간격(px) — 키우면 넓어짐
  static const double _lsButtonSize = 60; // 가로모드 버튼 크기(px) — 키우면 커짐 (세로는 60 고정)
  DateTime limitDate = DateTime(2025, 5, 24);
  final player = AudioPlayer();
  bool isTapped = false;

  @override
  void dispose() {
    unawaited(player.dispose());
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

    final double buttonSize =
        widget.buttonSize ?? (widget.landscape ? _lsButtonSize : 60); // 가로만 조절

    // 스타트 스탑
    final Widget playStopButton = GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (myTimer != null && myTimer.isActive) {
          // 정지 대신 일시정지: 남은 시간 유지 + Live Activity 일시정지 갱신
          context.read<DataProvider>().pauseTimer();
        } else {
          context.read<DataProvider>().setMyTimer(context);
          if (context.read<DataProvider>().startSec > 0) {
            context.read<DataProvider>().setIsStarted(true);
          }
        }
      },
      child: Image.asset(
        myTimer != null && myTimer.isActive
            ? (skin.stopButtonAsset ?? 'assets/img/stop.png')
            : (skin.playButtonAsset ?? 'assets/img/play.png'),
        width: buttonSize,
      ),
    );

    // 테마 변경
    final Widget changeButton = GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await context.read<ThemeProvider>().addThemeIndex();
      },
      child: Image.asset(skin.changeButtonAsset ?? 'assets/img/change.png',
          width: buttonSize),
    );

    if (widget.landscape) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          playStopButton,
          SizedBox(width: widget.buttonGap ?? _lsButtonGap),
          changeButton,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          playStopButton,
          // 테스트 버튼 (기존 비활성 데드코드 — 그대로 보존)
          if (false)
            GestureDetector(
              onTap: () async {
                String bodyText = 'end_message'.tr();
                DateTime alarmDate =
                    DateTime.now().add(const Duration(seconds: 3));
                // waitMS(1 * 1000).then(
                //   (value) async {
                //     setVibration();
                //   },
                // );
                await setScheduleNotification(
                    dateTime: alarmDate,
                    title: 'app_name'.tr(),
                    body: bodyText,
                    type: 'alarm');
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
          changeButton,
        ],
      ),
    );
  }
}
