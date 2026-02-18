import 'package:flutter/material.dart';

class AppThemeProvider extends ChangeNotifier {
  int _selectedColor = 0;
  bool _isDarkMode = false;
  double _fontSize = 14.0;

  int get selectedColor => _selectedColor;
  bool get isDarkMode => _isDarkMode;
  double get fontSize => _fontSize;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setThemeMode(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  void setColor(int index) {
    _selectedColor = index;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }
}
