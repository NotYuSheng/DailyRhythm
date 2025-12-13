import 'package:flutter/material.dart';

/// LifeRhythm - Monochrome Rhythm-Inspired Theme
///
/// Design Philosophy:
/// - Pure monochrome palette (blacks, whites, grays)
/// - Minimalist and clean
/// - Rhythmic spacing and proportions
/// - Wave/pulse visual metaphors

class AppTheme {
  // SGDS-Inspired Color Palette

  // Blue Palette (Primary - from SGDS)
  static const Color blue100 = Color(0xFFEBF1FF);
  static const Color blue200 = Color(0xFFD3E2FF);
  static const Color blue300 = Color(0xFF99BBFF);
  static const Color blue400 = Color(0xFF70A0FF);
  static const Color blue500 = Color(0xFF1F69FF);
  static const Color blue600 = Color(0xFF004FF0);
  static const Color blue700 = Color(0xFF0040C2);

  // Green Palette (Secondary - Growth/Success)
  static const Color green100 = Color(0xFFECFBEE);
  static const Color green400 = Color(0xFF58BE62);
  static const Color green500 = Color(0xFF34A83E);
  static const Color green600 = Color(0xFF0A8217);

  // Semantic Colors - Warning (Amber)
  static const Color amber100 = Color(0xFFFFFAEB);
  static const Color amber400 = Color(0xFFFEC84B);
  static const Color amber500 = Color(0xFFF79009);

  // Semantic Colors - Error (Red)
  static const Color red100 = Color(0xFFFFF4F3);
  static const Color red400 = Color(0xFFFB7463);
  static const Color red600 = Color(0xFFD7260F);

  // Neutral Grey Palette (SGDS - Dominant Base)
  static const Color grey50 = Color(0xFFFAFAFB);
  static const Color grey100 = Color(0xFFF7F7F9);
  static const Color grey200 = Color(0xFFE4E7EC);
  static const Color grey300 = Color(0xFFD0D5DD);
  static const Color grey400 = Color(0xFF98A2B3);
  static const Color grey500 = Color(0xFF667085);
  static const Color grey600 = Color(0xFF344054);
  static const Color grey700 = Color(0xFF1D2939);
  static const Color grey800 = Color(0xFF161B26);
  static const Color grey900 = Color(0xFF0F1419);

  // Semantic Color Aliases
  static const Color primaryColor = blue600;
  static const Color secondaryColor = green600;
  static const Color successColor = green600;
  static const Color warningColor = amber500;
  static const Color errorColor = red600;

  // Legacy Monochrome Color Palette (Deprecated - kept for backward compatibility)
  @Deprecated('Use grey900 instead')
  static const Color rhythmBlack = Color(0xFF000000);
  @Deprecated('Use grey800 instead')
  static const Color rhythmDarkGray = Color(0xFF1A1A1A);
  @Deprecated('Use grey600 instead')
  static const Color rhythmMediumGray = Color(0xFF4A4A4A);
  @Deprecated('Use grey400 instead')
  static const Color rhythmLightGray = Color(0xFFB0B0B0);
  @Deprecated('Use grey100 instead')
  static const Color rhythmOffWhite = Color(0xFFF5F5F5);
  @Deprecated('Use Colors.white instead')
  static const Color rhythmWhite = Color(0xFFFFFFFF);

  // Legacy accent grays (Deprecated)
  @Deprecated('Use grey700 instead')
  static const Color rhythmAccent1 = Color(0xFF2D2D2D);
  @Deprecated('Use grey500 instead')
  static const Color rhythmAccent2 = Color(0xFF6B6B6B);
  @Deprecated('Use grey400 instead')
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

