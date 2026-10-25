import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';

/// DailyRhythm - Rhythm-Inspired Theme
///
/// Design Philosophy:
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

  // Brand colors for each brightness. flex_color_scheme derives the rest of
  // the Material 3 scheme (surfaces, containers, on-colors) from these.
  // The garden palette (see GardenColors): leaf green, warm pot clay and
  // bloom pink on a soft green ground, so every screen matches Today.
  static const FlexSchemeColor _lightColors = FlexSchemeColor(
    primary: Color(0xFF1F6B45),
    primaryContainer: Color(0xFFD3EDDD),
    secondary: Color(0xFF9A4F2E),
    secondaryContainer: Color(0xFFFBE0D3),
    tertiary: Color(0xFFB0305C),
    tertiaryContainer: Color(0xFFFFDDE7),
    error: red600,
    errorContainer: red100,
  );

  static const FlexSchemeColor _darkColors = FlexSchemeColor(
    primary: Color(0xFF7FD1A3),
    primaryContainer: Color(0xFF1D3328),
    secondary: Color(0xFFF2A27E),
    secondaryContainer: Color(0xFF4A2C1E),
    tertiary: Color(0xFFFF9EB5),
    tertiaryContainer: Color(0xFF4A2231),
    error: red400,
    errorContainer: red600,
  );

  static const _groundLight = Color(0xFFEAF6EE);
  static const _groundDark = Color(0xFF13201A);

  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    blendOnLevel: 10,
    useMaterial3Typography: true,
    defaultRadius: 22,
    cardRadius: 26,
    cardElevation: 0,
    inputDecoratorRadius: 16,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorIsFilled: true,
    inputDecoratorUnfocusedHasBorder: false,
    chipRadius: 20,
    dialogRadius: 28,
    bottomSheetRadius: 28,
    snackBarRadius: 16,
    appBarCenterTitle: true,
    alignedDropdown: true,
    segmentedButtonSchemeColor: SchemeColor.primary,
    navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
    navigationBarMutedUnselectedLabel: true,
    navigationBarMutedUnselectedIcon: true,
  );

  static ThemeData get lightTheme => FlexThemeData.light(
        colors: _lightColors,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 2,
        scaffoldBackground: _groundLight,
        appBarBackground: _groundLight,
        fontFamily: 'Nunito',
        subThemesData: _subThemes,
      );

  static ThemeData get darkTheme => FlexThemeData.dark(
        colors: _darkColors,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 8,
        scaffoldBackground: _groundDark,
        appBarBackground: _groundDark,
        fontFamily: 'Nunito',
        subThemesData: _subThemes,
      );
}
