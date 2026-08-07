import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';

/// Resets all settings to defaults by clearing persisted data.
class ResetSettings {
  ResetSettings(this._repository);

  final SettingsRepository _repository;

  Future<void> call() => _repository.resetAll();
}