  // Theme-aware helper methods
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color getSecondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color getSubtleTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? grey400 : grey600;
  }

  static Color getOutlineColor(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }

  static Color getChartLineColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color getChartGridColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? grey700 : grey300;
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: grey100,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        // Primary (Blue)
        primary: blue600,
        onPrimary: Colors.white,
        primaryContainer: blue100,
        onPrimaryContainer: grey900,

        // Secondary (Green)
        secondary: green600,
        onSecondary: Colors.white,
        secondaryContainer: green100,
        onSecondaryContainer: grey900,

        // Tertiary (Amber - for special highlights)
        tertiary: amber500,
        onTertiary: Colors.white,
        tertiaryContainer: amber100,
        onTertiaryContainer: grey900,

        // Error (Red)
        error: red600,
        onError: Colors.white,
        errorContainer: red100,
        onErrorContainer: grey900,

        // Surface (Grey-dominant)
        surface: Colors.white,
        onSurface: grey900,
        surfaceContainerHighest: grey100,

        // Outline & dividers
        outline: grey300,
        outlineVariant: grey200,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: grey900,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: grey900,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(
            color: grey200,
            width: 1,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: blue600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: red600, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: red600, width: 2),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: grey900,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: grey900,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: grey900,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: grey900,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: grey900,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: grey900,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: grey700,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: grey600,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: grey500,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue600,
          foregroundColor: Colors.white,
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
          foregroundColor: blue600,
          padding: const EdgeInsets.symmetric(
            horizontal: spacePulse3,
            vertical: spacePulse2,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: grey300,
        thickness: 1,
        space: spacePulse3,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: blue600,
        unselectedItemColor: grey500,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        textColor: grey900,
        iconColor: grey700,
        selectedTileColor: blue100,
        selectedColor: blue600,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: grey900,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: grey900,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        // Primary (Blue - lighter tint for dark mode comfort)
        primary: blue400,
        onPrimary: grey900,
        primaryContainer: grey800,
        onPrimaryContainer: blue200,

        // Secondary (Green - lighter tint)
        secondary: green400,
        onSecondary: grey900,
        secondaryContainer: grey800,
        onSecondaryContainer: green100,

        // Tertiary (Amber)
        tertiary: amber400,
        onTertiary: grey900,
        tertiaryContainer: grey800,
        onTertiaryContainer: amber100,

        // Error (Red - softer for dark)
        error: red400,
        onError: grey900,
        errorContainer: grey800,
        onErrorContainer: red100,

        // Surface (Dark greys)
        surface: grey800,
        onSurface: grey50,
        surfaceContainerHighest: grey700,

        // Outline & dividers
        outline: grey600,
        outlineVariant: grey700,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: grey900,
        foregroundColor: grey50,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: grey50,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: grey800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(
            color: grey700,
            width: 1,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: grey700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: grey700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: blue400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: red400, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: red400, width: 2),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: grey50,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: grey50,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: grey50,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: grey50,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: grey50,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: grey50,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: grey200,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: grey300,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: grey400,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue400,
          foregroundColor: grey900,
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
          foregroundColor: blue300,
          padding: const EdgeInsets.symmetric(
            horizontal: spacePulse3,
            vertical: spacePulse2,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue400,
        foregroundColor: grey900,
        elevation: 0,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: grey600,
        thickness: 1,
        space: spacePulse3,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: grey900,
        selectedItemColor: blue400,
        unselectedItemColor: grey500,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        textColor: grey50,
        iconColor: grey50,
        subtitleTextStyle: TextStyle(color: grey400),
        selectedTileColor: grey800,
        selectedColor: blue400,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: grey50,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: grey800,
        deleteIconColor: grey400,
        labelStyle: const TextStyle(color: grey50),
        secondaryLabelStyle: const TextStyle(color: grey400),
        brightness: Brightness.dark,
        padding: const EdgeInsets.symmetric(
          horizontal: spacePulse2,
          vertical: spacePulse1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: grey700),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: grey800,
        titleTextStyle: const TextStyle(
          color: grey50,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: grey300,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: grey700,
        contentTextStyle: const TextStyle(color: grey50),
        actionTextColor: blue300,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue400;
          }
          return grey600;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return grey800;
          }
          return grey700;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue400;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(grey900),
        side: const BorderSide(color: grey600, width: 2),
      ),
    );
  }
}
