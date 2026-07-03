import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:connect/Providers/profile_provider.dart';

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

  static const Color accentPrimary =
      Color(0xFF0064E0); // Experimental Blue Accent
  static const Color accentSecondary =
      Color(0xFF0064E0); // Experimental Blue Accent

  static const Color felineColor10 = Color(0xFF000000);
  static const Color felineColor20 = Color(0xFF0A0A0C);
  static const Color felineColor30 =
      Color(0xFF00183D); // Experimental deep midnight blue background
}

/// AppGradients contains high-fidelity accent gradients instead of flat primary colors.
class AppGradients {
  AppGradients._();

  // static const LinearGradient felineBackgroundGradient = LinearGradient(
  //   colors: [
  //     AppColors.felineColor10,
  //     AppColors.felineColor20,
  //     AppColors.felineColor30,
  //   ],
  //   begin: Alignment.bottomLeft,
  //   end: Alignment.topRight,
  // );

  static const LinearGradient felineBackgroundGradient = LinearGradient(
    colors: [
      AppColors.felineColor10,
      AppColors.felineColor20,
      AppColors.felineColor30,
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

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
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.canvasBackground,
      cardColor: AppColors.surfacePrimary,
      primaryColor: AppColors.textPrimary,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfacePrimary,
      ),
      chipTheme: const ChipThemeData(
        checkmarkColor: Colors.white,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.textPrimary,
        secondary: AppColors.accentSecondary,
        surface: AppColors.surfacePrimary,
        onSurface: AppColors.textPrimary,
        error: Colors.redAccent,
      ),
      textTheme: const TextTheme().copyWith(
        displayLarge: AppTypography.displayHeader,
        headlineMedium: AppTypography.screenHeading,
        titleMedium: AppTypography.cardTitle,
        bodyMedium: AppTypography.bodyText,
        bodySmall: AppTypography.captionText,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SubtlePageTransitionsBuilder(),
          TargetPlatform.iOS: SubtlePageTransitionsBuilder(),
          TargetPlatform.macOS: SubtlePageTransitionsBuilder(),
          TargetPlatform.windows: SubtlePageTransitionsBuilder(),
        },
      ),
    );
  }
}

class SubtlePageTransitionsBuilder extends PageTransitionsBuilder {
  const SubtlePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Entrance: subtle slide from right (8% offset) and fade
    final primarySlide = Tween<Offset>(
      begin: const Offset(0.08, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final primaryFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ));

