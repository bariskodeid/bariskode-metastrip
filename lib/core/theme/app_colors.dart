import 'package:flutter/material.dart';

/// Color scheme for MetaStrip app
/// Based on Industrial Minimalism design language
class AppColorScheme {
  final Brightness brightness;

  // Backgrounds
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color backgroundTertiary;

  // Borders
  final Color border;
  final Color borderEmphasis;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;

  // Accents
  final Color accentPrimary;
  final Color accentSecondary;
  final Color accentSuccess;
  final Color accentDanger;
  final Color accentInfo;

  // Special
  final Color privacyWarning;
  final Color overlay;

  const AppColorScheme({
    required this.brightness,
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.backgroundTertiary,
    required this.border,
    required this.borderEmphasis,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.accentSuccess,
    required this.accentDanger,
    required this.accentInfo,
    required this.privacyWarning,
    required this.overlay,
  });

  /// Dark Industrial (Default Theme)
  static const darkIndustrial = AppColorScheme(
    brightness: Brightness.dark,
    backgroundPrimary: Color(0xFF0D0D0D),
    backgroundSecondary: Color(0xFF1A1A1A),
    backgroundTertiary: Color(0xFF242424),
    border: Color(0xFF2E2E2E),
    borderEmphasis: Color(0xFF404040),
    textPrimary: Color(0xFFE8E0D0),
    textSecondary: Color(0xFF9A9080),
    textTertiary: Color(0xFF5A5248),
    textInverse: Color(0xFF0D0D0D),
    accentPrimary: Color(0xFFC94B1A),
    accentSecondary: Color(0xFFE8A040),
    accentSuccess: Color(0xFF4A8C5A),
    accentDanger: Color(0xFF8C2A2A),
    accentInfo: Color(0xFF2A5A8C),
    privacyWarning: Color(0xFFC94B1A),
    overlay: Color(0xCC0D0D0D),
  );

  /// Steel Blue Theme
  static const steelBlue = AppColorScheme(
    brightness: Brightness.dark,
    backgroundPrimary: Color(0xFF0A1628),
    backgroundSecondary: Color(0xFF112038),
    backgroundTertiary: Color(0xFF1A2E4A),
    border: Color(0xFF243850),
    borderEmphasis: Color(0xFF304860),
    textPrimary: Color(0xFFE0E8F0),
    textSecondary: Color(0xFF8090A8),
    textTertiary: Color(0xFF506070),
    textInverse: Color(0xFF0A1628),
    accentPrimary: Color(0xFF2E7DD1),
    accentSecondary: Color(0xFF5BB8E8),
    accentSuccess: Color(0xFF3A9C6A),
    accentDanger: Color(0xFFC03030),
    accentInfo: Color(0xFF4A9DD1),
    privacyWarning: Color(0xFF2E7DD1),
    overlay: Color(0xCC0A1628),
  );

  /// Acid Green Theme
  static const acidGreen = AppColorScheme(
    brightness: Brightness.dark,
    backgroundPrimary: Color(0xFF0F1A0F),
    backgroundSecondary: Color(0xFF162416),
    backgroundTertiary: Color(0xFF1E2E1E),
    border: Color(0xFF243824),
    borderEmphasis: Color(0xFF304830),
    textPrimary: Color(0xFFD0E8D0),
    textSecondary: Color(0xFF70A070),
    textTertiary: Color(0xFF507050),
    textInverse: Color(0xFF0F1A0F),
    accentPrimary: Color(0xFF39D353),
    accentSecondary: Color(0xFFA0D8A0),
    accentSuccess: Color(0xFF4AE864),
    accentDanger: Color(0xFFD04040),
    accentInfo: Color(0xFF3AA35A),
    privacyWarning: Color(0xFF39D353),
    overlay: Color(0xCC0F1A0F),
  );

  /// Rust Theme
  static const rust = AppColorScheme(
    brightness: Brightness.dark,
    backgroundPrimary: Color(0xFF1A0D00),
    backgroundSecondary: Color(0xFF241200),
    backgroundTertiary: Color(0xFF2E1A00),
    border: Color(0xFF382400),
    borderEmphasis: Color(0xFF483000),
    textPrimary: Color(0xFFF0E0C8),
    textSecondary: Color(0xFFA08060),
    textTertiary: Color(0xFF706040),
    textInverse: Color(0xFF1A0D00),
    accentPrimary: Color(0xFFD4521A),
    accentSecondary: Color(0xFFE8A040),
    accentSuccess: Color(0xFF6A9C4A),
    accentDanger: Color(0xFFCC3030),
    accentInfo: Color(0xFF8A6A3A),
    privacyWarning: Color(0xFFD4521A),
    overlay: Color(0xCC1A0D00),
  );

