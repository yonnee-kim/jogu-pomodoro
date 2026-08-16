const double _frameGap = 0.04;

const Map<String, int> appleGifFrames = {
  'assets/gif/apple/apple_01.gif': 1,
  'assets/gif/apple/apple_01_blink.gif': 46,
  'assets/gif/apple/apple_02.gif': 72,
  'assets/gif/apple/apple_02_blink.gif': 45,
  'assets/gif/apple/apple_03.gif': 72,
  'assets/gif/apple/apple_03_blink.gif': 45,
  'assets/gif/apple/apple_04.gif': 80,
  'assets/gif/apple/apple_04_blink.gif': 45,
};

int getGifDurationMilliSec(String imgUrl) {
  int frames = appleGifFrames[imgUrl] ?? 0;
  return (_frameGap * frames).round() * 1000;
}

/// 타이머 일시정지 시 현재 남은 시간에 맞는 정지 프레임 GIF를 반환한다.
String getAppleGifForPause({
  required int startSec,
  required int currentMilliSec,
}) {
  int twoThirdMs = (startSec * 2 / 3).round() * 1000;
  int oneThirdMs = (startSec * 1 / 3).round() * 1000;

  if (currentMilliSec > twoThirdMs) {
    return 'assets/gif/apple/apple_02_blink.gif';
  } else if (currentMilliSec > oneThirdMs) {
    return 'assets/gif/apple/apple_03_blink.gif';
  } else if (currentMilliSec > 0) {
    return 'assets/gif/apple/apple_04_blink.gif';
  } else {
    return 'assets/gif/apple/apple_01_blink.gif';
  }
}

/// 남은 시간 기준 현재 구간.
/// 1: 완료, 2: 남은 시간 2/3 초과, 3: 1/3~2/3, 4: 0~1/3
int appleSegment({required int startSec, required int currentMilliSec}) {
  if (currentMilliSec <= 0) return 1;
  final int twoThirdMs = (startSec * 2 / 3).round() * 1000;
  final int oneThirdMs = (startSec * 1 / 3).round() * 1000;
  if (currentMilliSec > twoThirdMs) return 2;
  if (currentMilliSec > oneThirdMs) return 3;
  return 4;
}

/// 구간 진입을 목격했을 때 1회 재생하는 인트로 GIF 경로.
String appleIntroGif(int segment) => 'assets/gif/apple/apple_0$segment.gif';

/// 구간 대기 루프 GIF 경로.
String appleBlinkGif(int segment) => 'assets/gif/apple/apple_0${segment}_blink.gif';

/// 직전 알림 대비 정상적인 틱 진행인지 (백그라운드 복귀 등 큰 시간 점프 제외).
/// DataProvider는 재생 중 초당 알림하므로 정상 델타는 0~1000ms 근방이다.
bool isWitnessedTick({required int? lastMilliSec, required int currentMilliSec}) {
  if (lastMilliSec == null) return false;
  final int delta = lastMilliSec - currentMilliSec;
  return delta >= 0 && delta <= 1500;
}
