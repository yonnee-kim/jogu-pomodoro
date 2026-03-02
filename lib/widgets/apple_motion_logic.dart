const double _frameGap = 0.04;

const Map<String, int> appleGifFrames = {
  'assets/gif/apple_01.gif': 1,
  'assets/gif/apple_01_blink.gif': 46,
  'assets/gif/apple_02.gif': 72,
  'assets/gif/apple_02_blink.gif': 45,
  'assets/gif/apple_03.gif': 72,
  'assets/gif/apple_03_blink.gif': 45,
  'assets/gif/apple_04.gif': 80,
  'assets/gif/apple_04_blink.gif': 45,
};

int getGifDurationMilliSec(String imgUrl) {
  int frames = appleGifFrames[imgUrl] ?? 0;
  return (_frameGap * frames).round() * 1000;
}

/// 타이머 진행 중 현재 milliSec에 맞는 GIF 경로를 반환한다.
/// currentGif이 이미 올바른 상태면 그대로 반환 (불필요한 setState 방지).
String getAppleGifForProgress({
  required int startSec,
  required int currentMilliSec,
  required String currentGif,
}) {
  if (currentMilliSec <= 0) {
    return 'assets/gif/apple_01.gif';
  }

  int twoThirdMs = (startSec * 2 / 3).round() * 1000;
  int oneThirdMs = (startSec * 1 / 3).round() * 1000;

  // 2/3 ~ 1 구간
  if (currentMilliSec > twoThirdMs) {
    if (currentMilliSec == startSec * 1000) {
      return 'assets/gif/apple_02.gif';
    }
    if (currentMilliSec < startSec * 1000 - getGifDurationMilliSec(currentGif) &&
        currentGif != 'assets/gif/apple_02_blink.gif') {
      return 'assets/gif/apple_02_blink.gif';
    }
  }
  // 1/3 ~ 2/3 구간
  else if (currentMilliSec > oneThirdMs) {
    if (currentMilliSec == twoThirdMs) {
      return 'assets/gif/apple_03.gif';
    }
    if (currentMilliSec < twoThirdMs - getGifDurationMilliSec(currentGif) &&
        currentGif != 'assets/gif/apple_03_blink.gif') {
      return 'assets/gif/apple_03_blink.gif';
    }
  }
  // 0 ~ 1/3 구간
  else if (currentMilliSec > 0) {
    if (currentMilliSec == oneThirdMs) {
      return 'assets/gif/apple_04.gif';
    }
    if (currentMilliSec < oneThirdMs - getGifDurationMilliSec(currentGif) &&
        currentGif != 'assets/gif/apple_04_blink.gif') {
      return 'assets/gif/apple_04_blink.gif';
    }
  }

  return currentGif;
}

/// 타이머 일시정지 시 현재 남은 시간에 맞는 정지 프레임 GIF를 반환한다.
String getAppleGifForPause({
  required int startSec,
  required int currentMilliSec,
}) {
  int twoThirdMs = (startSec * 2 / 3).round() * 1000;
  int oneThirdMs = (startSec * 1 / 3).round() * 1000;

  if (currentMilliSec > twoThirdMs) {
    return 'assets/gif/apple_02_blink.gif';
  } else if (currentMilliSec > oneThirdMs) {
    return 'assets/gif/apple_03_blink.gif';
  } else if (currentMilliSec > 0) {
    return 'assets/gif/apple_04_blink.gif';
  } else {
    return 'assets/gif/apple_01_blink.gif';
  }
}
