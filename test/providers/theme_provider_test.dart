import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:joguman_pomodoro/models/skin_configs.dart';
import 'package:joguman_pomodoro/providers/theme_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// _loadThemeIndex()가 비동기로 실행되므로 완료될 때까지 대기
  Future<ThemeProvider> createProvider() async {
    final provider = ThemeProvider();
    // _loadThemeIndex의 Hive.openBox + notifyListeners 완료 대기
    await Future.delayed(const Duration(milliseconds: 50));
    return provider;
  }

  group('ThemeProvider', () {
    test('초기 themeIndex는 0', () async {
      final provider = await createProvider();
      expect(provider.themeIndex, 0);
    });

    test('skinCount는 skinConfigs.length와 동일', () async {
      final provider = await createProvider();
      expect(provider.skinCount, skinConfigs.length);
    });

    test('currentSkin은 현재 index의 SkinConfig 반환', () async {
      final provider = await createProvider();
      expect(provider.currentSkin.id, skinConfigs[0].id);
    });

    test('addThemeIndex()로 순환', () async {
      final provider = await createProvider();

      // 0 → 1
      await provider.addThemeIndex();
      expect(provider.themeIndex, 1);
      expect(provider.currentSkin.id, skinConfigs[1].id);

      // 1 → 다음 (2개면 0, 3개면 2)
      await provider.addThemeIndex();
      expect(provider.themeIndex, 2 % skinConfigs.length);
    });

    test('addThemeIndex()가 마지막 인덱스에서 0으로 순환', () async {
      final provider = await createProvider();

      for (int i = 0; i < provider.skinCount; i++) {
        await provider.addThemeIndex();
      }
      expect(provider.themeIndex, 0);
    });

    test('Hive에 themeIndex 저장', () async {
      final provider = await createProvider();
      await provider.addThemeIndex();

      final box = Hive.box('themeBox');
      expect(box.get('themeIndex'), 1);
    });

    test('저장된 index가 skinCount를 초과하면 0으로 리셋', () async {
      // 먼저 유효하지 않은 값 저장
      final box = await Hive.openBox('themeBox');
      await box.put('themeIndex', 999);
      await box.close();

      final provider = await createProvider();
      expect(provider.themeIndex, 0);
    });
  });
}
