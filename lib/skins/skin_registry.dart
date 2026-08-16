import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/skins/apple/apple_skin.dart';
import 'package:joguman_pomodoro/skins/wash/wash_skin.dart';
import 'package:joguman_pomodoro/skins/school/school_skin.dart';

/// 새 스킨 추가: lib/skins/<id>/ 디렉토리 생성 → 여기에 import + 등록
final List<SkinConfig> skinConfigs = [
  appleSkinConfig,
  washSkinConfig,
  schoolSkinConfig,
];

/// 모든 스킨에서 공유하는 에셋 경로
const List<String> sharedImagePaths = [
  'assets/img/play.png',
  'assets/img/stop.png',
  'assets/img/1.png',
  'assets/img/2.png',
  'assets/img/3.png',
  'assets/img/4.png',
  'assets/img/5.png',
  'assets/img/6.png',
  'assets/img/7.png',
  'assets/img/8.png',
  'assets/img/9.png',
  'assets/img/0.png',
  'assets/img/colon.png',
];

/// 모든 스킨이 가로모드에서 공유하는 배치 앵커.
/// wash 가로 배경 이미지(2869×1321)의 부품 위치 기준으로 측정했다.
/// 다이얼: 가운데 패널 중앙 / 타이머: 검은 디스플레이 박스(x 0.67~0.94, y 0.34~0.54) 중앙
const LandscapeAnchors sharedLandscapeAnchors = LandscapeAnchors(
  imageAspect: 2869 / 1321,
  dialCenter: Offset(0.390, 0.500),
  dialHeightFactor: 0.84,
  timerCenter: Offset(0.805, 0.442),
  numberHeightFactor: 0.1,
  buttonsCenter: Offset(0.805, 0.700),
  buttonSizeFactor: 0.15,
  buttonGapFactor: 0.12,
);
