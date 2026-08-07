import 'package:metastrip/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';

/// Repository implementation delegating to local data source.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dataSource);

  final SettingsLocalDataSource _dataSource;

  @override
  Future<SettingsEntity> getSettings() => _dataSource.getSettings();

  @override
  Future<void> saveSettings(SettingsEntity settings) => _dataSource.saveSettings(settings);

  @override
  Future<void> resetAll() => _dataSource.clearAllSettings();
}