import 'package:flutter/material.dart';

const List<Color> appColors = [
  Color(0xFF356FBB), // Azul principal
  Colors.red, // Color secundario/accento
];

const List<Color> textColors = [
  Color(0xFF000000), // Negro (texto principal)
  Color(0xFFFFFFFF), // Blanco (texto sobre fondos oscuros)
  Color(0xFF356FBB), // Azul (textos destacados)
];

const defaultSelectedColor = 0;

class AppTheme {
  final int selectedColor;
  final bool isDarkMode;

  AppTheme({
    this.selectedColor = defaultSelectedColor,
    this.isDarkMode = false,
  });

  ThemeData getTheme() => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: appColors[selectedColor],
    brightness: isDarkMode ? Brightness.dark : Brightness.light,
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        fontSize: 14,
        color: isDarkMode ? textColors[1] : textColors[0],
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor:
          isDarkMode ? const Color(0xFF1E1E1E) : appColors[selectedColor],
    ),
  );
}
