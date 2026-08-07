import 'dart:convert';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';

/// Local data source for settings persistence using SharedPreferences.
abstract class SettingsLocalDataSource {
  Future<SettingsEntity> getSettings();

  Future<void> saveSettings(SettingsEntity settings);

  Future<void> clearAllSettings();
}

/// SharedPreferences-backed implementation.
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  SettingsLocalDataSourceImpl(this._storage);

  final KeyValueStorage _storage;

  static const _settingsKey = 'app_settings_v1';

  @override
  Future<SettingsEntity> getSettings() async {
    final jsonString = _storage.getString(_settingsKey);
    final outputFolderPath =
        _storage.getString(AppConstants.keyOutputFolderPath);
    if (jsonString == null) {
      final defaults = SettingsEntity.defaults();
      return defaults.copyWith(
        storage: defaults.storage.copyWith(
          outputFolderPath: outputFolderPath,
        ),
      );
    }
    try {
      final map = json.decode(jsonString) as Map<String, dynamic>;
      final settings = SettingsEntity.fromJson(map);
      return settings.copyWith(
        storage: settings.storage.copyWith(
          outputFolderPath:
              outputFolderPath ?? settings.storage.outputFolderPath,
        ),
      );
    } catch (_) {
      // Corrupted JSON -> return defaults
      final defaults = SettingsEntity.defaults();
      return defaults.copyWith(
        storage: defaults.storage.copyWith(
          outputFolderPath: outputFolderPath,
        ),
      );
    }
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    final jsonString = json.encode(settings.toJson());
    await _storage.setString(_settingsKey, value: jsonString);
  }

  @override
  Future<void> clearAllSettings() async {
    final settings = _storage.getString(_settingsKey);
    final colorTheme = _storage.getString(AppConstants.keyColorTheme);
    final outputFolder = _storage.getString(AppConstants.keyOutputFolderPath);
    final onboardingCompleted =
        _storage.getBool(AppConstants.keyOnboardingCompleted);
    try {
      await _storage.remove(_settingsKey);
      await _storage.remove(AppConstants.keyColorTheme);
      await _storage.remove(AppConstants.keyOutputFolderPath);
      await _storage.remove(AppConstants.keyOnboardingCompleted);
    } catch (_) {
      try {
        await _restoreString(_settingsKey, settings);
        await _restoreString(AppConstants.keyColorTheme, colorTheme);
        await _restoreString(AppConstants.keyOutputFolderPath, outputFolder);
        await _restoreBool(
          AppConstants.keyOnboardingCompleted,
          onboardingCompleted,
        );
      } catch (_) {
        // Preserve the original reset error when restoration also fails.
      }
      rethrow;
    }
  }

  Future<void> _restoreString(String key, String? value) async {
    if (value == null) {
      await _storage.remove(key);
    } else {
      await _storage.setString(key, value: value);
    }
  }

  Future<void> _restoreBool(String key, bool? value) async {
    if (value == null) {
      await _storage.remove(key);
    } else {
      await _storage.setBool(key, value: value);
    }
  }
}
