import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/app/app.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/shared_preferences_storage.dart';
import 'package:metastrip/core/storage/stored_output_folder_repository.dart';
import 'package:metastrip/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:metastrip/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:metastrip/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';
import 'package:metastrip/features/settings/domain/usecases/clear_cache.dart';
import 'package:metastrip/features/settings/domain/usecases/export_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/get_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/import_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/reset_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/save_settings.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MetaStrip app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
      AppConstants.keyOutputFolderPath: '/output',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    final settingsDataSource = SettingsLocalDataSourceImpl(storage);
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(settingsRepository),
      saveSettings: SaveSettings(settingsRepository),
      resetSettings: ResetSettings(settingsRepository),
      exportSettings: ExportSettings(settingsRepository),
      importSettings: ImportSettings(
        settingsRepository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
          outputFolderValidator: (path) async => path,
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('METASTRIP VIEWER'), findsOneWidget);
    expect(find.text('NO FILES LOADED'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'ADD FILES'), findsOneWidget);
  });

  testWidgets('settings route receives the app-level SettingsCubit',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
      AppConstants.keyOutputFolderPath: '/output',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final settingsDataSource = SettingsLocalDataSourceImpl(storage);
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(settingsRepository),
      saveSettings: SaveSettings(settingsRepository),
      resetSettings: ResetSettings(settingsRepository),
      exportSettings: ExportSettings(settingsRepository),
      importSettings: ImportSettings(
        settingsRepository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    final dependencies = AppDependencies(
      onboardingRepository: SharedPreferencesOnboardingRepository(storage),
      outputFolderRepository: StoredOutputFolderRepository(storage),
      removerRepository: RemoverRepositoryImpl(),
      outputFolderValidator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: dependencies,
        settingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SETTINGS'), findsOneWidget);
    final settingsContext = tester.element(find.text('SETTINGS'));
    expect(settingsContext.read<SettingsCubit>(), same(settingsCubit));
    expect(find.text('Filename Template'), findsNothing);
    expect(find.text('Keep original files'), findsNothing);
    expect(find.text('PROCESSING'), findsNothing);
    expect(find.text('JPEG Quality'), findsNothing);
    expect(find.text('Concurrent Files'), findsNothing);
    expect(find.text('Auto-confirm'), findsNothing);
  });

  testWidgets('saved settings hydrate output folder and apply theme',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
      AppConstants.keyOutputFolderPath: '/output',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final settingsDataSource = SettingsLocalDataSourceImpl(storage);
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(settingsRepository),
      saveSettings: SaveSettings(settingsRepository),
      resetSettings: ResetSettings(settingsRepository),
      exportSettings: ExportSettings(settingsRepository),
      importSettings: ImportSettings(
        settingsRepository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
          outputFolderValidator: (path) async => path,
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();

    expect(settingsCubit.state.settings?.storage.outputFolderPath, '/output');
    await settingsCubit.updateTheme('Mercury');
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.brightness, Brightness.light);
  });

  testWidgets('reset returns the app to onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
      AppConstants.keyOutputFolderPath: '/output',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final settingsDataSource = SettingsLocalDataSourceImpl(storage);
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(settingsRepository),
      saveSettings: SaveSettings(settingsRepository),
      resetSettings: ResetSettings(settingsRepository),
      exportSettings: ExportSettings(settingsRepository),
      importSettings: ImportSettings(
        settingsRepository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
          outputFolderValidator: (path) async => path,
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reset all data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Reset all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset all data'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('User-created clean copies and output files are not'),
      findsOneWidget,
    );
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Clean copies and output files will remain'),
      findsOneWidget,
    );
    await tester.tap(find.text('RESET EVERYTHING'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('SETTINGS'), findsNothing);
    final onboardingCubit =
        tester.element(find.byType(OnboardingScreen)).read<OnboardingCubit>();
    expect(onboardingCubit.state.outputFolderPath, isNull);

    await onboardingCubit.setOutputFolder('/new-output');
    await tester.pump();
    expect(
      settingsCubit.state.settings?.storage.outputFolderPath,
      '/new-output',
    );
    await onboardingCubit.requestPermissions();
    await onboardingCubit.complete();
    await tester.pumpAndSettle();

    expect(find.text('METASTRIP VIEWER'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await settingsCubit.updateTheme('Mercury');
    expect((await settingsRepository.getSettings()).theme.themeName, 'Mercury');
  });

  testWidgets('onboarding output folder clear synchronizes settings state',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
      AppConstants.keyOutputFolderPath: '/output',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final settingsDataSource = SettingsLocalDataSourceImpl(storage);
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(settingsRepository),
      saveSettings: SaveSettings(settingsRepository),
      resetSettings: ResetSettings(settingsRepository),
      exportSettings: ExportSettings(settingsRepository),
      importSettings: ImportSettings(
        settingsRepository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
          outputFolderValidator: (path) async => path,
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();
    expect(settingsCubit.state.settings?.storage.outputFolderPath, '/output');

    await storage.remove(AppConstants.keyOutputFolderPath);
    final context = tester.element(find.text('METASTRIP VIEWER'));
    await context.read<OnboardingCubit>().load();
    await tester.pumpAndSettle();

    expect(settingsCubit.state.settings?.storage.outputFolderPath, isNull);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('failed reset remains on settings', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
      AppConstants.keyOutputFolderPath: '/output',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final repository = _FailingResetSettingsRepository();
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(repository),
      saveSettings: SaveSettings(repository),
      resetSettings: ResetSettings(repository),
      exportSettings: ExportSettings(repository),
      importSettings: ImportSettings(
        repository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
          outputFolderValidator: (path) async => path,
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reset all data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Reset all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET EVERYTHING'));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Failed to reset'), findsOneWidget);
  });

  testWidgets('first run renders onboarding after loading', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    final settingsDataSource = SettingsLocalDataSourceImpl(storage);
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(settingsRepository),
      saveSettings: SaveSettings(settingsRepository),
      resetSettings: ResetSettings(settingsRepository),
      exportSettings: ExportSettings(settingsRepository),
      importSettings: ImportSettings(
        settingsRepository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
        ),
        settingsCubit: settingsCubit,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('storage failure renders retry action instead of onboarding',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    final settingsDataSource = SettingsLocalDataSourceImpl(storage);
    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final settingsCubit = SettingsCubit(
      getSettings: GetSettings(settingsRepository),
      saveSettings: SaveSettings(settingsRepository),
      resetSettings: ResetSettings(settingsRepository),
      exportSettings: ExportSettings(settingsRepository),
      importSettings: ImportSettings(
        settingsRepository,
        storage: storage,
        validator: (path) async => path,
      ),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: _FailingOnboardingRepository(),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
        ),
        settingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOCAL STORAGE UNAVAILABLE'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
  });
}

class _FailingOnboardingRepository implements OnboardingRepository {
  @override
  Future<void> completeOnboarding() async {}

  @override
  Future<String?> getOutputFolderPath() => Future.error(StateError('failed'));

  @override
  Future<bool> isOnboardingCompleted() => Future.error(StateError('failed'));

  @override
  Future<void> resetOnboarding() async {}

  @override
  Future<void> saveOutputFolderPath(String path) async {}
}

class _FailingResetSettingsRepository implements SettingsRepository {
  SettingsEntity settings = SettingsEntity.defaults().copyWith(
    storage: SettingsEntity.defaults().storage.copyWith(
          outputFolderPath: '/output',
        ),
  );

  @override
  Future<SettingsEntity> getSettings() async => settings;

  @override
  Future<void> resetAll() => Future.error(StateError('failed'));

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    this.settings = settings;
  }
}
