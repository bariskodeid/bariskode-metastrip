import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/errors/app_exceptions.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/core/storage/stored_output_folder_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String? documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _MemoryStorage implements KeyValueStorage {
  final Map<String, Object> values = {};

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setBool(String key, {required bool value}) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, {required String value}) async {
    values[key] = value;
  }
}

void main() {
  late Directory temp;
  late _MemoryStorage storage;
  late String stalePath;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('metastrip_stored_folder_');
    addTearDown(() => temp.delete(recursive: true));
    final previous = PathProviderPlatform.instance;
    // "Second launch": the app container moved to a new UUID path.
    PathProviderPlatform.instance =
        _FakePathProvider('${temp.path}/new-uuid/Documents');
    addTearDown(() => PathProviderPlatform.instance = previous);
    stalePath = '${temp.path}/old-uuid/Documents/MetaStrip';
    storage = _MemoryStorage()
      ..values[AppConstants.keyOutputFolderPath] = stalePath;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS re-derives and persists a stale container output folder', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final fresh = '${temp.path}/new-uuid/Documents/MetaStrip';

    final result =
        await StoredOutputFolderRepository(storage).getValidOutputFolder();

    expect(result, fresh);
    expect(storage.values[AppConstants.keyOutputFolderPath], fresh);
  });

  test('a valid stored folder is returned unchanged', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final current = Directory('${temp.path}/new-uuid/Documents/MetaStrip');
    await current.create(recursive: true);
    storage.values[AppConstants.keyOutputFolderPath] = current.path;

    final result =
        await StoredOutputFolderRepository(storage).getValidOutputFolder();

    expect(result, current.path);
  });

  test('non-iOS platforms keep failing on a missing plain path', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await expectLater(
      StoredOutputFolderRepository(storage).getValidOutputFolder(),
      throwsA(isA<OutputFolderException>()),
    );
    expect(storage.values[AppConstants.keyOutputFolderPath], stalePath);
  });
}