    // Exit (when pushing another page on top): subtle slide to the left (4% offset) and fade down
    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.04, 0.0),
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    ));

    final secondaryFade = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOut,
    ));

    return SlideTransition(
      position: primarySlide,
      child: FadeTransition(
        opacity: primaryFade,
        child: SlideTransition(
          position: secondarySlide,
          child: FadeTransition(
            opacity: secondaryFade,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// AppThemeExtension on ThemeData allows querying custom colors/typography
/// directly using ThemeData.
extension AppThemeExtension on ThemeData {
  Color get canvasBackground => Colors.transparent;
  Color get surfacePrimary => AppColors.surfacePrimary;
  Color get surfaceSecondary => AppColors.surfaceSecondary;
  Color get borderMuted => AppColors.borderMuted;
  Color get accentPrimary => AppColors.accentPrimary;
  Color get accentSecondary => AppColors.accentSecondary;
  Color get textPrimary => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textMuted => AppColors.textMuted;

  LinearGradient get felineBackgroundGradient =>
      AppGradients.felineBackgroundGradient;
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

  Color get canvasBackground => Colors.transparent;
  Color get surfacePrimary => theme.surfacePrimary;
  Color get surfaceSecondary => theme.surfaceSecondary;
  Color get borderMuted => theme.borderMuted;
  Color get accentPrimary => theme.accentPrimary;
  Color get accentSecondary => theme.accentSecondary;
  Color get textPrimary => theme.textPrimary;
  Color get textSecondary => theme.textSecondary;
  Color get textMuted => theme.textMuted;

  LinearGradient get felineBackgroundGradient => theme.felineBackgroundGradient;
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

  bool get disableTransparency => shouldDisableTransparency(this);
}

/// Helper to determine if glassmorphic transparency/blur should be disabled
/// due to system accessibility features (reduce transparency) or user preference.
bool shouldDisableTransparency(BuildContext context) {
  // 1. Check system accessibility setting (high contrast or accessible navigation)
  final mq = MediaQuery.maybeOf(context);
  final systemReduce =
      (mq?.highContrast ?? false) || (mq?.accessibleNavigation ?? false);
  if (systemReduce) return true;

  // 2. Check user's manual background blur setting in ProfileProvider
  try {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: true);
    return !profileProvider.blurBackground;
  } catch (_) {
    return false;
  }
}

/// A highly polished, HIG-compliant Glassmorphic container.
/// Automatically falls back to a solid background if transparency is disabled.
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? glassColor;
  final Color? fallbackColor;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.borderRadius,
    this.border,
    this.glassColor,
    this.fallbackColor,
    this.blurSigma = 15.0,
    this.padding,
    this.margin,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableTransparency = shouldDisableTransparency(context);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.zero;

    if (disableTransparency) {
      // High-contrast, solid fallback container
      return Container(
        height: height,
        width: width,
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          color: fallbackColor ?? context.surfacePrimary,
          borderRadius: borderRadius,
          border: border ??
              Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 1.0),
          boxShadow: boxShadow,
        ),
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    final effectiveGlassColor =
        glassColor ?? Colors.black.withValues(alpha: 0.4);
    final effectiveBorder = border ??
        Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        );

    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveGlassColor,
              borderRadius: borderRadius,
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A reusable flexible space background widget designed for AppBars
/// to render a frosted glass background beneath scrolling content.
class GlassmorphicFlexibleSpace extends StatelessWidget {
  const GlassmorphicFlexibleSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassmorphicContainer(
      borderRadius: BorderRadius.zero,
      border: Border(
        bottom: BorderSide(
          color: Colors.white10,
          width: 0.5,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

/// An Apple HIG-compliant frosted glass alert dialog.
/// Automatically falls back to a solid dialog if transparency is disabled.
class GlassmorphicAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;

  const GlassmorphicAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableTransparency = shouldDisableTransparency(context);

    if (disableTransparency) {
      // Opaque, high-contrast fallback alert dialog
      return AlertDialog(
        backgroundColor: context.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
          side: BorderSide(color: context.surfaceSecondary, width: 1.5),
        ),
        title: title,
        content: content,
        actions: actions,
        titlePadding: titlePadding,
        contentPadding: contentPadding,
        actionsPadding: actionsPadding,
      );
    }

    return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: GlassmorphicContainer(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  DefaultTextStyle(
                    style: context.screenHeading.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                    child: title!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (content != null) ...[
                  DefaultTextStyle(
                    style: context.bodyText.copyWith(
                      color: context.textSecondary,
                    ),
                    child: content!,
                  ),
                  const SizedBox(height: 24),
                ],
                if (actions != null)
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8.0,
                    overflowSpacing: 8.0,
                    overflowAlignment: OverflowBarAlignment.end,
                    children: actions!,
                  ),
              ],
            ),
          ),
        ));
  }
}

/// A highly polished, Apple HIG-compliant Glassmorphic button.
/// Automatically falls back to a solid background if transparency is disabled.
class GlassmorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? glassColor;
  final Color? fallbackColor;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassmorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.height,
    this.width,
    this.borderRadius,
    this.border,
    this.glassColor,
    this.fallbackColor,
    this.blurSigma = 15.0,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableTransparency = shouldDisableTransparency(context);
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(99.0); // Pill shape by default

    if (disableTransparency) {
      return Container(
        height: height,
        width: width,
        margin: margin,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: fallbackColor ?? context.surfaceSecondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: effectiveBorderRadius,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            padding: padding,
            elevation: 0,
          ),
          child: child,
        ),
      );
    }

    final effectiveGlassColor =
        glassColor ?? Colors.white.withValues(alpha: 0.08);
    final effectiveBorder = border ??
        Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        );

    return Container(
      height: height,
      width: width,
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: effectiveGlassColor,
              borderRadius: effectiveBorderRadius,
              border: effectiveBorder,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: effectiveBorderRadius,
                child: Padding(
                  padding: padding ??
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Center(
                    widthFactor: 1.0,
                    heightFactor: 1.0,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
