import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:joguman_pomodoro/models/skin_config.dart';
import 'package:joguman_pomodoro/models/skin_configs.dart';

class ThemeProvider with ChangeNotifier {
  ThemeProvider() {
    _loadThemeIndex();
  }

  int themeIndex = 0;

  int get skinCount => skinConfigs.length;

  SkinConfig get currentSkin => skinConfigs[themeIndex];

  Future<void> addThemeIndex() async {
    themeIndex = (themeIndex + 1) % skinCount;
    Box themeBox;
    try {
      themeBox = Hive.box('themeBox');
    } catch (e) {
      themeBox = await Hive.openBox('themeBox');
    }
    await themeBox.put('themeIndex', themeIndex);
    notifyListeners();
  }

  _loadThemeIndex() async {
    var themeBox = await Hive.openBox('themeBox');
    int stored = themeBox.get('themeIndex') ?? 0;
    themeIndex = stored < skinCount ? stored : 0;
    notifyListeners();
  }
}
