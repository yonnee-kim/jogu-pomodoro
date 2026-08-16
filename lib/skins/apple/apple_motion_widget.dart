import 'dart:async';
import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/skins/apple/apple_motion_logic.dart';
import 'package:provider/provider.dart';

class AppleMotionWidget extends StatefulWidget {
  const AppleMotionWidget({super.key});

  @override
  State<AppleMotionWidget> createState() => _AppleMotionWidgetState();
}

class _AppleMotionWidgetState extends State<AppleMotionWidget> {
  Timer? _introTimer;
  int? _lastSegment; // 직전 빌드에서 목격한 구간 (null = 방금 마운트 → 인트로 생략)
  bool _wasStarted = false;
  bool _showingIntro = false;

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  void _startIntro(int segment) {
    _showingIntro = true;
    final String intro = appleIntroGif(segment);
    AssetImage(intro).evict(); // 인트로를 프레임 0부터 재생
    _introTimer?.cancel();
    _introTimer = Timer(
      Duration(milliseconds: getGifDurationMilliSec(intro)),
      () {
        if (!mounted) return;
        setState(() => _showingIntro = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // DataProvider가 재생 중 초당 notifyListeners()를 호출한다 — 그 알림이 시계 역할
    final data = context.watch<DataProvider>();
    final int segment = appleSegment(
        startSec: data.startSec, currentMilliSec: data.currMillisec);

    if (data.isStarted) {
      final bool freshStart =
          !_wasStarted && data.currMillisec == data.startSec * 1000;
      final bool crossedBoundary =
          _lastSegment != null && segment != _lastSegment;
      if (segment != 1 && (freshStart || crossedBoundary)) {
        _startIntro(segment);
      }
    } else {
      _introTimer?.cancel();
      _showingIntro = false;
    }
    _lastSegment = segment;
    _wasStarted = data.isStarted;

    final String imgUrl;
    if (!data.isStarted) {
      imgUrl = getAppleGifForPause(
          startSec: data.startSec, currentMilliSec: data.currMillisec);
    } else if (_showingIntro) {
      imgUrl = appleIntroGif(segment);
    } else {
      imgUrl = appleBlinkGif(segment);
    }
    return Image.asset(imgUrl, gaplessPlayback: true);
  }
}
