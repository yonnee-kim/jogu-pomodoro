import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeProvider with ChangeNotifier {
  ThemeProvider() {
    _loadThemeIndex();
  }
  int themeLength = 2;
  int themeIndex = 0;


  Future<void> addThemeIndex() async {
    themeIndex = themeIndex == themeLength - 1 ? 0 : themeIndex + 1;
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
    themeIndex = themeBox.get('themeIndex') ?? 0;
    notifyListeners();
  }

  
}
