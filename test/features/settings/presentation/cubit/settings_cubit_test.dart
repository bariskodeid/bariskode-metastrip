import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';
import 'package:metastrip/features/settings/domain/usecases/clear_cache.dart';
import 'package:metastrip/features/settings/domain/usecases/export_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/get_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/import_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/reset_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/save_settings.dart';
import 'package:metastrip/features/settings/domain/validation/settings_validation.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_state.dart';

void main() {
  test('output folder update rolls back when processing-key write fails',
      () async {
    final defaults = SettingsEntity.defaults();
    final previous = defaults.copyWith(
      storage: defaults.storage.copyWith(outputFolderPath: '/old'),
    );
    final repository = _MemorySettingsRepository(previous);
    final storage = _FailingStorage('/old');
    final cubit = SettingsCubit(
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
    addTearDown(cubit.close);
    await cubit.load();
    storage.failNextSetString = true;

    await cubit.updateOutputFolder('/new');

    expect(cubit.state.status, SettingsStatus.error);
    expect(cubit.state.settings, previous);
    expect(cubit.state.errorMessage, 'Failed to save output folder');
    expect(repository.settings, previous);
    expect(storage.getString(AppConstants.keyOutputFolderPath), '/old');
    expect(repository.saved, [
      isA<SettingsEntity>().having(
        (settings) => settings.storage.outputFolderPath,
        'output folder',
        '/new',
      ),
      previous,
    ]);
  });

  test('concurrent output folder updates persist in invocation order',
      () async {
    final defaults = SettingsEntity.defaults();
    final previous = defaults.copyWith(
      storage: defaults.storage.copyWith(outputFolderPath: '/old'),
    );
    final firstSaveStarted = Completer<void>();
    final releaseFirstSave = Completer<void>();
    final repository = _MemorySettingsRepository(
      previous,
      firstSaveStarted: firstSaveStarted,
      releaseFirstSave: releaseFirstSave,
    );
    final storage = _FailingStorage('/old');
    final cubit = SettingsCubit(
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
    addTearDown(cubit.close);
    await cubit.load();
    repository.pauseNextSave = true;

    final first = cubit.updateOutputFolder('/first');
    await firstSaveStarted.future;
    final second = cubit.updateOutputFolder('/second');
    releaseFirstSave.complete();
    await Future.wait([first, second]);

    expect(cubit.state.settings?.storage.outputFolderPath, '/second');
    expect(repository.settings.storage.outputFolderPath, '/second');
    expect(storage.getString(AppConstants.keyOutputFolderPath), '/second');
  });

  test('overlapping mixed updates merge against the latest queued state',
      () async {
    final previous = SettingsEntity.defaults();
    final firstSaveStarted = Completer<void>();
    final releaseFirstSave = Completer<void>();
    final repository = _MemorySettingsRepository(
      previous,
      firstSaveStarted: firstSaveStarted,
      releaseFirstSave: releaseFirstSave,
    );
    final storage = _FailingStorage('/old');
    final cubit = SettingsCubit(
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
    addTearDown(cubit.close);
    await cubit.load();
    repository.pauseNextSave = true;

    final first = cubit.updateNamingTemplate('{name}_private');
    await firstSaveStarted.future;
    final second = cubit.updateKeepOriginal(false);
    releaseFirstSave.complete();
    await Future.wait([first, second]);

    expect(cubit.state.settings?.storage.namingTemplate, '{name}_private');
    expect(cubit.state.settings?.storage.keepOriginal, isFalse);
    expect(repository.settings.storage.namingTemplate, '{name}_private');
    expect(repository.settings.storage.keepOriginal, isFalse);
  });

  test('invalid direct updates do not reach persistence', () async {
    final previous = SettingsEntity.defaults();
    final repository = _MemorySettingsRepository(previous);
    final storage = _FailingStorage('/old');
    final cubit = SettingsCubit(
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
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.updateJpegQuality(69);
    await cubit.updateConcurrentFiles(9);
    await cubit.updateFolderStructure('invalid');
    await cubit.updateNamingTemplate('   ');
    await cubit.updateTheme('Unknown');
    await cubit.updateTheme('custom', customColors: const {});
    await cubit.updateTheme(
      'custom',
      customColors: const {'unknown': 0xFF000000},
    );

    expect(repository.saved, isEmpty);
    expect(cubit.state.settings, previous);
    expect(cubit.state.status, SettingsStatus.error);
  });

  test('reset is a terminal barrier for mutations already queued after it',
      () async {
    final previous = SettingsEntity.defaults();
    final firstSaveStarted = Completer<void>();
    final releaseFirstSave = Completer<void>();
    final repository = _MemorySettingsRepository(
      previous,
      firstSaveStarted: firstSaveStarted,
      releaseFirstSave: releaseFirstSave,
    )..pauseNextSave = true;
    final storage = _FailingStorage('/old');
    final cubit = _createCubit(repository, storage);
    addTearDown(cubit.close);
    await cubit.load();

    final first = cubit.updateNamingTemplate('{name}_before_reset');
    await firstSaveStarted.future;
    final reset = cubit.resetAllData();
    final mutationAfterReset = cubit.updateKeepOriginal(false);
    releaseFirstSave.complete();

    expect(await reset, isTrue);
    await mutationAfterReset;
    await first;

    expect(repository.settings, SettingsEntity.defaults());
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.storage.keepOriginal, isTrue);
  });

  test('failed reset re-enables mutations', () async {
    final repository = _FailingResetRepository();
    final storage = _FailingStorage('/old');
    final cubit = _createCubit(repository, storage);
    addTearDown(cubit.close);
    await cubit.load();

    expect(await cubit.resetAllData(), isFalse);
    await cubit.updateKeepOriginal(false);

    expect(repository.settings.storage.keepOriginal, isFalse);
  });

  test('successful reset re-enables and persists mutations', () async {
    final repository = _MemorySettingsRepository(SettingsEntity.defaults());
    final storage = _FailingStorage('/old');
    final cubit = _createCubit(repository, storage);
    addTearDown(cubit.close);
    await cubit.load();

    expect(await cubit.resetAllData(), isTrue);
    await cubit.updateKeepOriginal(false);

    expect(cubit.state.settings?.storage.keepOriginal, isFalse);
    expect(repository.settings.storage.keepOriginal, isFalse);
  });

  test('custom theme update persists a complete color map', () async {
    final repository = _MemorySettingsRepository(SettingsEntity.defaults());
    final storage = _FailingStorage('/old');
    final cubit = _createCubit(repository, storage);
    addTearDown(cubit.close);
    await cubit.load();

    final colors = {
      for (final key in settingsCustomColorKeys) key: 0xFF123456,
    };
    await cubit.updateTheme('custom', customColors: colors);

    expect(cubit.state.settings?.theme.customColors, colors);
  });

  test('preset theme update clears stale custom colors', () async {
    final colors = {
      for (final key in settingsCustomColorKeys) key: 0xFF123456,
    };
    final defaults = SettingsEntity.defaults();
    final repository = _MemorySettingsRepository(
      defaults.copyWith(
        theme: defaults.theme.copyWith(
          themeName: 'custom',
          customColors: colors,
        ),
      ),
    );
    final storage = _FailingStorage('/old');
    final cubit = _createCubit(repository, storage);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.updateTheme('Mercury');

    expect(cubit.state.settings?.theme.customColors, isNull);
    expect(repository.settings.theme.customColors, isNull);
  });
}

SettingsCubit _createCubit(
  SettingsRepository repository,
  KeyValueStorage storage,
) =>
    SettingsCubit(
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

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(
    this.settings, {
    this.firstSaveStarted,
    this.releaseFirstSave,
  });

  SettingsEntity settings;
  final saved = <SettingsEntity>[];
  final Completer<void>? firstSaveStarted;
  final Completer<void>? releaseFirstSave;
  bool pauseNextSave = false;

  @override
  Future<SettingsEntity> getSettings() async => settings;

  @override
  Future<void> resetAll() async {
    settings = SettingsEntity.defaults();
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    if (pauseNextSave) {
      pauseNextSave = false;
      firstSaveStarted?.complete();
      await releaseFirstSave?.future;
    }
    this.settings = settings;
    saved.add(settings);
  }
}

class _FailingResetRepository extends _MemorySettingsRepository {
  _FailingResetRepository() : super(SettingsEntity.defaults());

  @override
  Future<void> resetAll() => Future.error(StateError('reset failed'));
}

class _FailingStorage implements KeyValueStorage {
  _FailingStorage(String outputFolder)
      : _values = {AppConstants.keyOutputFolderPath: outputFolder};

  final Map<String, Object> _values;
  bool failNextSetString = false;

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> setBool(String key, {required bool value}) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, {required String value}) async {
    if (failNextSetString) {
      failNextSetString = false;
      throw const FileSystemException('write failed');
    }
    _values[key] = value;
  }
}
