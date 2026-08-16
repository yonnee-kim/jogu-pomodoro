// ignore_for_file: use_build_context_synchronously

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
        controller.play();
      }
    } else {
      _controllerOf(finished).stop();
      _controllerOf(next).play();
    }
    if (!mounted) return;
    setState(() => _state = next);
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
        return IndexedStack(
          index: _state.index,
          children: [
            MyGif(
                image: 'assets/gif/wash/wash_blink.gif',
                callback: () => _onFinish(WashState.blink),
                controller: controllerBlink,
                autoPlay: _initialState == WashState.blink,
                loop: true),
            MyGif(
                image: 'assets/gif/wash/wash_start.gif',
                callback: () => _onFinish(WashState.start),
                controller: controllerStart),
            MyGif(
                image: 'assets/gif/wash/wash_activate.gif',
                callback: () => _onFinish(WashState.activate),
                controller: controllerActivate,
                autoPlay: _initialState == WashState.activate),
            MyGif(
                image: 'assets/gif/wash/wash_stop.gif',
                callback: () => _onFinish(WashState.stop),
                controller: controllerStop),
          ],
        );
      },
    );
  }
}
