import 'dart:async';
import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/widgets/apple_motion_logic.dart';
import 'package:provider/provider.dart';

class AppleMotionWidget extends StatefulWidget {
  const AppleMotionWidget({super.key});

  @override
  State<AppleMotionWidget> createState() => _AppleMotionWidgetState();
}

class _AppleMotionWidgetState extends State<AppleMotionWidget> {
  Timer? _debounce;
  int currMilliSec = 0;
  String imgUrl = 'assets/gif/apple_01_blink.gif';

  @override
  void initState() {
    super.initState();
    currMilliSec = context.read<DataProvider>().currSec * 1000;
  }

  @override
  void dispose() {
    if (_debounce != null && _debounce!.isActive) _debounce!.cancel();
    super.dispose();
  }

  setTimer({required int startSec}) {
    int currSec = context.read<DataProvider>().currSec;
    currMilliSec = currSec * 1000;

    if (_debounce != null && _debounce!.isActive) _debounce!.cancel();
    _debounce = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      String newGif = getAppleGifForProgress(
        startSec: startSec,
        currentMilliSec: currMilliSec,
        currentGif: imgUrl,
      );
      if (newGif != imgUrl) {
        imgUrl = newGif;
        setState(() {});
      }
      currMilliSec -= 100;
      if (currMilliSec <= 0 && _debounce != null) {
        imgUrl = 'assets/gif/apple_01.gif';
        _debounce!.cancel();
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<DataProvider, bool>(
      selector: (context, dataProvider) => dataProvider.isStarted,
      builder: (context, isStarted, child) {
        int startSec = context.read<DataProvider>().startSec;
        if (isStarted) {
          if (_debounce != null && _debounce!.isActive) {
          } else {
            setTimer(startSec: startSec);
          }
          return Image.asset(imgUrl, gaplessPlayback: true);
        } else {
          if (_debounce != null && _debounce!.isActive) _debounce!.cancel();

          imgUrl = getAppleGifForPause(
            startSec: startSec,
            currentMilliSec: currMilliSec,
          );

          return Image.asset(imgUrl, gaplessPlayback: true);
        }
      },
    );
  }
}
