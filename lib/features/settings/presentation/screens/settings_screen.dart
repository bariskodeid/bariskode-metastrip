import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/output_folder_picker.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_state.dart';
import 'package:metastrip/features/settings/presentation/screens/about_screen.dart';
import 'package:metastrip/features/settings/presentation/screens/licenses_screen.dart';
import 'package:metastrip/features/settings/presentation/screens/theme_picker_screen.dart';
import 'package:metastrip/features/settings/presentation/widgets/cache_size_widget.dart';
import 'package:metastrip/features/settings/presentation/widgets/concurrent_files_slider.dart';
import 'package:metastrip/features/settings/presentation/widgets/export_import_dialog.dart';
import 'package:metastrip/features/settings/presentation/widgets/folder_structure_selector.dart';
import 'package:metastrip/features/settings/presentation/widgets/jpeg_quality_slider.dart';
import 'package:metastrip/features/settings/presentation/widgets/naming_template_field.dart';
import 'package:metastrip/features/settings/presentation/widgets/output_folder_picker_widget.dart';
import 'package:metastrip/features/settings/presentation/widgets/reset_data_dialog.dart';
import 'package:metastrip/features/settings/presentation/widgets/settings_section.dart';
import 'package:metastrip/features/settings/presentation/widgets/theme_selector_widget.dart';
import 'package:metastrip/features/settings/presentation/widgets/toggle_setting_tile.dart';
import 'package:metastrip/features/settings/presentation/widgets/version_info_tile.dart';

/// Settings screen entry point (Cubit provided by app.dart).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.directoryPicker = pickOutputFolder});

  /// Folder picker; injectable for tests.
  final DirectoryPicker directoryPicker;

  @override
  Widget build(BuildContext context) {
    return _SettingsView(directoryPicker: directoryPicker);
  }
}

/// Internal view that consumes SettingsCubit.
class _SettingsView extends StatelessWidget {
  const _SettingsView({required this.directoryPicker});

  final DirectoryPicker directoryPicker;

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
                      final messenger = ScaffoldMessenger.of(context);
                      var failed = false;
                      String? folder;
                      try {
                        folder = await directoryPicker(
                          onError: (_) => failed = true,
                        );
                      } catch (_) {
                        failed = true;
                      }
                      if (failed) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Folder selection failed'),
                          ),
                        );
                      } else if (folder != null && folder.trim().isNotEmpty) {
                        await cubit.updateOutputFolder(folder);
                      }
                    },
                  ),
                  NamingTemplateField(
                    initialValue: s.storage.namingTemplate,
                    onChanged: cubit.updateNamingTemplate,
                    enabled: false,
                  ),
                  FolderStructureSelector(
                    currentValue: s.storage.folderStructure,
                    onChanged: cubit.updateFolderStructure,
                    enabled: false,
                  ),
                  const ToggleSettingTile(
                    title: 'Keep originals',
                    subtitle: 'MetaStrip always creates a clean copy and never '
                        'deletes the original.',
                    value: true,
                    onChanged: null,
                  ),
                ],
              ),

              SettingsSection(
                title: 'PROCESSING',
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'These preferences are saved for future processing '
                      'modes. The current remover does not re-encode JPEGs '
                      'and processes files sequentially.',
                    ),
                  ),
                  JpegQualitySlider(
                    value: s.processing.jpegQuality,
                    onChanged: cubit.updateJpegQuality,
                  ),
                  ConcurrentFilesSlider(
                    value: s.processing.concurrentFiles,
                    onChanged: cubit.updateConcurrentFiles,
                  ),
                  ToggleSettingTile(
                    title: 'Auto-confirm',
                    subtitle: 'Saved for a future confirmation workflow.',
                    value: s.processing.autoConfirm,
                    onChanged: cubit.updateAutoConfirm,
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
                        outputFolder: s.storage.outputFolderPath,
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
