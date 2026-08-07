import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_state.dart';
import 'package:metastrip/features/settings/presentation/screens/about_screen.dart';
import 'package:metastrip/features/settings/presentation/screens/licenses_screen.dart';
import 'package:metastrip/features/settings/presentation/screens/theme_picker_screen.dart';
import 'package:metastrip/features/settings/presentation/widgets/cache_size_widget.dart';
import 'package:metastrip/features/settings/presentation/widgets/export_import_dialog.dart';
import 'package:metastrip/features/settings/presentation/widgets/output_folder_picker_widget.dart';
import 'package:metastrip/features/settings/presentation/widgets/reset_data_dialog.dart';
import 'package:metastrip/features/settings/presentation/widgets/settings_section.dart';
import 'package:metastrip/features/settings/presentation/widgets/theme_selector_widget.dart';
import 'package:metastrip/features/settings/presentation/widgets/version_info_tile.dart';

/// Settings screen entry point (Cubit provided by app.dart).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsView();
  }
}

/// Internal view that consumes SettingsCubit.
class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            duration:
                const Duration(milliseconds: AppConstants.snackbarDurationMs),
          ),
        );
      },
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        final s = state.settings;

        if (s == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('SETTINGS')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('SETTINGS')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Appearance Section
              SettingsSection(
                title: 'APPEARANCE',
                children: [
                  ThemeSelectorWidget(
                    currentTheme: s.theme.themeName,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ThemePickerScreen()),
                    ),
                  ),
                ],
              ),

              // Output Section
              SettingsSection(
                title: 'OUTPUT',
                children: [
                  OutputFolderPickerWidget(
                    currentPath: s.storage.outputFolderPath ?? '',
                    onPick: () async {
                      final folder = await getDirectoryPath();
                      if (folder != null) {
                        await cubit.updateOutputFolder(folder);
                      }
                    },
                  ),
                ],
              ),

              // Maintenance Section
              SettingsSection(
                title: 'MAINTENANCE',
                children: [
                  CacheSizeWidget(
                    sizeBytes: state.cacheSizeBytes,
                    onClear: cubit.clearCache,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Export settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => ExportImportDialog(
                        onExport: (path) => cubit.exportSettings(path),
                        onImport: (file) => cubit.importSettings(file),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Reset all data',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => ResetDataDialog(
                        onConfirm: () async {
                          final success = await cubit.resetAllData();
                          if (success && context.mounted) {
                            await context.read<OnboardingCubit>().load();
                            if (!context.mounted) return;
                            Navigator.of(context).popUntil(
                              (route) => route.isFirst,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // About Section
              SettingsSection(
                title: 'ABOUT',
                children: [
                  const VersionInfoTile(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('About MetaStrip'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('Licenses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LicensesScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
