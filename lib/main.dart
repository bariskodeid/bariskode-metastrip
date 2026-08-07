import 'package:flutter/material.dart';
import 'package:metastrip/app/app.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';
import 'package:metastrip/core/storage/shared_preferences_storage.dart';
import 'package:metastrip/core/storage/stored_output_folder_repository.dart';
import 'package:metastrip/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:metastrip/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:metastrip/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:metastrip/features/settings/domain/usecases/clear_cache.dart';
import 'package:metastrip/features/settings/domain/usecases/export_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/get_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/import_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/reset_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/save_settings.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
}

Future<void> _bootstrap() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    // Data sources
    final settingsDataSource = SettingsLocalDataSourceImpl(storage);

    // Repositories
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);

    // Use cases
    final getSettings = GetSettings(settingsRepository);
    final saveSettings = SaveSettings(settingsRepository);
    final resetSettings = ResetSettings(settingsRepository);
    final exportSettings = ExportSettings(settingsRepository);
    final importSettings = ImportSettings(
      settingsRepository,
      storage: storage,
      validator: validateOutputFolder,
    );
    final clearCache = ClearCache(storage);

    // SettingsCubit provided at app level
    final settingsCubit = SettingsCubit(
      getSettings: getSettings,
      saveSettings: saveSettings,
      resetSettings: resetSettings,
      exportSettings: exportSettings,
      importSettings: importSettings,
      clearCache: clearCache,
      storage: storage,
      validator: validateOutputFolder,
    );

    runApp(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
          outputFolderValidator: validateOutputFolder,
        ),
        settingsCubit: settingsCubit,
      ),
    );
  } catch (_) {
    runApp(const _BootstrapFailureApp(onRetry: _bootstrap));
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('LOCAL STORAGE UNAVAILABLE'),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: onRetry, child: const Text('TRY AGAIN')),
            ],
          ),
        ),
      ),
    );
  }
}
