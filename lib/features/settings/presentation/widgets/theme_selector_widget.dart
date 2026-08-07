import 'package:flutter/material.dart';
import 'package:metastrip/core/theme/app_colors.dart';

/// Displays current theme with navigate action to ThemePickerScreen.
class ThemeSelectorWidget extends StatelessWidget {
  const ThemeSelectorWidget({
    super.key,
    required this.currentTheme,
    required this.onTap,
  });

  final String currentTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColorScheme.fromName(currentTheme);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.accentPrimary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: const Text('Color Theme'),
      subtitle: Text(currentTheme),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
