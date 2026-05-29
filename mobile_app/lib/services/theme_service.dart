import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const Color accentColor = Color(0xFF6C63FF);

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeService() {
    _loadTheme();
  }

  void toggleTheme() async {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isDark = prefs.getBool('isDarkMode');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      primaryColor: accentColor,
      cardColor: const Color(0xFF0A0A0A),
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.roboto(fontWeight: FontWeight.w800, color: Colors.white),
        headlineMedium: GoogleFonts.roboto(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: Color(0xFF0A0A0A),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F8FA),
      primaryColor: accentColor,
      cardColor: Colors.white,
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.roboto(fontWeight: FontWeight.w800, color: Colors.black),
        headlineMedium: GoogleFonts.roboto(fontWeight: FontWeight.w700, color: Colors.black),
      ),
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        secondary: accentColor,
        surface: Colors.white,
      ),
    );
  }
}
