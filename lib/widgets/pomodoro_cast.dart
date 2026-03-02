import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:joguman_pomodoro/providers/angle_provider.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';

class PomodoroCast extends StatefulWidget {
  const PomodoroCast({
    super.key,
    required this.clockSize,
    required this.clockHandWidth,
    required this.clockHandHeight,
    required this.currThemeIndex,
    this.clockHandFoot,
    this.leftTimeColor = Colors.red,
    this.backgroundImage,
    this.backgroundColor = Colors.white,
    this.dialColor,
    this.dialImage,
    this.clockHandColor = Colors.deepOrange,
    this.clockHandHead = const SizedBox(),
    this.centerAnimation,
  });
  final double clockSize;
  final double clockHandWidth;
  final double clockHandHeight;
  final int currThemeIndex;
  final Color leftTimeColor;
  final DecorationImage? backgroundImage;
  final Color backgroundColor;
  final Color? dialColor;
  final String? dialImage;
  final Color clockHandColor;
  final Widget? clockHandFoot;
  final Widget clockHandHead;
  final Widget? centerAnimation;

  @override
  State<PomodoroCast> createState() => _PomodoroCastState();
}

class _PomodoroCastState extends State<PomodoroCast> {
  bool isStop = true;
  double newMinutes = 0;
  double positionX = 0;
  double positionY = 0;
  NeverScrollableScrollPhysics? pageScrollPhysics = const NeverScrollableScrollPhysics();
  late Offset center; // 다이얼의 중심 위치

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    center = Offset(widget.clockSize / 2, widget.clockSize / 2);
    setState(() {});
  }

  void onPanUpdate(DragUpdateDetails details) {
    double angle = context.read<AngleProvider>().angle;
    int currSec = context.read<DataProvider>().currSec;
    int minutes = (currSec / 60).round();

    context.read<DataProvider>().cancleTimer();

    // 현재 손가락 위치와 중심의 위치를 이용해 각도 계산
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    angle = atan2(dy, dx) + (pi / 2); // 12시 방향을 기준으로 조정

    if (angle < 0) {
      angle += 2 * pi; // 음수 각도를 양수로 변환
    }

    context.read<AngleProvider>().setAngle(angle);

    newMinutes = (60 * (angle % (2 * pi)) / (2 * pi)); // 분 계산

    // currentMinutes가 0일 때는 반시계 방향 드래그를 막기
    if (minutes >= 0 && minutes <= 10 && newMinutes >= 15) {
      minutes = 0;
      angle = 0;
      context.read<AngleProvider>().setAngle(angle);
      context.read<DataProvider>().setCurrSec(minutes * 60);
      return;
    }
    // currentMinutes가 60 일 때는 시계 방향 드래그를 막기
    else if (minutes <= 60 && minutes >= 50 && newMinutes <= 45) {
      minutes = 60;
      angle = 2 * pi;
      context.read<AngleProvider>().setAngle(angle);
      context.read<DataProvider>().setCurrSec(minutes * 60);
      return;
    }
    //햅틱 진동
    if (newMinutes.round() - 0.2 < newMinutes && newMinutes.round() + 0.2 > newMinutes) {
      newMinutes = newMinutes.round().toDouble();
      if (newMinutes.round() != minutes) {
        HapticFeedback.lightImpact();
        minutes = newMinutes.round(); // minutes 업데이트
        context.read<DataProvider>().setCurrSec(minutes * 60);
      }
    }
    setState(() {});
  }

  void onPanEnd(DragEndDetails details) {
    double angle = context.read<AngleProvider>().angle;
    int currSec = context.read<DataProvider>().currSec;
    int minutes = (currSec / 60).round();

    // 손가락을 떼면 스냅
    angle = (minutes * (2 * pi / 60)); // 스냅할 각도
    context.read<AngleProvider>().setAngle(angle);
    context.read<DataProvider>().setStartSec(currSec);
  }

  @override
  Widget build(BuildContext context) {
    double clockSize = widget.clockSize;
    double angle = context.watch<AngleProvider>().angle;

    return Column(
      // mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            //남은 시간 표시부
            GestureDetector(
              onPanUpdate: onPanUpdate,
              onPanEnd: onPanEnd,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 크로노
                  if (widget.dialImage != null) Image.asset(widget.dialImage!, width: clockSize * 1.02),
                  // 남은시간 색상 채우기
                  Container(
                    height: clockSize * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.currThemeIndex == 0 ? const Color.fromRGBO(237, 237, 237, 1) : const Color.fromRGBO(210, 210, 215, 1),
                      boxShadow: [
                        BoxShadow(
                          color: widget.currThemeIndex == 0 ? Colors.grey : const Color.fromARGB(255, 189, 189, 189),
                          blurRadius: 20,
                          spreadRadius: -5,
                        )
                      ],
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: Size(
                          clockSize * 0.75 - 20,
                          clockSize * 0.7,
                        ),
                        painter: TimerPainter(angle: angle, leftTimeColor: widget.leftTimeColor),
                      ),
                    ),
                  ),
                  // 애니메이션
                  if (widget.centerAnimation != null) widget.centerAnimation!,
                  //사과 분침
                  if (widget.clockHandFoot != null)
                    Transform.rotate(
                      angle: angle,
                      child: Transform.translate(
                        offset: Offset(0, widget.currThemeIndex == 0 ? -(clockSize * 0.75 / 2) + 9 : -(clockSize * 0.75 / 2) + 11),
                        child: Transform.rotate(angle: -angle, child: widget.clockHandFoot),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TimerPainter extends CustomPainter {
  final double angle;
  final Color leftTimeColor;

  TimerPainter({
    required this.angle,
    required this.leftTimeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = leftTimeColor
      ..strokeWidth = 20
      // ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 원의 중심과 반지름 설정
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    // print('angle : $angle');

    // 반투명 빨간색 원호 그리기
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // 시작 각도 (12시 방향)
      angle, // 현재 각도
      false, // 센터 사용
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
