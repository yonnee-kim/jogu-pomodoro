import 'dart:math' as math;

/// 가로모드 영역 분할 결과.
class LandscapeLayout {
  final double leftRegion; // 왼쪽(다이얼) 영역 폭
  final double dialSize; // 다이얼 한 변 길이(정사각)
  final double rightRegion; // 오른쪽(버튼) 영역 폭

  const LandscapeLayout({
    required this.leftRegion,
    required this.dialSize,
    required this.rightRegion,
  });
}

/// 가로 화면에서 다이얼/버튼 영역 폭과 다이얼 크기를 계산한다.
///
/// 규칙:
/// - 기본 다이얼:버튼 = dialRegionRatio : (1-dialRegionRatio) (6:4)
/// - 6:4에서 다이얼이 최대높이(height*dialHeightFactor)에 못 미치면
///   왼쪽 영역을 넓혀 다이얼을 키운다.
/// - 단, 버튼(오른쪽) 영역은 최소 width*panelMinRatio(20%) 보장.
LandscapeLayout computeLandscapeLayout({
  required double width,
  required double height,
  double dialRegionRatio = 0.6,
  double panelMinRatio = 0.2,
  double dialHeightFactor = 0.9,
}) {
  final double maxDialByHeight = height * dialHeightFactor;
  double leftRegion = width * dialRegionRatio;
  if (leftRegion < maxDialByHeight) {
    leftRegion = math.min(maxDialByHeight, width * (1 - panelMinRatio));
  }
  final double dialSize = math.min(leftRegion, maxDialByHeight);
  final double rightRegion = width - leftRegion;
  return LandscapeLayout(
    leftRegion: leftRegion,
    dialSize: dialSize,
    rightRegion: rightRegion,
  );
}
