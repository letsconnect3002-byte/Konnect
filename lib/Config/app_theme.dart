import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppColors contains the color palette tokens defined for the Connect App's
/// true dark-canvas aesthetic.
class AppColors {
  AppColors._();

  static const Color canvasBackground =
      Color(0xFF000000); // Pure deep black canvas background
  static const Color surfacePrimary =
      Color(0xFF121316); // Matte obsidian dark grey for primary cards
  static const Color surfaceSecondary =
      Color(0xFF1C1D22); // Slightly lighter gray for fields, nested containers
  static const Color borderMuted =
      Color(0xFF23252B); // Thin, low-contrast border frame for containers
  static const Color textPrimary =
      Color(0xFFFFFFFF); // Pure white for major titles
  static const Color textSecondary =
      Color(0xFF8E919A); // Neutral grey for secondary labels and metadata
  static const Color textMuted =
      Color(0xFF4E515A); // Dark grey for placeholders and structural indicators

  static const Color accentPrimary = Color.fromARGB(
      255, 30, 215, 96); // Neon Volt Green (Volt scan neon fill start color)
  static const Color accentSecondary =
      Color.fromARGB(255, 30, 215, 96); // Neon Electric Violet
}

/// AppGradients contains high-fidelity accent gradients instead of flat primary colors.
class AppGradients {
  AppGradients._();

  static const LinearGradient voltScanGradient = LinearGradient(
    colors: [Color(0xFFCEF143), Color(0xFF76EC68)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ticketGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFFEC4899), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// AppTypography contains text styles using the geometric sans-serif font Inter.
class AppTypography {
  AppTypography._();

  static TextStyle get displayHeader => GoogleFonts.inter(
        fontSize: 26.0,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get screenHeading => GoogleFonts.inter(
        fontSize: 20.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardTitle => GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyText => GoogleFonts.inter(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get captionText => GoogleFonts.inter(
        fontSize: 11.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
        color: AppColors.textSecondary,
      );
}

/// AppDimensions contains margins, paddings, and radii tokens.
class AppDimensions {
  AppDimensions._();

  static const double marginStandard = 16.0;
  static const double paddingInternal = 12.0;
  static const double radiusPremiumCard = 24.0;
  static const double radiusComponent = 16.0;
  static const double radiusPill = 99.0;
}

/// AppTheme provides dark ThemeData configured with the custom palette
/// and typography tokens.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.canvasBackground,
      canvasColor: AppColors.canvasBackground,
      cardColor: AppColors.surfacePrimary,
      primaryColor: AppColors.textPrimary,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfacePrimary,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.textPrimary,
        secondary: AppColors.accentSecondary,
        surface: AppColors.surfacePrimary,
        onSurface: AppColors.textPrimary,
        error: Colors.redAccent,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayHeader,
        headlineMedium: AppTypography.screenHeading,
        titleMedium: AppTypography.cardTitle,
        bodyMedium: AppTypography.bodyText,
        bodySmall: AppTypography.captionText,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// AppThemeExtension on ThemeData allows querying custom colors/typography
/// directly using ThemeData.
extension AppThemeExtension on ThemeData {
  Color get canvasBackground => AppColors.canvasBackground;
  Color get surfacePrimary => AppColors.surfacePrimary;
  Color get surfaceSecondary => AppColors.surfaceSecondary;
  Color get borderMuted => AppColors.borderMuted;
  Color get accentPrimary => AppColors.accentPrimary;
  Color get accentSecondary => AppColors.accentSecondary;
  Color get textPrimary => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textMuted => AppColors.textMuted;

  LinearGradient get voltScanGradient => AppGradients.voltScanGradient;
  LinearGradient get ticketGradient => AppGradients.ticketGradient;

  TextStyle get displayHeader => AppTypography.displayHeader;
  TextStyle get screenHeading => AppTypography.screenHeading;
  TextStyle get cardTitle => AppTypography.cardTitle;
  TextStyle get bodyText => AppTypography.bodyText;
  TextStyle get captionText => AppTypography.captionText;
}

/// AppBuildContextExtension on BuildContext allows direct query of theme
/// parameters from BuildContext (e.g. context.accentPrimary).
extension AppBuildContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  Color get canvasBackground => theme.canvasBackground;
  Color get surfacePrimary => theme.surfacePrimary;
  Color get surfaceSecondary => theme.surfaceSecondary;
  Color get borderMuted => theme.borderMuted;
  Color get accentPrimary => theme.accentPrimary;
  Color get accentSecondary => theme.accentSecondary;
  Color get textPrimary => theme.textPrimary;
  Color get textSecondary => theme.textSecondary;
  Color get textMuted => theme.textMuted;

  LinearGradient get voltScanGradient => theme.voltScanGradient;
  LinearGradient get ticketGradient => theme.ticketGradient;

  TextStyle get displayHeader => theme.displayHeader;
  TextStyle get screenHeading => theme.screenHeading;
  TextStyle get cardTitle => theme.cardTitle;
  TextStyle get bodyText => theme.bodyText;
  TextStyle get captionText => theme.captionText;

  // Layout adjusters as context helpers for easy access
  double get marginStandard => AppDimensions.marginStandard;
  double get paddingInternal => AppDimensions.paddingInternal;
  double get radiusPremiumCard => AppDimensions.radiusPremiumCard;
  double get radiusComponent => AppDimensions.radiusComponent;
  double get radiusPill => AppDimensions.radiusPill;
}
