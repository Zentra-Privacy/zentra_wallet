import 'package:flutter/material.dart';

class ZentraTheme {
  static const Color primary = Color(0xFF1B5E4B);
  static const Color accent = Color(0xFF3DDC97);
  static const Color surface = Color(0xFF0F1419);
  static const Color card = Color(0xFF1A2332);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: primary,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: surface,
      ),
    );
    return base;
  }
}
