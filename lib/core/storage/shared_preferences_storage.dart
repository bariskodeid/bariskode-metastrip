import 'package:metastrip/core/errors/app_exceptions.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin [SharedPreferences] adapter that keeps plugin APIs at bootstrap.
class SharedPreferencesStorage implements KeyValueStorage {
  const SharedPreferencesStorage(this._preferences);

  final SharedPreferences _preferences;

  @override
  bool? getBool(String key) => _preferences.getBool(key);

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<void> remove(String key) async {
    if (!_preferences.containsKey(key)) return;
    if (!await _preferences.remove(key)) {
      throw const StorageException('Could not remove the saved setting');
    }
  }

  @override
  Future<void> setBool(String key, {required bool value}) async {
    if (!await _preferences.setBool(key, value)) {
      throw const StorageException('Could not save the setting');
    }
  }

  @override
  Future<void> setString(String key, {required String value}) async {
    if (!await _preferences.setString(key, value)) {
      throw const StorageException('Could not save the setting');
    }
  }
}
