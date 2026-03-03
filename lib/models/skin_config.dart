import 'package:flutter/material.dart';

class SkinConfig {
  final String id;
  final Color backgroundColor;
  final Color dialCircleColor;
  final Color dialShadowColor;
  final Color leftTimeColor;
  final Color? numberTintColor;
  final double clockHandFootOffset;
  final String clockHandFootAsset;
  final double clockHandFootWidth;
  final bool clockHandFootRotatesWithDial;
  final Color centerShadowColor;
  final double centerShadowBlur;
  final double centerShadowSpread;
  final Color centerBackgroundColor;
  final double? centerAnimationScale;
  final Clip centerClipBehavior;
  final Widget Function() motionWidgetBuilder;
  final Widget Function(bool isStarted)? timerOverlayBuilder;
  final List<String> precacheImagePaths;
  final List<String> prefetchGifPaths;

  // school 스킨 등에서 사용하는 확장 필드
  final double timerOffsetY;
  final Widget Function()? backgroundBuilder;
  final String? dialImageAsset;
  final Offset dialImageOffset;
  final double dialImageScale;
  final String? playButtonAsset;
  final String? stopButtonAsset;
  final String? changeButtonAsset;
  final CustomPainter Function(double angle, Color color)? timerPainterBuilder;
  final Widget Function(double clockSize)? dialOverlayBuilder;
  final Widget Function(double dialSize, double angle)? dialBackgroundBuilder;

  const SkinConfig({
    required this.id,
    required this.backgroundColor,
    required this.dialCircleColor,
    required this.dialShadowColor,
    required this.leftTimeColor,
    this.numberTintColor,
    required this.clockHandFootOffset,
    required this.clockHandFootAsset,
    required this.clockHandFootWidth,
    this.clockHandFootRotatesWithDial = false,
    required this.centerShadowColor,
    this.centerShadowBlur = 12,
    this.centerShadowSpread = -3,
    this.centerBackgroundColor = Colors.white,
    this.centerAnimationScale,
    this.centerClipBehavior = Clip.none,
    required this.motionWidgetBuilder,
    this.timerOverlayBuilder,
    this.precacheImagePaths = const [],
    this.prefetchGifPaths = const [],
    this.timerOffsetY = 0,
    this.backgroundBuilder,
    this.dialImageAsset,
    this.dialImageOffset = Offset.zero,
    this.dialImageScale = 1.02,
    this.playButtonAsset,
    this.stopButtonAsset,
    this.changeButtonAsset,
    this.timerPainterBuilder,
    this.dialOverlayBuilder,
    this.dialBackgroundBuilder,
  });
}
