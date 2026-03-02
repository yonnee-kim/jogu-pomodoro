// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:provider/provider.dart';

import '../utility.dart';

class AppleMotionWidget extends StatefulWidget {
  const AppleMotionWidget({super.key});

  @override
  State<AppleMotionWidget> createState() => _AppleMotionWidgetState();
}

class _AppleMotionWidgetState extends State<AppleMotionWidget> {
  Timer? _debounce;
  int currSec = 0;
  int currMilliSec = 0;
  String imgUrl = 'assets/gif/apple_01_blink.gif';

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    currSec = context.read<DataProvider>().currSec;
    currMilliSec = currSec * 1000;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    if (_debounce != null && _debounce!.isActive) _debounce!.cancel();
  }

  setTimer({required int startSec}) {
    int currSec = context.read<DataProvider>().currSec;
    currMilliSec = currSec * 1000;

    if (_debounce != null && _debounce!.isActive) _debounce!.cancel();
    _debounce = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (currMilliSec > (startSec * 2 / 3).round() * 1000) {
        if (currMilliSec == startSec * 1000) {
          imgUrl = 'assets/gif/apple_02.gif';
          setState(() {});
        }
        if (currMilliSec < startSec * 1000 - getGifDurationMilliSec(imgUrl) && imgUrl != 'assets/gif/apple_02_blink.gif') {
          imgUrl = 'assets/gif/apple_02_blink.gif';
          setState(() {});
        }
      } else if (currMilliSec > (startSec * 1 / 3).round() * 1000) {
        if (currMilliSec == (startSec * 2 / 3).round() * 1000) {
          imgUrl = 'assets/gif/apple_03.gif';
          setState(() {});
        }
        if (currMilliSec < (startSec * 2 / 3).round() * 1000 - getGifDurationMilliSec(imgUrl) && imgUrl != 'assets/gif/apple_03_blink.gif') {
          imgUrl = 'assets/gif/apple_03_blink.gif';
          setState(() {});
        }
      } else if (currMilliSec > 0) {
        if (currMilliSec == (startSec * 1 / 3).round() * 1000) {
          imgUrl = 'assets/gif/apple_04.gif';
          setState(() {});
        }
        if (currMilliSec < (startSec * 1 / 3).round() * 1000 - getGifDurationMilliSec(imgUrl) && imgUrl != 'assets/gif/apple_03_blink.gif') {
          imgUrl = 'assets/gif/apple_04_blink.gif';
          setState(() {});
        }
      }
      currMilliSec -= 100;
      if (currMilliSec <= 0 && _debounce != null) {
        imgUrl = 'assets/gif/apple_01.gif';
        _debounce!.cancel();
        setState(() {});
      }
    });
  }

  getGifDurationMilliSec(String imgUrl) {
    double frameGap = 0.04;
    Map framsMap = {
      'assets/gif/apple_01.gif': 1,
      'assets/gif/apple_01_blink.gif': 46,
      'assets/gif/apple_02.gif': 72,
      'assets/gif/apple_02_blink.gif': 45,
      'assets/gif/apple_03.gif': 72,
      'assets/gif/apple_03_blink.gif': 45,
      'assets/gif/apple_04.gif': 80, // 기존 90
      'assets/gif/apple_04_blink.gif': 45,
    };
    int frameMilliSec = (frameGap * framsMap[imgUrl]).round() * 1000;
    return frameMilliSec;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<DataProvider, bool>(
      selector: (context, dataProvider) => dataProvider.isStarted,
      builder: (context, isStarted, child) {
        int startSec = context.read<DataProvider>().startSec;
        int currSec = context.read<DataProvider>().currSec;
        if (isStarted) {
          if (_debounce != null && _debounce!.isActive) {
          } else {
            setTimer(startSec: startSec);
          }
          return Image.asset(imgUrl, gaplessPlayback: true);
        } else {
          if (_debounce != null && _debounce!.isActive) _debounce!.cancel();

          if (currMilliSec > (startSec * 2 / 3).round() * 1000) {
            imgUrl = 'assets/gif/apple_02_blink.gif';
          } else if (currMilliSec > (startSec * 1 / 3).round() * 1000) {
            imgUrl = 'assets/gif/apple_03_blink.gif';
          } else if (currMilliSec > 0) {
            imgUrl = 'assets/gif/apple_04_blink.gif';
          } else if (currSec == 0) {
            imgUrl = 'assets/gif/apple_01_blink.gif';
          }

          evictAndPreCacheAll(context);
          return Image.asset(imgUrl, gaplessPlayback: true);
        }
      },
    );
  }
}
