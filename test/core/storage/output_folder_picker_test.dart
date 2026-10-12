import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/output_folder_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String? documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('unsupported platforms report UnsupportedError and return null',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final errors = <Object>[];

    final result = await pickOutputFolder(onError: errors.add);

    expect(result, isNull);
    expect(errors, hasLength(1));
    expect(errors.single, isA<UnsupportedError>());
  });

  test('pickOutputFolder never throws without an onError callback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    expect(await pickOutputFolder(), isNull);
  });

  test('iOS pickOutputFolder returns Documents/MetaStrip and creates it',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final temp = await Directory.systemTemp.createTemp('metastrip_ios_docs_');
    addTearDown(() => temp.delete(recursive: true));
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
    addTearDown(() => PathProviderPlatform.instance = previous);
    final errors = <Object>[];

    final result = await pickOutputFolder(onError: errors.add);

    expect(result, '${temp.path}/MetaStrip');
    expect(errors, isEmpty);
    expect(await Directory('${temp.path}/MetaStrip').exists(), isTrue);
  });

  test('iOS pickOutputFolder reports path provider failures', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(null);
    addTearDown(() => PathProviderPlatform.instance = previous);
    final errors = <Object>[];

    final result = await pickOutputFolder(onError: errors.add);

    expect(result, isNull);
    expect(errors, hasLength(1));
  });
}
