import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';

/// Gets the current settings from the repository.
class GetSettings {
  GetSettings(this._repository);

  final SettingsRepository _repository;

  Future<SettingsEntity> call() => _repository.getSettings();
}