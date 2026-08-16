import 'package:flutter/material.dart';

/// 가로모드에서 위젯을 배경 이미지(BoxFit.cover) 위의 고정 지점에 배치하는 앵커.
/// 좌표(Offset)는 배경 이미지에 대한 비율(0~1), 크기 factor는 배경 이미지
/// 높이에 대한 비율이라 기기 크기가 달라져도 배경과의 정렬이 유지된다.
class LandscapeAnchors {
  final double imageAspect; // 배경 이미지 가로/세로 비 (cover 기하 계산용)
  final Offset dialCenter; // 다이얼 중심
  final double dialHeightFactor; // 다이얼 크기 — 낮추면 축소
  final Offset timerCenter; // 타이머 숫자 중심
  final double numberHeightFactor; // 숫자 높이 — 낮추면 축소
  final Offset buttonsCenter; // 버튼 행 중심
  final double buttonSizeFactor; // 버튼 한 개 크기
  final double buttonGapFactor; // 버튼 사이 간격

  const LandscapeAnchors({
    required this.imageAspect,
    required this.dialCenter,
    required this.dialHeightFactor,
    required this.timerCenter,
    required this.numberHeightFactor,
    required this.buttonsCenter,
    required this.buttonSizeFactor,
    required this.buttonGapFactor,
  });
}

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

  /// 가로모드 전용 전체화면 배경. null이면 [backgroundBuilder]를 그대로 사용한다.
  final Widget Function(bool isStarted)? landscapeBackgroundBuilder;
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
    this.landscapeBackgroundBuilder,
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
