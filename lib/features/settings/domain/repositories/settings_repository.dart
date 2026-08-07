import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';

/// Repository interface for settings operations.
abstract class SettingsRepository {
  /// Returns current settings, falling back to defaults if none saved.
  Future<SettingsEntity> getSettings();

  /// Persists settings to local storage.
  Future<void> saveSettings(SettingsEntity settings);

  /// Clears all persisted settings and resets to defaults.
  Future<void> resetAll();
}