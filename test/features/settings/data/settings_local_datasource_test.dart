import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/core/storage/shared_preferences_storage.dart';
import 'package:metastrip/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:metastrip/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';
import 'package:metastrip/features/settings/domain/usecases/export_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/import_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('corrupt settings preserve the onboarding output folder', () async {
    SharedPreferences.setMockInitialValues({
      'app_settings_v1': '{not-json',
      AppConstants.keyOutputFolderPath: '/legacy-output',
    });
    final preferences = await SharedPreferences.getInstance();
    final dataSource = SettingsLocalDataSourceImpl(
      SharedPreferencesStorage(preferences),
    );

    final settings = await dataSource.getSettings();

    expect(settings.storage.outputFolderPath, '/legacy-output');
  });

  test('saved settings persist as JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dataSource = SettingsLocalDataSourceImpl(
      SharedPreferencesStorage(preferences),
    );

    await dataSource.saveSettings(
      SettingsLocalDataSourceTestData.settingsWithFolder('/output'),
    );

    final encoded = preferences.getString('app_settings_v1');
    expect(encoded, isNotNull);
    expect(json.decode(encoded!)['storage']['outputFolderPath'], '/output');
  });

  test('import validates and synchronizes the processing output folder',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOutputFolderPath: '/active',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final repository = SettingsRepositoryImpl(
      SettingsLocalDataSourceImpl(storage),
    );
    final directory = await Directory.systemTemp.createTemp('settings-import-');
    addTearDown(() => directory.delete(recursive: true));
    final importFile = File('${directory.path}/settings.json');
    await importFile.writeAsString(
      json.encode(
        SettingsLocalDataSourceTestData.settingsWithFolder('/imported')
            .toJson(),
      ),
    );
    String? validatedPath;
    final useCase = ImportSettings(
      repository,
      storage: storage,
      validator: (path) async {
        validatedPath = path;
        return path;
      },
    );

    final imported = await useCase(importFile);

    expect(imported.storage.outputFolderPath, '/active');
    expect(validatedPath, '/active');
    expect(
      preferences.getString(AppConstants.keyOutputFolderPath),
      '/active',
    );
  });

  final invalidImports = <String, SettingsEntity>{
    'JPEG quality below minimum': _settingsWith(jpegQuality: 69),
    'JPEG quality above maximum': _settingsWith(jpegQuality: 101),
    'concurrency below minimum': _settingsWith(concurrentFiles: 0),
    'concurrency above maximum': _settingsWith(concurrentFiles: 9),
    'unknown folder structure': _settingsWith(folderStructure: 'unknown'),
    'blank naming template': _settingsWith(namingTemplate: '   '),
    'unknown theme': _settingsWith(themeName: 'Unknown'),
    'custom theme without colors': _settingsWith(themeName: 'custom'),
  };
  for (final entry in invalidImports.entries) {
    test('import rejects ${entry.key} without persisting it', () async {
      final previous = SettingsLocalDataSourceTestData.settingsWithFolder(
        '/existing',
      );
      final repository = _MemorySettingsRepository(previous);
      final storage = _MemoryStorage({
        AppConstants.keyOutputFolderPath: '/existing',
      });
      final importFile = await _writeImportFile(entry.value);
      var validatorCalled = false;
      final useCase = ImportSettings(
        repository,
        storage: storage,
        validator: (path) async {
          validatorCalled = true;
          return path;
        },
      );

      await expectLater(useCase(importFile), throwsFormatException);
      expect(repository.settings, previous);
      expect(repository.savedSettings, isEmpty);
      expect(validatorCalled, isFalse);
      expect(
        storage.getString(AppConstants.keyOutputFolderPath),
        '/existing',
      );
    });
  }

  test('import rolls back settings when output folder persistence fails',
      () async {
    final previous = SettingsLocalDataSourceTestData.settingsWithFolder(
      '/settings-old',
    );
    final repository = _MemorySettingsRepository(previous);
    final storage = _MemoryStorage(
      {AppConstants.keyOutputFolderPath: '/processing-old'},
      failNextSetString: true,
    );
    final imported = SettingsLocalDataSourceTestData.settingsWithFolder(
      '/imported',
    );
    final importFile = await _writeImportFile(imported);
    final useCase = ImportSettings(
      repository,
      storage: storage,
      validator: (path) async => path,
    );

    await expectLater(useCase(importFile), throwsStateError);

    expect(repository.settings, previous);
    final resolvedImport = imported.copyWith(
      storage: imported.storage.copyWith(
        outputFolderPath: '/processing-old',
      ),
    );
    expect(repository.savedSettings, [resolvedImport, previous]);
    expect(
      storage.getString(AppConstants.keyOutputFolderPath),
      '/processing-old',
    );
  });

  test('blank imported folder preserves the current processing folder',
      () async {
    final staleSettings =
        SettingsLocalDataSourceTestData.settingsWithFolder('/stale');
    SharedPreferences.setMockInitialValues({
      'app_settings_v1': json.encode(staleSettings.toJson()),
      AppConstants.keyOutputFolderPath: '/active',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final repository = SettingsRepositoryImpl(
      SettingsLocalDataSourceImpl(storage),
    );
    final directory = await Directory.systemTemp.createTemp('settings-blank-');
    addTearDown(() => directory.delete(recursive: true));
    final importFile = File('${directory.path}/settings.json');
    await importFile.writeAsString(
      json.encode(
        SettingsLocalDataSourceTestData.settingsWithFolder('').toJson(),
      ),
    );
    final useCase = ImportSettings(
      repository,
      storage: storage,
      validator: (path) async => path,
    );

    final imported = await useCase(importFile);

    expect(imported.storage.outputFolderPath, '/active');
    expect(preferences.getString(AppConstants.keyOutputFolderPath), '/active');
  });

  test('import accepts a settings file at the size limit', () async {
    final previous = SettingsLocalDataSourceTestData.settingsWithFolder('/old');
    final imported = SettingsLocalDataSourceTestData.settingsWithFolder('/new');
    final repository = _MemorySettingsRepository(previous);
    final storage = _MemoryStorage({
      AppConstants.keyOutputFolderPath: '/old',
    });
    final encoded = json.encode(imported.toJson());
    final importFile = await _writeRawImportFile(
      encoded.padRight(ImportSettings.maxImportFileSizeBytes),
    );
    final useCase = ImportSettings(
      repository,
      storage: storage,
      validator: (path) async => path,
    );

    final result = await useCase(importFile);

    expect(result.storage.outputFolderPath, '/old');
  });

  test('import rejects a settings file above the size limit before reading it',
      () async {
    final previous = SettingsLocalDataSourceTestData.settingsWithFolder('/old');
    final repository = _MemorySettingsRepository(previous);
    final storage = _MemoryStorage({
      AppConstants.keyOutputFolderPath: '/old',
    });
    final importFile = await _writeRawImportFile(
      ' ' * (ImportSettings.maxImportFileSizeBytes + 1),
    );
    final useCase = ImportSettings(
      repository,
      storage: storage,
      validator: (path) async => path,
    );

    await expectLater(useCase(importFile), throwsFormatException);
    expect(repository.savedSettings, isEmpty);
  });

  test('import rejects an oversized naming template', () async {
    final previous = SettingsLocalDataSourceTestData.settingsWithFolder('/old');
    final repository = _MemorySettingsRepository(previous);
    final storage = _MemoryStorage({
      AppConstants.keyOutputFolderPath: '/old',
    });
    final imported = _settingsWith(
      namingTemplate: 'x' * (ImportSettings.maxNamingTemplateLength + 1),
    );
    final importFile = await _writeImportFile(imported);
    final useCase = ImportSettings(
      repository,
      storage: storage,
      validator: (path) async => path,
    );

    await expectLater(useCase(importFile), throwsFormatException);
    expect(repository.savedSettings, isEmpty);
  });

  for (final invalidJson in <String, Map<String, dynamic>>{
    'an empty object': {},
    'a missing theme section': {
      'storage': SettingsEntity.defaults().storage.toJson(),
      'processing': SettingsEntity.defaults().processing.toJson(),
    },
    'a missing processing field': {
      'theme': SettingsEntity.defaults().theme.toJson(),
      'storage': SettingsEntity.defaults().storage.toJson(),
      'processing': {'jpegQuality': 95, 'concurrentFiles': 4},
    },
  }.entries) {
    test('import rejects ${invalidJson.key}', () async {
      final previous = SettingsLocalDataSourceTestData.settingsWithFolder(
        '/old',
      );
      final repository = _MemorySettingsRepository(previous);
      final storage = _MemoryStorage({
        AppConstants.keyOutputFolderPath: '/old',
      });
      final importFile =
          await _writeRawImportFile(json.encode(invalidJson.value));
      final useCase = ImportSettings(
        repository,
        storage: storage,
        validator: (path) async => path,
      );

      await expectLater(useCase(importFile), throwsFormatException);
      expect(repository.savedSettings, isEmpty);
    });
  }

  test('custom theme survives a portable export-import round trip', () async {
    final defaults = SettingsEntity.defaults();
    final custom = defaults.copyWith(
      theme: const ThemeSettingsEntity(
        themeName: 'custom',
        customColors: {'accentPrimary': 0xFF123456},
      ),
      storage: defaults.storage.copyWith(outputFolderPath: '/private'),
    );
    final exportRepository = _MemorySettingsRepository(custom);
    final directory = await Directory.systemTemp.createTemp('settings-round-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/settings.json');
    await ExportSettings(exportRepository)(file.path);
    final importRepository = _MemorySettingsRepository(
      SettingsLocalDataSourceTestData.settingsWithFolder('/active'),
    );
    final storage = _MemoryStorage({
      AppConstants.keyOutputFolderPath: '/active',
    });

    final imported = await ImportSettings(
      importRepository,
      storage: storage,
      validator: (path) async => path,
    )(file);

    expect(imported.theme, custom.theme);
    expect(imported.storage.outputFolderPath, '/active');
  });

  test('export omits the device-local output folder', () async {
    final settings = SettingsLocalDataSourceTestData.settingsWithFolder(
      '/private/output',
    );
    final repository = _MemorySettingsRepository(settings);
    final directory = await Directory.systemTemp.createTemp('settings-export-');
    addTearDown(() => directory.delete(recursive: true));
    final exportFile = File('${directory.path}/settings.json');

    await ExportSettings(repository)(exportFile.path);

    final exported =
        json.decode(await exportFile.readAsString()) as Map<String, dynamic>;
    final storage = exported['storage']! as Map<String, dynamic>;
    expect(storage, isNot(contains('outputFolderPath')));
  });

  for (var failedRemove = 1; failedRemove <= 4; failedRemove++) {
    test('reset restores every key when remove $failedRemove fails', () async {
      final initial = <String, Object>{
        'app_settings_v1': '{"saved":true}',
        AppConstants.keyColorTheme: 'Mercury',
        AppConstants.keyOutputFolderPath: '/output',
        AppConstants.keyOnboardingCompleted: true,
      };
      final storage = _MemoryStorage(
        initial,
        failRemoveAt: failedRemove,
      );
      final dataSource = SettingsLocalDataSourceImpl(storage);

      await expectLater(dataSource.clearAllSettings(), throwsStateError);

      expect(storage.values, initial);
    });
  }
}

SettingsEntity _settingsWith({
  int? jpegQuality,
  int? concurrentFiles,
  String? folderStructure,
  String? namingTemplate,
  String? themeName,
}) {
  final defaults = SettingsEntity.defaults();
  return defaults.copyWith(
    theme: ThemeSettingsEntity(
      themeName: themeName ?? defaults.theme.themeName,
    ),
    storage: defaults.storage.copyWith(
      outputFolderPath: '/new',
      folderStructure: folderStructure,
      namingTemplate: namingTemplate,
    ),
    processing: defaults.processing.copyWith(
      jpegQuality: jpegQuality,
      concurrentFiles: concurrentFiles,
    ),
  );
}

Future<File> _writeImportFile(SettingsEntity settings) async {
  return _writeRawImportFile(json.encode(settings.toJson()));
}

Future<File> _writeRawImportFile(String contents) async {
  final directory = await Directory.systemTemp.createTemp('settings-import-');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/settings.json');
  await file.writeAsString(contents);
  return file;
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(this.settings);

  SettingsEntity settings;
  final savedSettings = <SettingsEntity>[];

  @override
  Future<SettingsEntity> getSettings() async => settings;

  @override
  Future<void> resetAll() async => settings = SettingsEntity.defaults();

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    this.settings = settings;
    savedSettings.add(settings);
  }
}

class _MemoryStorage implements KeyValueStorage {
  _MemoryStorage(
    Map<String, Object> values, {
    this.failNextSetString = false,
    this.failRemoveAt,
  }) : _values = Map.of(values);

  final Map<String, Object> _values;
  bool failNextSetString;
  final int? failRemoveAt;
  int _removeCount = 0;

  Map<String, Object> get values => Map.unmodifiable(_values);

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
    _removeCount++;
    if (_removeCount == failRemoveAt) {
      throw StateError('remove failed');
    }
    _values.remove(key);
  }

  @override
  Future<void> setBool(String key, {required bool value}) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, {required String value}) async {
    if (failNextSetString) {
      failNextSetString = false;
      throw StateError('setString failed');
    }
    _values[key] = value;
  }
}

abstract final class SettingsLocalDataSourceTestData {
  static SettingsEntity settingsWithFolder(String path) =>
      SettingsEntity.defaults().copyWith(
        storage: SettingsEntity.defaults().storage.copyWith(
              outputFolderPath: path,
            ),
      );
}
