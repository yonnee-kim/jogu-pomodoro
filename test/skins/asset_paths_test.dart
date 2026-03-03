import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/skins/skin_registry.dart';

void main() {
  group('에셋 파일 존재 검증', () {
    test('모든 스킨의 precacheImagePaths 파일이 존재', () {
      for (final skin in skinConfigs) {
        for (final path in skin.precacheImagePaths) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path 파일이 존재하지 않습니다 (skin: ${skin.id})');
        }
      }
    });

    test('모든 스킨의 prefetchGifPaths 파일이 존재', () {
      for (final skin in skinConfigs) {
        for (final path in skin.prefetchGifPaths) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path 파일이 존재하지 않습니다 (skin: ${skin.id})');
        }
      }
    });

    test('모든 스킨의 clockHandFootAsset 파일이 존재', () {
      for (final skin in skinConfigs) {
        final file = File(skin.clockHandFootAsset);
        expect(file.existsSync(), isTrue, reason: '${skin.clockHandFootAsset} 파일이 존재하지 않습니다 (skin: ${skin.id})');
      }
    });

    test('sharedImagePaths 파일이 모두 존재', () {
      for (final path in sharedImagePaths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path 파일이 존재하지 않습니다');
      }
    });
  });
}
