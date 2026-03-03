import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/skins/skin_registry.dart';

void main() {
  group('스킨 디렉토리 구조 무결성', () {
    test('각 스킨 ID에 대응하는 lib/skins/<id>/ 디렉토리 존재', () {
      for (final skin in skinConfigs) {
        final dir = Directory('lib/skins/${skin.id}');
        expect(dir.existsSync(), isTrue, reason: 'lib/skins/${skin.id}/ 디렉토리가 존재하지 않습니다');
      }
    });

    test('각 스킨 ID에 대응하는 <id>_skin.dart 파일 존재', () {
      for (final skin in skinConfigs) {
        final file = File('lib/skins/${skin.id}/${skin.id}_skin.dart');
        expect(file.existsSync(), isTrue, reason: 'lib/skins/${skin.id}/${skin.id}_skin.dart 파일이 존재하지 않습니다');
      }
    });

    test('중복 스킨 ID 없음', () {
      final ids = skinConfigs.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
