import 'package:flutter/material.dart';

abstract final class ToungularColor {
  static const Color ink = Color(0xFF14283B);
  static const Color paper = Color(0xFFFFFCF5);
  static const Color sand = Color(0xFFF2E9D8);
  static const Color leaf = Color(0xFF1D6C57);
  static const Color leafDeep = Color(0xFF14513F);
  static const Color lime = Color(0xFFCFF57B);
  static const Color coral = Color(0xFFE86B4B);
  static const Color mist = Color(0xFFE5F1EB);
  static const Color mutedInk = Color(0xFF5B6974);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color peach = Color(0xFFFFF0E8);
  static const Color butter = Color(0xFFFFF2D9);
  static const Color lilac = Color(0xFFF0EDFF);
  static const Color sky = Color(0xFFE8F2FF);
  static const Color danger = Color(0xFFB42318);
}

abstract final class ToungularSpace {
  static const double xs = 6;
  static const double s = 12;
  static const double m = 18;
  static const double l = 24;
  static const double xl = 32;
}

abstract final class ToungularRadius {
  static const double card = 20;
  static const double button = 14;
}

abstract final class ToungularTheme {
  static const String _body = 'PlusJakartaSans';
  static const String _display = 'Fraunces';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: ToungularColor.leaf,
      brightness: Brightness.light,
      primary: ToungularColor.leaf,
      secondary: ToungularColor.coral,
      surface: ToungularColor.paper,
      error: ToungularColor.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ToungularColor.paper,
      fontFamily: _body,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: _display,
          fontSize: 42,
          height: .98,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: ToungularColor.ink,
        ),
        headlineSmall: TextStyle(
          fontFamily: _display,
          fontSize: 28,
          height: 1.08,
          fontWeight: FontWeight.w600,
          letterSpacing: -.6,
          color: ToungularColor.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: _display,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
          color: ToungularColor.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ToungularColor.ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.45,
          color: ToungularColor.ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: ToungularColor.mutedInk,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ToungularColor.paper,
        foregroundColor: ToungularColor.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _display,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
          color: ToungularColor.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: ToungularColor.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ToungularRadius.card),
          side: const BorderSide(color: ToungularColor.sand),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ToungularColor.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ToungularColor.sand),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ToungularColor.sand),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ToungularColor.leaf, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: ToungularColor.leaf,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ToungularRadius.button),
          ),
          textStyle: const TextStyle(
            fontFamily: _body,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: ToungularColor.paper,
        indicatorColor: ToungularColor.mist,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? ToungularColor.leaf
                : ToungularColor.mutedInk,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _body,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? ToungularColor.leaf
                : ToungularColor.mutedInk,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ToungularColor.mist,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ToungularColor.ink,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: const DividerThemeData(
        color: ToungularColor.sand,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ToungularColor.leaf,
      ),
    );
  }
}
