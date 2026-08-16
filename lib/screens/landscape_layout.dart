import 'dart:math' as math;

/// BoxFit.cover로 그려진 배경 이미지가 화면에서 차지하는 실제 영역.
/// 화면 밖으로 잘리는 부분이 있으면 left/top이 음수가 된다.
class CoverGeometry {
  final double left;
  final double top;
  final double width;
  final double height;

  const CoverGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// 이미지 기준 비율 좌표(0~1)를 화면 좌표로 변환.
  double mapX(double fx) => left + fx * width;
  double mapY(double fy) => top + fy * height;
}

/// 화면 크기와 이미지 가로/세로비로 BoxFit.cover 기하를 계산한다.
/// 위젯을 배경 이미지의 특정 지점에 기기 무관하게 고정(앵커)할 때 사용.
CoverGeometry computeCoverGeometry({
  required double screenWidth,
  required double screenHeight,
  required double imageAspect,
}) {
  final double bgWidth = math.max(screenWidth, screenHeight * imageAspect);
  final double bgHeight = math.max(screenHeight, screenWidth / imageAspect);
  return CoverGeometry(
    left: (screenWidth - bgWidth) / 2,
    top: (screenHeight - bgHeight) / 2,
    width: bgWidth,
    height: bgHeight,
  );
}
