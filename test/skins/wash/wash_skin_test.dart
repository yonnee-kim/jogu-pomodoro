import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/skins/wash/wash_skin.dart';

void main() {
  group('washSkinConfig 검증', () {
    test('id는 wash', () {
      expect(washSkinConfig.id, 'wash');
    });

    test('timerOverlayBuilder가 존재', () {
      expect(washSkinConfig.timerOverlayBuilder, isNotNull);
    });

    test('prefetchGifPaths 4개 항목', () {
      expect(washSkinConfig.prefetchGifPaths.length, 4);
    });

    test('모든 에셋 경로가 assets/로 시작', () {
      for (final path in washSkinConfig.prefetchGifPaths) {
        expect(path, startsWith('assets/'));
      }
      for (final path in washSkinConfig.precacheImagePaths) {
        expect(path, startsWith('assets/'));
      }
      expect(washSkinConfig.clockHandFootAsset, startsWith('assets/'));
    });
  });
}
