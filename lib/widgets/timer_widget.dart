import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class TimerWidget extends StatefulWidget {
  const TimerWidget({
    super.key,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    int themeIndex = context.watch<ThemeProvider>().themeIndex;
    Color jogumanYellow = const Color.fromRGBO(255, 211, 0, 1);

    double numberHeight = 10.5.w;
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

    if (themeIndex == 1) {}

    return Stack(
      alignment: Alignment.center,
      children: [
        Selector<DataProvider, bool>(
            selector: (context, dataProvider) => dataProvider.isStarted,
            builder: (context, isStarted, child) {
              return SizedBox(
                height: 51.w,
                width: 100.w,
                child: themeIndex == 1
                    ? Image(image: AssetImage(isStarted ? 'assets/img/wash/machine_head_on.png' : 'assets/img/wash/machine_head_off.png'))
                    : null,
              );
            }),
        Transform.translate(
          offset: Offset(-0.8.w, 2.3.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image(image: numberMap[minutes1], color: themeIndex == 1 ? jogumanYellow : null, height: numberHeight),
                    SizedBox(width: 0.8.w),
                    Image(image: numberMap[minutes2], color: themeIndex == 1 ? jogumanYellow : null, height: numberHeight),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child: Image.asset('assets/img/colon.png', color: themeIndex == 1 ? jogumanYellow : null, height: numberHeight),
              ),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Image(image: numberMap[seconds1], color: themeIndex == 1 ? jogumanYellow : null, height: numberHeight),
                    SizedBox(width: 0.8.w),
                    Image(image: numberMap[seconds2], color: themeIndex == 1 ? jogumanYellow : null, height: numberHeight),
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
