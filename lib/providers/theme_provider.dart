import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/skins/skin_registry.dart';

class ThemeProvider with ChangeNotifier {
  ThemeProvider() {
    var themeBox = Hive.box('themeBox');
    int stored = themeBox.get('themeIndex') ?? 0;
    themeIndex = stored < skinCount ? stored : 0;
  }

  int themeIndex = 0;

  int get skinCount => skinConfigs.length;

  SkinConfig get currentSkin => skinConfigs[themeIndex];

  Future<void> addThemeIndex() async {
    themeIndex = (themeIndex + 1) % skinCount;
    var themeBox = Hive.box('themeBox');
    await themeBox.put('themeIndex', themeIndex);
    notifyListeners();
  }
}
