import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/screens/landscape_layout.dart';

void main() {
  group('computeLandscapeLayout', () {
    test('일반 폰 가로(2.2:1)는 정확히 6:4, 다이얼은 높이 기준', () {
      // W=2200, H=1000 → maxDialByHeight=900, leftRegion=1320(>900 → 확장 없음)
      final r = computeLandscapeLayout(width: 2200, height: 1000);
      expect(r.leftRegion, closeTo(1320, 0.001)); // 60%
      expect(r.rightRegion, closeTo(880, 0.001)); // 40%
      expect(r.dialSize, closeTo(900, 0.001)); // 높이 0.9
    });

    test('태블릿 가로(1.33:1)는 다이얼 영역이 6 이상으로 확장, 버튼 20% 이상', () {
      // W=1330, H=1000 → maxDialByHeight=900, leftRegion=798(<900)
      // → leftRegion=min(900, 1330*0.8=1064)=900
      final r = computeLandscapeLayout(width: 1330, height: 1000);
      expect(r.leftRegion, closeTo(900, 0.001));
      expect(r.dialSize, closeTo(900, 0.001)); // 최대높이 도달
      expect(r.rightRegion, closeTo(430, 0.001));
      expect(r.rightRegion / 1330, greaterThan(0.2)); // 버튼영역 > 20%
      expect(r.leftRegion / 1330, greaterThan(0.6)); // 다이얼영역 > 60%
    });

    test('거의 정사각(1.05:1)은 버튼영역 20% 하한, 다이얼은 최대높이 미달 허용', () {
      // W=1050, H=1000 → maxDialByHeight=900, leftRegion=630(<900)
      // → leftRegion=min(900, 1050*0.8=840)=840
      final r = computeLandscapeLayout(width: 1050, height: 1000);
      expect(r.leftRegion, closeTo(840, 0.001));
      expect(r.dialSize, closeTo(840, 0.001)); // 900에 미달(폭 제약)
      expect(r.rightRegion, closeTo(210, 0.001));
      expect(r.rightRegion / 1050, closeTo(0.2, 0.001)); // 하한 도달
    });

    test('불변식: 다이얼 크기는 항상 높이*0.9 이하, 버튼영역은 항상 폭*0.2 이상', () {
      for (final wh in [
        [1600, 900],
        [2400, 1080],
        [1194, 834],
        [2000, 1000]
      ]) {
        final r = computeLandscapeLayout(width: wh[0].toDouble(), height: wh[1].toDouble());
        expect(r.dialSize, lessThanOrEqualTo(wh[1] * 0.9 + 0.001));
        expect(r.rightRegion, greaterThanOrEqualTo(wh[0] * 0.2 - 0.001));
        expect(r.leftRegion + r.rightRegion, closeTo(wh[0].toDouble(), 0.001));
      }
    });
  });
}
