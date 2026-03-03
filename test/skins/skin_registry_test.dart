import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/skins/skin_registry.dart';

void main() {
  group('skinConfigs 레지스트리 검증', () {
    test('최소 2개 스킨 존재', () {
      expect(skinConfigs.length, greaterThanOrEqualTo(2));
    });

    test('모든 스킨 ID 고유', () {
      final ids = skinConfigs.map((s) => s.id).toSet();
      expect(ids.length, skinConfigs.length);
    });

    test('스킨 순서: [apple, wash]', () {
      expect(skinConfigs[0].id, 'apple');
      expect(skinConfigs[1].id, 'wash');
    });

    test('sharedImagePaths에 숫자/컨트롤 이미지 포함', () {
      expect(sharedImagePaths, contains('assets/img/0.png'));
      expect(sharedImagePaths, contains('assets/img/9.png'));
      expect(sharedImagePaths, contains('assets/img/colon.png'));
      expect(sharedImagePaths, contains('assets/img/play.png'));
      expect(sharedImagePaths, contains('assets/img/stop.png'));
    });
  });
}
