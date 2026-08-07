import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';

/// Saves settings to the repository.
class SaveSettings {
  SaveSettings(this._repository);

  final SettingsRepository _repository;

  Future<void> call(SettingsEntity settings) => _repository.saveSettings(settings);
}