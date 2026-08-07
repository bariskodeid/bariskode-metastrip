/// Supported custom-theme color keys.
const settingsCustomColorKeys = {
  'backgroundPrimary',
  'backgroundSecondary',
  'backgroundTertiary',
  'border',
  'borderEmphasis',
  'textPrimary',
  'textSecondary',
  'textTertiary',
  'textInverse',
  'accentPrimary',
  'accentSecondary',
  'accentSuccess',
  'accentDanger',
  'accentInfo',
  'privacyWarning',
  'overlay',
};

/// Returns whether a theme selection is safe to persist.
bool isValidSettingsTheme(
  String themeName,
  Map<String, int>? customColors,
) {
  const themes = {
    'Dark Industrial',
    'Steel Blue',
    'Acid Green',
    'Rust',
    'Mercury',
    'Neon Orange',
    'Cobalt',
    'custom',
  };
  if (!themes.contains(themeName)) return false;
  if (themeName == 'custom' && (customColors == null || customColors.isEmpty)) {
    return false;
  }
  if (customColors == null) return true;
  return customColors.length <= settingsCustomColorKeys.length &&
      customColors.keys.every(settingsCustomColorKeys.contains) &&
      customColors.values.every(
        (value) => value >= 0 && value <= 0xFFFFFFFF,
      );
}
