import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/widgets/motion_widget_apple.dart';
import 'package:joguman_pomodoro/widgets/motion_widget_wash.dart';

final List<SkinConfig> skinConfigs = [
  // 사과
  SkinConfig(
    id: 'apple',
    backgroundColor: Colors.white,
    dialCircleColor: const Color.fromRGBO(237, 237, 237, 1),
    dialShadowColor: Colors.grey,
    leftTimeColor: const Color.fromRGBO(222, 37, 49, 1),
    numberTintColor: null,
    clockHandFootOffset: 9,
    clockHandFootAsset: 'assets/img/apple/apple.png',
    clockHandFootWidth: 36,
    centerShadowColor: const Color.fromARGB(255, 137, 137, 137),
    centerShadowBlur: 12,
    centerShadowSpread: -3,
    centerAnimationScale: null,
    centerClipBehavior: Clip.hardEdge,
    motionWidgetBuilder: () => const AppleMotionWidget(),
    timerOverlayBuilder: null,
    precacheImagePaths: [
      'assets/gif/apple_01_blink.gif',
      'assets/gif/apple_01.gif',
      'assets/gif/apple_02_blink.gif',
      'assets/gif/apple_02.gif',
      'assets/gif/apple_03_blink.gif',
      'assets/gif/apple_03.gif',
      'assets/gif/apple_04_blink.gif',
      'assets/gif/apple_04.gif',
    ],
    prefetchGifPaths: [],
  ),
  // 세탁기
  SkinConfig(
    id: 'wash',
    backgroundColor: const Color.fromRGBO(245, 246, 247, 1),
    dialCircleColor: const Color.fromRGBO(210, 210, 215, 1),
    dialShadowColor: const Color.fromARGB(255, 189, 189, 189),
    leftTimeColor: const Color.fromRGBO(22, 20, 24, 1),
    numberTintColor: const Color.fromRGBO(255, 211, 0, 1),
    clockHandFootOffset: 11,
    clockHandFootAsset: 'assets/img/wash/dot.png',
    clockHandFootWidth: 26,
    centerShadowColor: const Color.fromARGB(255, 0, 0, 0),
    centerShadowBlur: 10,
    centerShadowSpread: -1,
    centerAnimationScale: 1.11,
    centerClipBehavior: Clip.none,
    motionWidgetBuilder: () => const WashMotionWidget(),
    timerOverlayBuilder: (bool isStarted) => Image(
      image: AssetImage(isStarted ? 'assets/img/wash/machine_head_on.png' : 'assets/img/wash/machine_head_off.png'),
    ),
    precacheImagePaths: [
      'assets/img/wash/machine_head_on.png',
      'assets/img/wash/machine_head_off.png',
    ],
    prefetchGifPaths: [
      'assets/gif/wash_activate.gif',
      'assets/gif/wash_blink.gif',
      'assets/gif/wash_start.gif',
      'assets/gif/wash_stop.gif',
    ],
  ),
];

/// 모든 스킨에서 공유하는 에셋 경로
const List<String> sharedImagePaths = [
  'assets/img/play.png',
  'assets/img/stop.png',
  'assets/img/1.png',
  'assets/img/2.png',
  'assets/img/3.png',
  'assets/img/4.png',
  'assets/img/5.png',
  'assets/img/6.png',
  'assets/img/7.png',
  'assets/img/8.png',
  'assets/img/9.png',
  'assets/img/0.png',
  'assets/img/colon.png',
];
