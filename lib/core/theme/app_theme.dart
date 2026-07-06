import 'package:flutter/material.dart';
import 'package:metastrip/core/theme/app_colors.dart';
import 'package:metastrip/core/theme/app_typography.dart';

/// Build ThemeData from AppColorScheme
class AppTheme {
  AppTheme._();

  static ThemeData build(AppColorScheme colors) {
    return ThemeData(
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.backgroundPrimary,
      fontFamily: AppTypography.ibmPlexMono,
      useMaterial3: true,

      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.accentPrimary,
        onPrimary: colors.textInverse,
        secondary: colors.accentSecondary,
        onSecondary: colors.textInverse,
        error: colors.accentDanger,
        onError: colors.textPrimary,
        surface: colors.backgroundSecondary,
        onSurface: colors.textPrimary,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colors.backgroundPrimary,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.h2(colors.textPrimary),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 24),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.backgroundSecondary,
        selectedItemColor: colors.accentPrimary,
        unselectedItemColor: colors.textTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.overline(colors.accentPrimary),
        unselectedLabelStyle: AppTypography.overline(colors.textTertiary),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: colors.backgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // Elevated Button Theme (Primary Button)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accentPrimary,
          foregroundColor: colors.textInverse,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: AppTypography.button(colors.textInverse),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // Outlined Button Theme (Secondary Button)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: colors.borderEmphasis, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: AppTypography.button(colors.textPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textSecondary,
          textStyle: AppTypography.button(colors.textSecondary),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colors.accentPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colors.accentDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colors.accentDanger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.body(colors.textTertiary),
        labelStyle: AppTypography.caption(colors.textSecondary),
        errorStyle: AppTypography.caption(colors.accentDanger),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: colors.textPrimary,
        size: 24,
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accentPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colors.textInverse),
        side: BorderSide(color: colors.borderEmphasis, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accentPrimary;
          }
          return colors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accentPrimary.withValues(alpha: 0.4);
          }
          return colors.border;
        }),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentPrimary,
        linearTrackColor: colors.border,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.textPrimary,
        contentTextStyle: AppTypography.body(colors.backgroundPrimary),
        actionTextColor: colors.accentPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colors.backgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colors.border, width: 1),
        ),
        titleTextStyle: AppTypography.h2(colors.textPrimary),
        contentTextStyle: AppTypography.body(colors.textSecondary),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.backgroundSecondary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.display(colors.textPrimary),
        headlineLarge: AppTypography.h1(colors.textPrimary),
        headlineMedium: AppTypography.h2(colors.textPrimary),
        headlineSmall: AppTypography.h3(colors.textPrimary),
        bodyLarge: AppTypography.body(colors.textPrimary),
        bodyMedium: AppTypography.body(colors.textPrimary),
        bodySmall: AppTypography.caption(colors.textSecondary),
        labelLarge: AppTypography.button(colors.textPrimary),
        labelMedium: AppTypography.caption(colors.textSecondary),
        labelSmall: AppTypography.overline(colors.textTertiary),
      ),
    );
  }
}
