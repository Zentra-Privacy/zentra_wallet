import 'package:flutter/material.dart';

/// Clean dark theme — flat surfaces, no glow shadows.
class ZentraTheme {
  static const Color accent = Color(0xFF6E56CF);
  static const Color background = Color(0xFF0E1117);
  static const Color surface = Color(0xFF161B22);
  static const Color card = Color(0xFF1C2128);
  static const Color border = Color(0xFF30363D);
  static const Color textPrimary = Color(0xFFF0F3F6);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color success = Color(0xFF3FB950);
  static const Color danger = Color(0xFFF85149);

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: textMuted),
        labelLarge: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          elevation: 0,
          side: const BorderSide(color: border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
    );
  }

  static BoxDecoration flatCard({Color? color, double radius = radiusMd}) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }
}
