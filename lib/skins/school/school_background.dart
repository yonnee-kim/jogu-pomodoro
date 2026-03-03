import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class SchoolBackground extends StatelessWidget {
  const SchoolBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Transform.translate(
              offset: Offset(0, 1.h * 0),
              child: Image.asset(
                'assets/img/school/sun_cloud.png',
                width: 100.w,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/img/school/green_background.png',
              fit: BoxFit.fitWidth,
            ),
          ),
        ],
      ),
    );
  }
}
