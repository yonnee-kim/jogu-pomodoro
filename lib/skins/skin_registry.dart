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
