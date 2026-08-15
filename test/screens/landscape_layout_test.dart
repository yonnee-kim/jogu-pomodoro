import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/screens/landscape_layout.dart';

void main() {
  group('computeCoverGeometry', () {
    const double aspect = 2.0; // 이미지 2:1

    test('화면비 == 이미지비: 배경이 화면과 정확히 일치', () {
      final g = computeCoverGeometry(
          screenWidth: 2000, screenHeight: 1000, imageAspect: aspect);
      expect(g.left, 0);
      expect(g.top, 0);
      expect(g.width, 2000);
      expect(g.height, 1000);
    });

    test('화면이 이미지보다 가로로 김: 폭 기준 확대, 상하 크롭(top 음수)', () {
      // W=2400, H=1000 → bgW=2400, bgH=1200, top=-100
      final g = computeCoverGeometry(
          screenWidth: 2400, screenHeight: 1000, imageAspect: aspect);
      expect(g.width, 2400);
      expect(g.height, closeTo(1200, 0.001));
      expect(g.left, 0);
      expect(g.top, closeTo(-100, 0.001));
    });

    test('화면이 이미지보다 세로로 김: 높이 기준 확대, 좌우 크롭(left 음수)', () {
      // W=1500, H=1000 → bgH=1000, bgW=2000, left=-250
      final g = computeCoverGeometry(
          screenWidth: 1500, screenHeight: 1000, imageAspect: aspect);
      expect(g.height, 1000);
      expect(g.width, closeTo(2000, 0.001));
      expect(g.top, 0);
      expect(g.left, closeTo(-250, 0.001));
    });

    test('mapX/mapY: 이미지 비율 좌표 → 화면 좌표 변환', () {
      final g = computeCoverGeometry(
          screenWidth: 1500, screenHeight: 1000, imageAspect: aspect);
      // 이미지 중앙은 항상 화면 중앙
      expect(g.mapX(0.5), closeTo(750, 0.001));
      expect(g.mapY(0.5), closeTo(500, 0.001));
      // 이미지 왼쪽 끝은 크롭되어 화면 밖
      expect(g.mapX(0.0), closeTo(-250, 0.001));
    });

    test('불변식: 배경은 항상 화면을 덮고(양방향 >=), 중앙 정렬', () {
      for (final wh in [
        [2400, 1000],
        [1500, 1000],
        [2000, 1000],
        [844, 390],
      ]) {
        final g = computeCoverGeometry(
            screenWidth: wh[0].toDouble(),
            screenHeight: wh[1].toDouble(),
            imageAspect: 2869 / 1321);
        expect(g.width, greaterThanOrEqualTo(wh[0].toDouble()));
        expect(g.height, greaterThanOrEqualTo(wh[1].toDouble()));
        expect(g.width / g.height, closeTo(2869 / 1321, 0.001)); // 비율 보존
        expect(g.left * 2 + g.width, closeTo(wh[0].toDouble(), 0.001));
        expect(g.top * 2 + g.height, closeTo(wh[1].toDouble(), 0.001));
      }
    });
  });
}
