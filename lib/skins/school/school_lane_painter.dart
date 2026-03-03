import 'dart:math';
import 'package:flutter/material.dart';

/// school 스킨에서 기존 TimerPainter(호) 대신 사용하는 빈 painter.
class EmptyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 12시 방향부터 [angle]까지의 부채꼴 영역을 클리핑하는 CustomClipper.
/// lane.png 위에 노란색 tint lane.png를 겹치고, 남은 시간 영역만 보여준다.
class ArcSectorClipper extends CustomClipper<Path> {
  final double angle;

  ArcSectorClipper({required this.angle});

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = max(size.width, size.height);
    final path = Path();

    if (angle <= 0) return path;

    path.moveTo(center.dx, center.dy);
    path.lineTo(center.dx, 0); // 12시 방향

    // 12시 방향(-pi/2)에서 시계 방향으로 angle만큼 arc 추가
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      angle,
      false,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(ArcSectorClipper oldClipper) => oldClipper.angle != angle;
}

/// watch_face.png 위에 lane.png(흰색) + 노란색 tint lane.png(남은 시간)을 겹치는 위젯
class SchoolDialBackground extends StatelessWidget {
  final double dialSize;
  final double laneSize;
  final double angle;
  final Color laneColor;

  const SchoolDialBackground({
    super.key,
    required this.dialSize,
    required this.angle,
    required this.laneColor,
    double? laneSize,
  }) : laneSize = laneSize ?? dialSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dialSize,
      height: dialSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 도로 + 잔디 배경 (그림자 포함)
          Container(
            width: dialSize,
            height: dialSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Image.asset('assets/img/school/watch_face.png', width: dialSize),
          ),
          // 흰색 점선 (전체 원)
          Image.asset('assets/img/school/lane.png', width: laneSize),
          // 노란색 점선 (남은 시간 영역만 클리핑)
          ClipPath(
            clipper: ArcSectorClipper(angle: angle),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(laneColor, BlendMode.srcATop),
              child: Image.asset('assets/img/school/lane.png', width: laneSize),
            ),
          ),
        ],
      ),
    );
  }
}
