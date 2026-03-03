import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/skins/apple/apple_skin.dart';

void main() {
  group('appleSkinConfig 검증', () {
    test('id는 apple', () {
      expect(appleSkinConfig.id, 'apple');
    });

    test('motionWidgetBuilder가 존재', () {
      expect(appleSkinConfig.motionWidgetBuilder, isNotNull);
    });

    test('precacheImagePaths 8개 항목', () {
      expect(appleSkinConfig.precacheImagePaths.length, 8);
    });

    test('모든 에셋 경로가 assets/로 시작', () {
      for (final path in appleSkinConfig.precacheImagePaths) {
        expect(path, startsWith('assets/'));
      }
      expect(appleSkinConfig.clockHandFootAsset, startsWith('assets/'));
    });
  });
}
