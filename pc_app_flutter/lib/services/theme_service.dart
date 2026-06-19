import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    primaryColor: const Color(0xFF7C3AED),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7C3AED),
      surface: Colors.white,
      onSurface: Color(0xFF1C1C1E),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F0F11),
    primaryColor: const Color(0xFF7C3AED),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF7C3AED),
      surface: Color(0xFF1A1A1E),
      onSurface: Colors.white,
    ),
  );
}
