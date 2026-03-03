import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/skins/apple/apple_motion_widget.dart';

final appleSkinConfig = SkinConfig(
  id: 'apple',
  backgroundColor: Colors.white,
  dialCircleColor: const Color.fromRGBO(237, 237, 237, 1),
  dialShadowColor: Colors.grey,
  leftTimeColor: const Color.fromRGBO(222, 37, 49, 1),
  numberTintColor: null,
  clockHandFootOffset: 0.026,
  clockHandFootAsset: 'assets/img/apple/apple.png',
  clockHandFootWidth: 0.1,
  centerShadowColor: const Color.fromARGB(255, 137, 137, 137),
  centerShadowBlur: 12,
  centerShadowSpread: -3,
  centerAnimationScale: null,
  centerClipBehavior: Clip.hardEdge,
  motionWidgetBuilder: () => const AppleMotionWidget(),
  timerOverlayBuilder: null,
  precacheImagePaths: [
    'assets/gif/apple/apple_01_blink.gif',
    'assets/gif/apple/apple_01.gif',
    'assets/gif/apple/apple_02_blink.gif',
    'assets/gif/apple/apple_02.gif',
    'assets/gif/apple/apple_03_blink.gif',
    'assets/gif/apple/apple_03.gif',
    'assets/gif/apple/apple_04_blink.gif',
    'assets/gif/apple/apple_04.gif',
  ],
  prefetchGifPaths: [],
);
