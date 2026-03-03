import 'package:flutter/material.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/skins/wash/wash_motion_widget.dart';

final washSkinConfig = SkinConfig(
  id: 'wash',
  backgroundColor: const Color.fromRGBO(245, 246, 247, 1),
  dialCircleColor: const Color.fromRGBO(210, 210, 215, 1),
  dialShadowColor: const Color.fromARGB(255, 189, 189, 189),
  leftTimeColor: const Color.fromRGBO(22, 20, 24, 1),
  numberTintColor: const Color.fromRGBO(255, 211, 0, 1),
  clockHandFootOffset: 0.031,
  clockHandFootAsset: 'assets/img/wash/dot.png',
  clockHandFootWidth: 0.073,
  centerShadowColor: const Color.fromARGB(255, 0, 0, 0),
  centerShadowBlur: 10,
  centerShadowSpread: -1,
  centerAnimationScale: 1.11,
  centerClipBehavior: Clip.none,
  motionWidgetBuilder: () => const WashMotionWidget(),
  timerOverlayBuilder: (bool isStarted) => Image(
    image: AssetImage(isStarted ? 'assets/img/wash/machine_head_on.png' : 'assets/img/wash/machine_head_off.png'),
  ),
  precacheImagePaths: [
    'assets/img/wash/machine_head_on.png',
    'assets/img/wash/machine_head_off.png',
  ],
  prefetchGifPaths: [
    'assets/gif/wash/wash_activate.gif',
    'assets/gif/wash/wash_blink.gif',
    'assets/gif/wash/wash_start.gif',
    'assets/gif/wash/wash_stop.gif',
  ],
);
