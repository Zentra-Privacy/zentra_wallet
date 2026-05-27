import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean dark theme — neutral surfaces, purple accent (original Zentra palette).
class ZentraTheme {
  static const Color accent = Color(0xFF6E56CF);
  static const Color primary = accent;
  static const Color primaryMuted = Color(0xFF8B7FD4);
  static const Color background = Color(0xFF0E1117);
  static const Color backgroundDeep = Color(0xFF010409);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceContainer = Color(0xFF161B22);
  static const Color surfaceContainerHigh = Color(0xFF1C2128);
  static const Color card = Color(0xFF1C2128);
  static const Color cardGradientStart = Color(0xFF21262D);
  static const Color cardGradientEnd = Color(0xFF1C2128);
  static const Color border = Color(0xFF30363D);
  static const Color borderSubtle = Color(0xFF30363D);
  static const Color textPrimary = Color(0xFFF0F3F6);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color danger = Color(0xFFF85149);

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusPill = 50;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);

  // Layout tokens (Material / mobile wallet standard)
  static const double minTouchTarget = 48;
  static const double buttonHeight = 52;
  static const double navBarHeight = 64;
  static const double navIconSize = 24;
  static const double navLabelSize = 11;
  static const double listLeadingSize = 44;
  static const double quickActionSize = 52;
  static const double appBarIconButtonSize = 48;

  static TextTheme _textTheme(Color onSurface) {
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -1,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, color: onSurface),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, color: textMuted),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, color: textMuted),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textMuted,
      ),
    );
  }

  static ThemeData dark() {
    final textTheme = _textTheme(textPrimary);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: primaryMuted,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: card,
        outline: border,
        error: danger,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          elevation: 0,
          side: const BorderSide(color: border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? textPrimary : textMuted,
          );
        }),
      ),
    );
  }

  static BoxDecoration flatCard({Color? color, double radius = radiusLg}) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }

  /// Subtle lift on flat cards — same neutral palette, not blue-tinted.
  static BoxDecoration gradientCard({double radius = radiusLg}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cardGradientStart, cardGradientEnd],
      ),
      border: Border.all(color: border),
    );
  }

  static BoxDecoration iconCircle({Color? color, double size = 40}) {
    return BoxDecoration(
      color: (color ?? accent).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(color: (color ?? accent).withValues(alpha: 0.22)),
    );
  }
}
