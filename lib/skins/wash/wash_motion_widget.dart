// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/skins/wash/wash_motion_logic.dart';
import 'package:joguman_pomodoro/widgets/my_gif.dart';
import 'package:provider/provider.dart';

class WashMotionWidget extends StatefulWidget {
  const WashMotionWidget({super.key});

  @override
  State<WashMotionWidget> createState() => _WashMotionWidgetState();
}

class _WashMotionWidgetState extends State<WashMotionWidget> {
  final controllerBlink = GifController();
  final controllerStart = GifController();
  final controllerActivate = GifController();
  final controllerStop = GifController();
  late WashState _state;
  late final WashState _initialState; // 마운트 시 1회 고정 — autoPlay 대상 결정용
  // 초기 모션이 로딩된 뒤에 나머지 GIF를 빌드한다 — 마운트 직후 4개가
  // 동시에 디코딩을 경쟁하면 정작 첫 화면의 모션이 몇 배 늦게 뜬다.
  bool _restBuilt = false;

  GifController _controllerOf(WashState state) {
    switch (state) {
      case WashState.blink:
        return controllerBlink;
      case WashState.start:
        return controllerStart;
      case WashState.activate:
        return controllerActivate;
      case WashState.stop:
        return controllerStop;
    }
  }

  @override
  void initState() {
    super.initState();
    _initialState =
        washInitialState(isStarted: context.read<DataProvider>().isStarted);
    _state = _initialState;
  }

  @override
  void dispose() {
    controllerBlink.dispose();
    controllerStart.dispose();
    controllerActivate.dispose();
    controllerStop.dispose();
    super.dispose();
  }

  Future<void> _onFinish(WashState finished) async {
    if (!mounted) return;
    final bool isStarted = context.read<DataProvider>().isStarted;
    final WashState next =
        washNextState(finished: finished, isStarted: isStarted);
    if (next == finished) {
      // 같은 모션 반복: blink는 loop=true라 seek(0)만, activate는 재생을 다시 건다
      final controller = _controllerOf(finished);
      controller.seek(0);
      if (finished == WashState.activate) {
        await Future.delayed(const Duration(milliseconds: 1));
        if (!mounted) return;
        controller.play();
      }
    } else {
      _controllerOf(finished).stop();
      _controllerOf(next).play();
    }
    if (!mounted) return;
    setState(() => _state = next);
  }

  /// GIF 디코딩 완료 전에 전환이 걸려 play()가 무시된 경우를 복구한다.
  /// gif_view 1.0.2의 onLoaded는 GifController.configure() 이전에 호출되어
  /// 이 시점엔 아직 frames가 비어 있다 — 여기서 바로 play()를 불러도 무시된다.
  /// configure() 완료 후(다음 마이크로태스크)로 미뤄 놓친 play()를 복구한다.
  void _onGifLoaded(WashState loaded) {
    scheduleMicrotask(() {
      if (!mounted) return;
      if (loaded == _initialState && !_restBuilt) {
        setState(() => _restBuilt = true);
      }
      final controller = _controllerOf(loaded);
      if (_state != loaded) {
        // 로딩 중 다른 상태로 전환된 경우 autoPlay 잔여 재생 정리
        controller.stop();
        return;
      }
      if (!controller.isPlaying) {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<DataProvider, bool>(
      selector: (context, dataProvider) => dataProvider.isStarted,
      builder: (context, isStarted, child) {
        // 화면에 보이는 중 시작 조작을 목격하면 즉시 start 전환 모션 재생
        // (정지는 기존 동작대로 현재 모션이 끝나는 시점에 _onFinish에서 전이)
        if (isStarted && _state == WashState.blink) {
          _state = WashState.start;
          controllerBlink.stop();
          controllerStart.play();
        }
        // 초기 모션이 준비되기 전에는 그 모션만 빌드하고(디코딩 독점),
        // 전환 대상이 아직 준비 전이면 초기 모션을 계속 보여준다 (빈 화면 방지)
        Widget staged(WashState state, Widget gif) =>
            (_restBuilt || state == _initialState)
                ? gif
                : const SizedBox.shrink();
        final int displayIndex = (_restBuilt || _state == _initialState)
            ? _state.index
            : _initialState.index;
        return IndexedStack(
          index: displayIndex,
          children: [
            staged(
                WashState.blink,
                MyGif(
                    image: 'assets/gif/wash/wash_blink.gif',
                    callback: () => _onFinish(WashState.blink),
                    controller: controllerBlink,
                    autoPlay: _initialState == WashState.blink,
                    loop: true,
                    onLoaded: () => _onGifLoaded(WashState.blink))),
            staged(
                WashState.start,
                MyGif(
                    image: 'assets/gif/wash/wash_start.gif',
                    callback: () => _onFinish(WashState.start),
                    controller: controllerStart,
                    onLoaded: () => _onGifLoaded(WashState.start))),
            staged(
                WashState.activate,
                MyGif(
                    image: 'assets/gif/wash/wash_activate.gif',
                    callback: () => _onFinish(WashState.activate),
                    controller: controllerActivate,
                    autoPlay: _initialState == WashState.activate,
                    onLoaded: () => _onGifLoaded(WashState.activate))),
            staged(
                WashState.stop,
                MyGif(
                    image: 'assets/gif/wash/wash_stop.gif',
                    callback: () => _onFinish(WashState.stop),
                    controller: controllerStop,
                    onLoaded: () => _onGifLoaded(WashState.stop))),
          ],
        );
      },
    );
  }
}
