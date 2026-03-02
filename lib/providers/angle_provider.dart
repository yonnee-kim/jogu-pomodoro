import 'package:flutter/material.dart';

class AngleProvider with ChangeNotifier {
  double angle = 0;

  void setAngle(double currentAngle) {
    angle = currentAngle;
    notifyListeners();
  }
}
