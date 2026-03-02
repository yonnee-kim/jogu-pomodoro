import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/models/skin_configs.dart';

void main() {
  group('skinConfigs 리스트 검증', () {
    test('최소 2개 스킨 존재 (apple, wash)', () {
      expect(skinConfigs.length, greaterThanOrEqualTo(2));
    });

    test('각 스킨의 id가 고유함', () {
      final ids = skinConfigs.map((s) => s.id).toSet();
      expect(ids.length, skinConfigs.length);
    });

    test('각 스킨의 clockHandFootAsset이 assets/로 시작', () {
      for (final skin in skinConfigs) {
        expect(skin.clockHandFootAsset, startsWith('assets/'));
      }
    });

    test('각 스킨의 precacheImagePaths가 모두 assets/로 시작', () {
      for (final skin in skinConfigs) {
        for (final path in skin.precacheImagePaths) {
          expect(path, startsWith('assets/'));
        }
      }
    });

    test('각 스킨의 prefetchGifPaths가 모두 assets/로 시작', () {
      for (final skin in skinConfigs) {
        for (final path in skin.prefetchGifPaths) {
          expect(path, startsWith('assets/'));
        }
      }
    });
  });

  group('apple 스킨 설정값 회귀 테스트', () {
    late SkinConfig apple;

    setUp(() {
      apple = skinConfigs.firstWhere((s) => s.id == 'apple');
    });

    test('배경색은 흰색', () {
      expect(apple.backgroundColor, Colors.white);
    });

    test('다이얼 원 색상', () {
      expect(apple.dialCircleColor, const Color.fromRGBO(237, 237, 237, 1));
    });

    test('다이얼 그림자 색상', () {
      expect(apple.dialShadowColor, Colors.grey);
    });

    test('남은시간 호(arc) 색상', () {
      expect(apple.leftTimeColor, const Color.fromRGBO(222, 37, 49, 1));
    });

    test('숫자 틴트 없음', () {
      expect(apple.numberTintColor, isNull);
    });

    test('분침 오프셋 = 9', () {
      expect(apple.clockHandFootOffset, 9);
    });

    test('분침 에셋 경로', () {
      expect(apple.clockHandFootAsset, 'assets/img/apple/apple.png');
    });

    test('분침 너비 = 36', () {
      expect(apple.clockHandFootWidth, 36);
    });

    test('centerAnimationScale은 null (스케일 없음)', () {
      expect(apple.centerAnimationScale, isNull);
    });

    test('centerClipBehavior는 Clip.hardEdge', () {
      expect(apple.centerClipBehavior, Clip.hardEdge);
    });

    test('timerOverlayBuilder는 null', () {
      expect(apple.timerOverlayBuilder, isNull);
    });

    test('apple GIF 8개 precache', () {
      expect(apple.precacheImagePaths.length, 8);
      expect(apple.precacheImagePaths, contains('assets/gif/apple_01_blink.gif'));
      expect(apple.precacheImagePaths, contains('assets/gif/apple_04.gif'));
    });
  });

  group('wash 스킨 설정값 회귀 테스트', () {
    late SkinConfig wash;

    setUp(() {
      wash = skinConfigs.firstWhere((s) => s.id == 'wash');
    });

    test('배경색', () {
      expect(wash.backgroundColor, const Color.fromRGBO(245, 246, 247, 1));
    });

    test('다이얼 원 색상', () {
      expect(wash.dialCircleColor, const Color.fromRGBO(210, 210, 215, 1));
    });

    test('남은시간 호(arc) 색상', () {
      expect(wash.leftTimeColor, const Color.fromRGBO(22, 20, 24, 1));
    });

    test('숫자 틴트 = jogumanYellow', () {
      expect(wash.numberTintColor, const Color.fromRGBO(255, 211, 0, 1));
    });

    test('분침 오프셋 = 11', () {
      expect(wash.clockHandFootOffset, 11);
    });

    test('분침 에셋 경로', () {
      expect(wash.clockHandFootAsset, 'assets/img/wash/dot.png');
    });

    test('centerAnimationScale = 1.11', () {
      expect(wash.centerAnimationScale, 1.11);
    });

    test('timerOverlayBuilder가 존재', () {
      expect(wash.timerOverlayBuilder, isNotNull);
    });

    test('wash GIF 4개 prefetch', () {
      expect(wash.prefetchGifPaths.length, 4);
      expect(wash.prefetchGifPaths, contains('assets/gif/wash_blink.gif'));
      expect(wash.prefetchGifPaths, contains('assets/gif/wash_activate.gif'));
    });

    test('machine head 이미지 2개 precache', () {
      expect(wash.precacheImagePaths, contains('assets/img/wash/machine_head_on.png'));
      expect(wash.precacheImagePaths, contains('assets/img/wash/machine_head_off.png'));
    });
  });
}
