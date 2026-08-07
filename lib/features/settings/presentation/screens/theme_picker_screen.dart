import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/theme/app_colors.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/core/theme/app_theme.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_state.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';

/// Screen for selecting color theme with live preview.
class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final currentTheme =
            state.settings?.theme.themeName ?? AppConstants.defaultTheme;
        final customColors = state.settings?.theme.customColors;

        return Scaffold(
          appBar: AppBar(title: const Text('COLOR THEME')),
          body: Column(
            children: [
              // Live preview area
              _ThemePreviewCard(
                themeName: currentTheme,
                customColors: customColors,
              ),

              // Theme list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    RadioGroup<String>(
                      groupValue: currentTheme,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<SettingsCubit>().updateTheme(value);
                        }
                      },
                      child: Column(
                        children: AppColorScheme.allThemes.entries
                            .map(
                              (entry) => RadioListTile<String>(
                                title: Text(entry.key),
                                value: entry.key,
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                dense: true,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const Divider(height: AppSpacing.lg),
                    // Custom theme builder
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Custom Theme'),
                      subtitle: const Text('Build your own color scheme'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showCustomThemeBuilder(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomThemeBuilder(BuildContext context) {
    final theme = context.read<SettingsCubit>().state.settings?.theme;
    final tempColors = resolveCustomThemeColors(
      theme?.themeName ?? AppConstants.defaultTheme,
      theme?.customColors,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Custom Theme Builder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...tempColors.entries.map((entry) {
                  return ListTile(
                    dense: true,
                    title: Text(entry.key),
                    trailing: GestureDetector(
                      onTap: () => _pickColor(
                          ctx, entry.key, entry.value, setState, tempColors),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: tempColors[entry.key] ?? entry.value,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Theme.of(ctx).dividerColor),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            PrimaryButton(
              label: 'SAVE',
              onPressed: () async {
                final colorsMap =
                    tempColors.map((k, v) => MapEntry(k, v.toARGB32()));
                final cubit = context.read<SettingsCubit>();
                await cubit.updateTheme('custom', customColors: colorsMap);
                final savedTheme = cubit.state.settings?.theme;
                if (ctx.mounted &&
                    cubit.state.status == SettingsStatus.loaded &&
                    savedTheme?.themeName == 'custom' &&
                    _mapsEqual(savedTheme?.customColors, colorsMap)) {
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickColor(
    BuildContext context,
    String key,
    Color currentColor,
    StateSetter setState,
    Map<String, Color> tempColors,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pick $key'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: tempColors[key] ?? currentColor,
            onColorChanged: (color) {
              setState(() {
                tempColors[key] = color;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }
}

/// Resolves every color displayed by the custom-theme editor.
Map<String, Color> resolveCustomThemeColors(
  String themeName,
  Map<String, int>? customColors,
) {
  final scheme = AppColorScheme.fromName(
    themeName,
    customColors: customColors,
  );
  return {
    'backgroundPrimary': scheme.backgroundPrimary,
    'backgroundSecondary': scheme.backgroundSecondary,
    'backgroundTertiary': scheme.backgroundTertiary,
    'border': scheme.border,
    'borderEmphasis': scheme.borderEmphasis,
    'textPrimary': scheme.textPrimary,
    'textSecondary': scheme.textSecondary,
    'textTertiary': scheme.textTertiary,
    'textInverse': scheme.textInverse,
    'accentPrimary': scheme.accentPrimary,
    'accentSecondary': scheme.accentSecondary,
    'accentSuccess': scheme.accentSuccess,
    'accentDanger': scheme.accentDanger,
    'accentInfo': scheme.accentInfo,
    'privacyWarning': scheme.privacyWarning,
    'overlay': scheme.overlay,
  };
}

bool _mapsEqual(Map<String, int>? first, Map<String, int> second) {
  if (first == null || first.length != second.length) return false;
  return first.entries.every((entry) => second[entry.key] == entry.value);
}

/// Preview card showing current theme colors.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.themeName,
    this.customColors,
  });

  final String themeName;
  final Map<String, int>? customColors;

  @override
  Widget build(BuildContext context) {
    AppColorScheme scheme;
    scheme = AppColorScheme.fromName(
      themeName,
      customColors: customColors,
    );

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Theme(
        data: AppTheme.build(scheme),
        child: Card(
          margin: const EdgeInsets.all(AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PREVIEW', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    ElevatedButton(
                        onPressed: () {}, child: const Text('PRIMARY')),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                        onPressed: () {}, child: const Text('SECONDARY')),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const TextField(
                  decoration: InputDecoration(hintText: 'Input field'),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: scheme.accentPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: scheme.accentSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: scheme.accentSuccess,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
