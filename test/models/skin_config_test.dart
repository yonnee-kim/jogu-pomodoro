import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/skins/skin_registry.dart';

void main() {
  group('skinConfigs 리스트 검증', () {
    test('3개 스킨 존재 (apple, wash, school)', () {
      expect(skinConfigs.length, 3);
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

    test('분침 오프셋 비율 = 0.026', () {
      expect(apple.clockHandFootOffset, 0.026);
    });

    test('분침 에셋 경로', () {
      expect(apple.clockHandFootAsset, 'assets/img/apple/apple.png');
    });

    test('분침 너비 비율 = 0.1', () {
      expect(apple.clockHandFootWidth, 0.1);
    });

    test('centerAnimationScale은 null (스케일 없음)', () {
      expect(apple.centerAnimationScale, isNull);
    });

    test('centerClipBehavior는 Clip.hardEdge', () {
      expect(apple.centerClipBehavior, Clip.hardEdge);
    });

    test('clockHandFoot은 역회전 (기본값)', () {
      expect(apple.clockHandFootRotatesWithDial, isFalse);
    });

    test('timerOverlayBuilder는 null', () {
      expect(apple.timerOverlayBuilder, isNull);
    });

    test('apple GIF 8개 precache', () {
      expect(apple.precacheImagePaths.length, 8);
      expect(apple.precacheImagePaths, contains('assets/gif/apple/apple_01_blink.gif'));
      expect(apple.precacheImagePaths, contains('assets/gif/apple/apple_04.gif'));
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

    test('분침 오프셋 비율 = 0.031', () {
      expect(wash.clockHandFootOffset, 0.031);
    });

    test('분침 에셋 경로', () {
      expect(wash.clockHandFootAsset, 'assets/img/wash/dot.png');
    });

    test('clockHandFoot은 역회전 (기본값)', () {
      expect(wash.clockHandFootRotatesWithDial, isFalse);
    });

    test('centerAnimationScale = 1.11', () {
      expect(wash.centerAnimationScale, 1.11);
    });

    test('timerOverlayBuilder가 존재', () {
      expect(wash.timerOverlayBuilder, isNotNull);
    });

    test('wash GIF 4개 prefetch', () {
      expect(wash.prefetchGifPaths.length, 4);
      expect(wash.prefetchGifPaths, contains('assets/gif/wash/wash_blink.gif'));
      expect(wash.prefetchGifPaths, contains('assets/gif/wash/wash_activate.gif'));
    });

    test('machine head 이미지 2개 precache', () {
      expect(wash.precacheImagePaths, contains('assets/img/wash/machine_head_on.png'));
      expect(wash.precacheImagePaths, contains('assets/img/wash/machine_head_off.png'));
    });
  });

  group('school 스킨 설정값 회귀 테스트', () {
    late SkinConfig school;

    setUp(() {
      school = skinConfigs.firstWhere((s) => s.id == 'school');
    });

    test('배경색은 하늘색', () {
      expect(school.backgroundColor, const Color(0xFF87CEEB));
    });

    test('다이얼 원 색상 transparent', () {
      expect(school.dialCircleColor, Colors.transparent);
    });

    test('다이얼 그림자 transparent', () {
      expect(school.dialShadowColor, Colors.transparent);
    });

    test('남은시간 색상 노란색', () {
      expect(school.leftTimeColor, const Color(0xFFFFD300));
    });

    test('숫자 틴트 없음', () {
      expect(school.numberTintColor, isNull);
    });

    test('분침 에셋 경로', () {
      expect(school.clockHandFootAsset, 'assets/img/school/head.png');
    });

    test('분침 너비 비율 = 0.3', () {
      expect(school.clockHandFootWidth, 0.3);
    });

    test('clockHandFoot은 다이얼과 함께 회전', () {
      expect(school.clockHandFootRotatesWithDial, isTrue);
    });

    test('timerOverlayBuilder는 null', () {
      expect(school.timerOverlayBuilder, isNull);
    });

    test('backgroundBuilder가 존재', () {
      expect(school.backgroundBuilder, isNotNull);
    });

    test('dialImageAsset은 school/chrono.png', () {
      expect(school.dialImageAsset, 'assets/img/school/chrono.png');
    });

    test('전용 버튼 에셋 존재', () {
      expect(school.playButtonAsset, 'assets/img/school/play.png');
      expect(school.stopButtonAsset, 'assets/img/school/stop.png');
      expect(school.changeButtonAsset, 'assets/img/school/change.png');
    });

    test('dialBackgroundBuilder가 존재', () {
      expect(school.dialBackgroundBuilder, isNotNull);
    });

    test('dialOverlayBuilder가 존재', () {
      expect(school.dialOverlayBuilder, isNotNull);
    });

    test('GIF 없음', () {
      expect(school.prefetchGifPaths, isEmpty);
    });

    test('school 에셋 10개 precache', () {
      expect(school.precacheImagePaths.length, 10);
      expect(school.precacheImagePaths, contains('assets/img/school/head.png'));
      expect(school.precacheImagePaths, contains('assets/img/school/school.png'));
    });
  });
}
