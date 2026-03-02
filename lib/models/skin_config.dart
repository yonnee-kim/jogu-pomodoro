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
  final Color centerShadowColor;
  final double centerShadowBlur;
  final double centerShadowSpread;
  final double? centerAnimationScale;
  final Clip centerClipBehavior;
  final Widget Function() motionWidgetBuilder;
  final Widget Function(bool isStarted)? timerOverlayBuilder;
  final List<String> precacheImagePaths;
  final List<String> prefetchGifPaths;

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
    required this.centerShadowColor,
    this.centerShadowBlur = 12,
    this.centerShadowSpread = -3,
    this.centerAnimationScale,
    this.centerClipBehavior = Clip.none,
    required this.motionWidgetBuilder,
    this.timerOverlayBuilder,
    this.precacheImagePaths = const [],
    this.prefetchGifPaths = const [],
  });
}
