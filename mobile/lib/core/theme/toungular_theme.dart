import 'package:flutter/material.dart';

abstract final class ToungularColor {
  static const Color ink = Color(0xFF14283B);
  static const Color paper = Color(0xFFFFFCF5);
  static const Color sand = Color(0xFFF2E9D8);
  static const Color leaf = Color(0xFF1D6C57);
  static const Color lime = Color(0xFFCFF57B);
  static const Color coral = Color(0xFFE86B4B);
  static const Color mist = Color(0xFFE5F1EB);
  static const Color mutedInk = Color(0xFF5B6974);
}

abstract final class ToungularSpace {
  static const double xs = 6;
  static const double s = 12;
  static const double m = 18;
  static const double l = 24;
  static const double xl = 32;
}

abstract final class ToungularTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: ToungularColor.leaf,
      brightness: Brightness.light,
      primary: ToungularColor.leaf,
      secondary: ToungularColor.coral,
      surface: ToungularColor.paper,
      error: const Color(0xFFB42318),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ToungularColor.paper,
      fontFamily: 'serif',
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 42, height: .98, fontWeight: FontWeight.w700, color: ToungularColor.ink),
        headlineSmall: TextStyle(fontSize: 28, height: 1.08, fontWeight: FontWeight.w700, color: ToungularColor.ink),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: ToungularColor.ink),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ToungularColor.ink),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: ToungularColor.ink),
        bodyMedium: TextStyle(fontSize: 15, height: 1.4, color: ToungularColor.mutedInk),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ToungularColor.paper,
        foregroundColor: ToungularColor.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: ToungularColor.sand),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ToungularColor.sand)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ToungularColor.sand)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ToungularColor.leaf, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: ToungularColor.leaf,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
