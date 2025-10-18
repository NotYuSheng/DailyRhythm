import 'package:flutter/material.dart';

/// LifeRhythm - Monochrome Rhythm-Inspired Theme
///
/// Design Philosophy:
/// - Pure monochrome palette (blacks, whites, grays)
/// - Minimalist and clean
/// - Rhythmic spacing and proportions
/// - Wave/pulse visual metaphors

class AppTheme {
  // Monochrome Color Palette
  static const Color rhythmBlack = Color(0xFF000000);
  static const Color rhythmDarkGray = Color(0xFF1A1A1A);
  static const Color rhythmMediumGray = Color(0xFF4A4A4A);
  static const Color rhythmLightGray = Color(0xFFB0B0B0);
  static const Color rhythmOffWhite = Color(0xFFF5F5F5);
  static const Color rhythmWhite = Color(0xFFFFFFFF);

  // Accent grays for subtle hierarchy
  static const Color rhythmAccent1 = Color(0xFF2D2D2D);
  static const Color rhythmAccent2 = Color(0xFF6B6B6B);
  static const Color rhythmAccent3 = Color(0xFF8F8F8F);

  // Rhythmic spacing system (based on 8px grid)
  static const double spacePulse1 = 4.0;   // Smallest pulse
  static const double spacePulse2 = 8.0;   // Base rhythm
  static const double spacePulse3 = 16.0;  // Standard spacing
  static const double spacePulse4 = 24.0;  // Section spacing
  static const double spacePulse5 = 32.0;  // Large spacing
  static const double spacePulse6 = 48.0;  // Major sections

  // Border radius (subtle, minimal)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: rhythmOffWhite,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: rhythmBlack,
        onPrimary: rhythmWhite,
        secondary: rhythmMediumGray,
        onSecondary: rhythmWhite,
        surface: rhythmWhite,
        onSurface: rhythmBlack,
        error: rhythmMediumGray,
        onError: rhythmWhite,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: rhythmWhite,
        foregroundColor: rhythmBlack,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: rhythmBlack,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: rhythmWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(
            color: rhythmLightGray,
            width: 1,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: rhythmOffWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: rhythmLightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: rhythmLightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: rhythmBlack, width: 2),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: rhythmBlack,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: rhythmBlack,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: rhythmBlack,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: rhythmBlack,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: rhythmBlack,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: rhythmBlack,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: rhythmDarkGray,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: rhythmMediumGray,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: rhythmAccent2,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: rhythmBlack,
          foregroundColor: rhythmWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacePulse4,
            vertical: spacePulse3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: rhythmBlack,
          padding: const EdgeInsets.symmetric(
            horizontal: spacePulse3,
            vertical: spacePulse2,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: rhythmBlack,
        foregroundColor: rhythmWhite,
        elevation: 0,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: rhythmLightGray,
        thickness: 1,
        space: spacePulse3,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: rhythmWhite,
        selectedItemColor: rhythmBlack,
        unselectedItemColor: rhythmMediumGray,
        selectedLabelStyle: TextStyle(fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        textColor: rhythmBlack,
        iconColor: rhythmBlack,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: rhythmBlack,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: rhythmBlack,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: rhythmWhite,
        onPrimary: rhythmBlack,
        secondary: rhythmLightGray,
        onSecondary: rhythmBlack,
        surface: rhythmDarkGray,
        onSurface: rhythmWhite,
        error: rhythmLightGray,
        onError: rhythmBlack,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: rhythmBlack,
        foregroundColor: rhythmWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: rhythmWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: rhythmDarkGray,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(
            color: rhythmAccent1,
            width: 1,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: rhythmDarkGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: rhythmAccent1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: rhythmAccent1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: rhythmWhite, width: 2),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: rhythmWhite,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: rhythmWhite,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: rhythmWhite,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: rhythmWhite,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: rhythmWhite,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: rhythmWhite,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: rhythmOffWhite,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: rhythmLightGray,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: rhythmAccent3,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: rhythmWhite,
          foregroundColor: rhythmBlack,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacePulse4,
            vertical: spacePulse3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: rhythmWhite,
          padding: const EdgeInsets.symmetric(
            horizontal: spacePulse3,
            vertical: spacePulse2,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: rhythmWhite,
        foregroundColor: rhythmBlack,
        elevation: 0,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: rhythmAccent1,
        thickness: 1,
        space: spacePulse3,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: rhythmBlack,
        selectedItemColor: rhythmWhite,
        unselectedItemColor: rhythmAccent2,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        textColor: rhythmWhite,
        iconColor: rhythmWhite,
        subtitleTextStyle: TextStyle(color: rhythmLightGray),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: rhythmWhite,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: rhythmAccent1,
        deleteIconColor: rhythmLightGray,
        labelStyle: const TextStyle(color: rhythmWhite),
        secondaryLabelStyle: const TextStyle(color: rhythmLightGray),
        brightness: Brightness.dark,
        padding: const EdgeInsets.symmetric(
          horizontal: spacePulse2,
          vertical: spacePulse1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: rhythmAccent1),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: rhythmDarkGray,
        titleTextStyle: const TextStyle(
          color: rhythmWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: rhythmLightGray,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: rhythmAccent1,
        contentTextStyle: const TextStyle(color: rhythmWhite),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return rhythmWhite;
          }
          return rhythmAccent2;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return rhythmAccent2;
          }
          return rhythmAccent1;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return rhythmWhite;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(rhythmBlack),
        side: const BorderSide(color: rhythmAccent2, width: 2),
      ),
    );
  }
}
