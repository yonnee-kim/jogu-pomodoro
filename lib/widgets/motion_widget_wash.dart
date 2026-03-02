// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
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
  Timer? _debounce;
  int currSec = 0;
  int currMilliSec = 0;
  int gifIndex = 0;
  bool isLoaded = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    currSec = context.read<DataProvider>().currSec;
    currMilliSec = currSec * 1000;
    initFunc();
  }

  initFunc() async {
    setState(() {
      isLoaded = true;
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controllerBlink.dispose();
    controllerStart.dispose();
    controllerActivate.dispose();
    controllerStop.dispose();

    print('세탁기 dispose됨');
    super.dispose();
  }

  void callbackBlink() {
    bool isStarted = context.read<DataProvider>().isStarted;
    if (isStarted) {
      context.read<DataProvider>().setWashGifIndex(1);
      gifIndex = 1;
      controllerBlink.stop();
      controllerStart.play();
    } else {
      controllerBlink.seek(0);
    }
    setState(() {});
  }

  void callbackStart() {
    bool isStarted = context.read<DataProvider>().isStarted;
    if (isStarted) {
      context.read<DataProvider>().setWashGifIndex(2);
      gifIndex = 2;
      controllerStart.stop();
      controllerActivate.play();
    } else {
      context.read<DataProvider>().setWashGifIndex(3);
      gifIndex = 3;
      controllerStart.stop();
      controllerStop.play();
    }
    setState(() {});
  }

  Future<void> callbackActivate() async {
    bool isStarted = context.read<DataProvider>().isStarted;
    if (isStarted) {
      controllerActivate.seek(0);
      await Future.delayed(const Duration(milliseconds: 1));
      controllerActivate.play();
    } else {
      context.read<DataProvider>().setWashGifIndex(3);
      gifIndex = 3;
      controllerActivate.stop();
      controllerStop.play();
    }
    setState(() {});
  }

  void callbackStop() {
    bool isStarted = context.read<DataProvider>().isStarted;
    if (isStarted) {
      context.read<DataProvider>().setWashGifIndex(1);
      gifIndex = 1;
      controllerStop.stop();
      controllerStart.play();
    } else {
      context.read<DataProvider>().setWashGifIndex(0);
      gifIndex = 0;
      controllerStop.stop();
      controllerBlink.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Selector<DataProvider, bool>(
      selector: (context, dataProvider) => dataProvider.isStarted,
      builder: (context, isStarted, child) {
        // int gifIndex = context.read<DataProvider>().washGifIndex;
        print('22 : $isStarted');
        if (isStarted && gifIndex == 0) {
          // 시작버튼 누른 경우
          gifIndex = 1;
          controllerStart.play();
        }
        return IndexedStack(
          index: gifIndex,
          children: [
            MyGif(image: 'assets/gif/wash_blink.gif', callback: callbackBlink, controller: controllerBlink, autoPlay: true, loop: true),
            MyGif(image: 'assets/gif/wash_start.gif', callback: callbackStart, controller: controllerStart),
            MyGif(image: 'assets/gif/wash_activate.gif', callback: callbackActivate, controller: controllerActivate),
            MyGif(image: 'assets/gif/wash_stop.gif', callback: callbackStop, controller: controllerStop),
          ],
        );
      },
    );
  }
}