  /// Mercury (Light Mode)
  static const mercury = AppColorScheme(
    brightness: Brightness.light,
    backgroundPrimary: Color(0xFFF0EFEC),
    backgroundSecondary: Color(0xFFFFFFFF),
    backgroundTertiary: Color(0xFFE8E6E0),
    border: Color(0xFFC8C4BC),
    borderEmphasis: Color(0xFFA8A49C),
    textPrimary: Color(0xFF1A1816),
    textSecondary: Color(0xFF6A6560),
    textTertiary: Color(0xFF9A9590),
    textInverse: Color(0xFFF0EFEC),
    accentPrimary: Color(0xFF8C2E00),
    accentSecondary: Color(0xFFC4600A),
    accentSuccess: Color(0xFF2A6A3A),
    accentDanger: Color(0xFF8C1A1A),
    accentInfo: Color(0xFF3A5A7C),
    privacyWarning: Color(0xFF8C2E00),
    overlay: Color(0xCC1A1816),
  );

  /// Neon Orange Theme
  static const neonOrange = AppColorScheme(
    brightness: Brightness.dark,
    backgroundPrimary: Color(0xFF0D0800),
    backgroundSecondary: Color(0xFF1A1200),
    backgroundTertiary: Color(0xFF261C00),
    border: Color(0xFF382800),
    borderEmphasis: Color(0xFF483400),
    textPrimary: Color(0xFFF0E8D0),
    textSecondary: Color(0xFFA08040),
    textTertiary: Color(0xFF706030),
    textInverse: Color(0xFF0D0800),
    accentPrimary: Color(0xFFFF6B00),
    accentSecondary: Color(0xFFFFB040),
    accentSuccess: Color(0xFF5A9C3A),
    accentDanger: Color(0xFFCC2020),
    accentInfo: Color(0xFF8A7A3A),
    privacyWarning: Color(0xFFFF6B00),
    overlay: Color(0xCC0D0800),
  );

  /// Cobalt Theme
  static const cobalt = AppColorScheme(
    brightness: Brightness.dark,
    backgroundPrimary: Color(0xFF000D1A),
    backgroundSecondary: Color(0xFF001224),
    backgroundTertiary: Color(0xFF001A2E),
    border: Color(0xFF002438),
    borderEmphasis: Color(0xFF003048),
    textPrimary: Color(0xFFD0E0F0),
    textSecondary: Color(0xFF7090B0),
    textTertiary: Color(0xFF506080),
    textInverse: Color(0xFF000D1A),
    accentPrimary: Color(0xFF0055D4),
    accentSecondary: Color(0xFF4088E8),
    accentSuccess: Color(0xFF3A8C6A),
    accentDanger: Color(0xFFC03030),
    accentInfo: Color(0xFF2A6AA4),
    privacyWarning: Color(0xFF0055D4),
    overlay: Color(0xCC000D1A),
  );

  /// Gets a preset or custom theme by name.
  static AppColorScheme fromName(
    String name, {
    Map<String, int>? customColors,
  }) {
    final normalizedName = name.toLowerCase().replaceAll(' ', '_');
    if (normalizedName == 'custom' && customColors != null) {
      return _customFrom(customColors);
    }

    switch (normalizedName) {
      case 'dark_industrial':
      case 'darkindustrial':
        return darkIndustrial;
      case 'steel_blue':
      case 'steelblue':
        return steelBlue;
      case 'acid_green':
      case 'acidgreen':
        return acidGreen;
      case 'rust':
        return rust;
      case 'mercury':
        return mercury;
      case 'neon_orange':
      case 'neonorange':
        return neonOrange;
      case 'cobalt':
        return cobalt;
      default:
        return darkIndustrial;
    }
  }

  static AppColorScheme _customFrom(Map<String, int> colors) {
    Color get(String key, Color fallback) {
      final value = colors[key];
      return value == null ? fallback : Color(value);
    }

    const base = darkIndustrial;
    return AppColorScheme(
      brightness: base.brightness,
      backgroundPrimary: get('backgroundPrimary', base.backgroundPrimary),
      backgroundSecondary: get('backgroundSecondary', base.backgroundSecondary),
      backgroundTertiary: get('backgroundTertiary', base.backgroundTertiary),
      border: get('border', base.border),
      borderEmphasis: get('borderEmphasis', base.borderEmphasis),
      textPrimary: get('textPrimary', base.textPrimary),
      textSecondary: get('textSecondary', base.textSecondary),
      textTertiary: get('textTertiary', base.textTertiary),
      textInverse: get('textInverse', base.textInverse),
      accentPrimary: get('accentPrimary', base.accentPrimary),
      accentSecondary: get('accentSecondary', base.accentSecondary),
      accentSuccess: get('accentSuccess', base.accentSuccess),
      accentDanger: get('accentDanger', base.accentDanger),
      accentInfo: get('accentInfo', base.accentInfo),
      privacyWarning: get('privacyWarning', base.privacyWarning),
      overlay: get('overlay', base.overlay),
    );
  }

  /// Get all available themes
  static Map<String, AppColorScheme> get allThemes => {
        'Dark Industrial': darkIndustrial,
        'Steel Blue': steelBlue,
        'Acid Green': acidGreen,
        'Rust': rust,
        'Mercury': mercury,
        'Neon Orange': neonOrange,
        'Cobalt': cobalt,
      };
}
