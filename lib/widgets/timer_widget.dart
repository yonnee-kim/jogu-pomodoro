import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class TimerWidget extends StatelessWidget {
  const TimerWidget({super.key, this.numberHeight});

  final double? numberHeight;

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<ThemeProvider>().currentSkin;

    final double unit = numberHeight ?? 10.5.w;
    final double overlayHeight = unit * (51 / 10.5);
    final double overlayWidth = unit * (100 / 10.5);
    final double offsetX = unit * (-0.8 / 10.5);
    final double offsetY = unit * (2.3 / 10.5);
    final double digitGap = unit * (0.8 / 10.5);
    final double colonPad = unit * (3 / 10.5);
    int currentSec = context.watch<DataProvider>().currSec;
    int minutes = currentSec ~/ 60;
    int seconds = currentSec % 60;
    if (seconds < 0) {
      seconds = 0;
    }
    String minutes1 = intl.NumberFormat('00').format(minutes)[0];
    String minutes2 = intl.NumberFormat('00').format(minutes)[1];
    String seconds1 = intl.NumberFormat('00').format(seconds)[0];
    String seconds2 = intl.NumberFormat('00').format(seconds)[1];

    Map numberMap = {
      '1': const AssetImage('assets/img/1.png'),
      '2': const AssetImage('assets/img/2.png'),
      '3': const AssetImage('assets/img/3.png'),
      '4': const AssetImage('assets/img/4.png'),
      '5': const AssetImage('assets/img/5.png'),
      '6': const AssetImage('assets/img/6.png'),
      '7': const AssetImage('assets/img/7.png'),
      '8': const AssetImage('assets/img/8.png'),
      '9': const AssetImage('assets/img/9.png'),
      '0': const AssetImage('assets/img/0.png'),
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        Selector<DataProvider, bool>(
            selector: (context, dataProvider) => dataProvider.isStarted,
            builder: (context, isStarted, child) {
              return SizedBox(
                height: overlayHeight,
                width: overlayWidth,
                child: skin.timerOverlayBuilder != null ? skin.timerOverlayBuilder!(isStarted) : null,
              );
            }),
        Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image(image: numberMap[minutes1], color: skin.numberTintColor, height: unit),
                    SizedBox(width: digitGap),
                    Image(image: numberMap[minutes2], color: skin.numberTintColor, height: unit),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: colonPad),
                child: Image.asset('assets/img/colon.png', color: skin.numberTintColor, height: unit),
              ),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Image(image: numberMap[seconds1], color: skin.numberTintColor, height: unit),
                    SizedBox(width: digitGap),
                    Image(image: numberMap[seconds2], color: skin.numberTintColor, height: unit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
