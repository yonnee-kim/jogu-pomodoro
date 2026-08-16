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
  int? _lastMillisec; // 직전 빌드에서 목격한 currMillisec — 백그라운드 복귀 등 큰 점프 판별용
  bool _wasStarted = false;
  bool _showingIntro = false;
  bool _settingDial = false; // 정지 상태에서 다이얼 재설정 중 → 대기 포즈(01_blink) 고정

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
      _settingDial = false;
      final bool freshStart =
          !_wasStarted && data.currMillisec == data.startSec * 1000;
      final bool crossedBoundary = _lastSegment != null &&
          segment != _lastSegment &&
          isWitnessedTick(
              lastMilliSec: _lastMillisec, currentMilliSec: data.currMillisec);
      if (segment != 1 && (freshStart || crossedBoundary)) {
        _startIntro(segment);
      }
    } else {
      _introTimer?.cancel();
      _showingIntro = false;
      // 다이얼 조작(분 단위 점프) 또는 남은 시간 == 시작 시간(재설정 완료/미시작)이면
      // 일시정지가 아니라 시간 설정 중 — 드래그 중 낡은 startSec으로 구간을 계산해
      // 02~04가 순차로 보이는 문제를 막는다.
      if (isDialAdjusted(
              lastMilliSec: _lastMillisec,
              currentMilliSec: data.currMillisec) ||
          data.currMillisec >= data.startSec * 1000) {
        _settingDial = true;
      }
    }
    _lastSegment = segment;
    _lastMillisec = data.currMillisec;
    _wasStarted = data.isStarted;

    final String imgUrl;
    if (!data.isStarted) {
      imgUrl = _settingDial
          ? appleBlinkGif(1)
          : getAppleGifForPause(
              startSec: data.startSec, currentMilliSec: data.currMillisec);
    } else if (_showingIntro) {
      imgUrl = appleIntroGif(segment);
    } else {
      imgUrl = appleBlinkGif(segment);
    }
    return Image.asset(imgUrl, gaplessPlayback: true);
  }
}
