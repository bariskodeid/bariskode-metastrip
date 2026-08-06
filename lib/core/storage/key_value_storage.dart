/// Minimal key-value storage used by application repositories.
abstract interface class KeyValueStorage {
  bool? getBool(String key);

  String? getString(String key);

  Future<void> setBool(String key, {required bool value});

  Future<void> setString(String key, {required String value});

  Future<void> remove(String key);
}
