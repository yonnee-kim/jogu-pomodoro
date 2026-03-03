import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/skins/school/school_background.dart';
import 'package:joguman_pomodoro/skins/school/school_lane_painter.dart';
import 'package:joguman_pomodoro/skins/school/school_motion_widget.dart';

final schoolSkinConfig = SkinConfig(
  id: 'school',
  backgroundColor: const Color(0xFF87CEEB),
  dialCircleColor: Colors.transparent,
  dialShadowColor: Colors.transparent,
  timerOffsetY: 0,
  leftTimeColor: const Color(0xFFFFD300),
  numberTintColor: null,
  clockHandFootOffset: -0.025,
  clockHandFootAsset: 'assets/img/school/head.png',
  clockHandFootWidth: 0.3,
  clockHandFootRotatesWithDial: true,
  centerShadowColor: Colors.transparent,
  centerBackgroundColor: Colors.transparent,
  centerShadowBlur: 0,
  centerShadowSpread: 0,
  centerAnimationScale: null,
  centerClipBehavior: Clip.none,
  motionWidgetBuilder: () => const SchoolMotionWidget(),
  timerOverlayBuilder: null,
  backgroundBuilder: () => const SchoolBackground(),
  dialImageAsset: 'assets/img/school/chrono.png',
  dialImageOffset: const Offset(-0.005, 0),
  dialImageScale: 1.01,
  playButtonAsset: 'assets/img/school/play.png',
  stopButtonAsset: 'assets/img/school/stop.png',
  changeButtonAsset: 'assets/img/school/change.png',
  timerPainterBuilder: (double angle, Color color) => EmptyPainter(),
  dialBackgroundBuilder: (double dialSize, double angle) => SchoolDialBackground(
    dialSize: dialSize,
    laneSize: dialSize * 0.9,
    angle: angle,
    laneColor: const Color(0xFFFFD300),
  ),
  dialOverlayBuilder: (double clockSize) => Transform.translate(
    offset: Offset(clockSize * 0.003, -(clockSize * 0.475)),
    child: Image.asset(
      'assets/img/school/school.png',
      width: clockSize * 0.245,
    ),
  ),
  precacheImagePaths: [
    'assets/img/school/head.png',
    'assets/img/school/chrono.png',
    'assets/img/school/watch_face.png',
    'assets/img/school/lane.png',
    'assets/img/school/school.png',
    'assets/img/school/green_background.png',
    'assets/img/school/sun_cloud.png',
    'assets/img/school/play.png',
    'assets/img/school/stop.png',
    'assets/img/school/change.png',
  ],
  prefetchGifPaths: [],
);
