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

  group('resolveStaleIosOutputFolder', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('metastrip_ios_stale_');
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance =
          _FakePathProvider('${temp.path}/new-uuid/Documents');
      addTearDown(() => PathProviderPlatform.instance = previous);
      addTearDown(() => temp.delete(recursive: true));
    });

    test('iOS re-derives a stale container Documents/MetaStrip path', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final result = await resolveStaleIosOutputFolder(
        '${temp.path}/old-uuid/Documents/MetaStrip',
      );

      expect(result, '${temp.path}/new-uuid/Documents/MetaStrip');
      expect(await Directory(result!).exists(), isTrue);
    });

    test('iOS leaves the current folder and unrelated paths alone', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(
        await resolveStaleIosOutputFolder(
          '${temp.path}/new-uuid/Documents/MetaStrip',
        ),
        isNull,
      );
      expect(await resolveStaleIosOutputFolder('/somewhere/else'), isNull);
      expect(await resolveStaleIosOutputFolder(null), isNull);
    });

    test('other platforms never re-derive', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        await resolveStaleIosOutputFolder('/old-uuid/Documents/MetaStrip'),
        isNull,
      );
    });

    test('iOS path provider failure returns null', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      PathProviderPlatform.instance = _FakePathProvider(null);

      expect(
        await resolveStaleIosOutputFolder('/old-uuid/Documents/MetaStrip'),
        isNull,
      );
    });
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
