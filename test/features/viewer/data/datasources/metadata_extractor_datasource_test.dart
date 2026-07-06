import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/metadata_extractor_datasource.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

void main() {
  test('extractBasic returns filesystem, MIME, and hash metadata', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_test_');
    addTearDown(() => dir.delete(recursive: true));

    final file = File('${dir.path}${Platform.pathSeparator}sample.txt');
    await file.writeAsString('hello');

    final metadata = await MetadataExtractorDatasource().extractBasic(
      FileItemEntity(
        path: file.path,
        name: 'sample.txt',
        extension: 'txt',
        sizeBytes: 5,
        addedAt: DateTime.now(),
      ),
    );

    final values = {
      for (final field in metadata.fields) field.label: field.value,
    };

    expect(values['Name'], 'sample.txt');
    expect(values['MIME Type'], 'text/plain');
    expect(values['SHA-256'], 'Not computed');
  });

  test('extractBasic computes and caches hash on request', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_hash_test_');
    addTearDown(() => dir.delete(recursive: true));

    final file = File('${dir.path}${Platform.pathSeparator}hash.txt');
    await file.writeAsString('hello');

    final metadata = await MetadataExtractorDatasource().extractBasic(
      FileItemEntity(
        path: file.path,
        name: 'hash.txt',
        extension: 'txt',
        sizeBytes: 5,
        addedAt: DateTime.now(),
      ),
      computeHash: true,
    );

    final values = {
      for (final field in metadata.fields) field.label: field.value,
    };

    expect(
      values['SHA-256'],
      '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e730'
      '43362938b9824',
    );
  });

  test('extractBasic returns PNG text chunk metadata', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_png_test_');
    addTearDown(() => dir.delete(recursive: true));

    final file = File('${dir.path}${Platform.pathSeparator}sample.png');
    await file.writeAsBytes(_pngWithTextChunk('Author', 'Ada'));

    final metadata = await MetadataExtractorDatasource().extractBasic(
      FileItemEntity(
        path: file.path,
        name: 'sample.png',
        extension: 'png',
        sizeBytes: await file.length(),
        addedAt: DateTime.now(),
      ),
    );

    final authorField = metadata.fields.singleWhere(
      (field) => field.section == 'PNG Text' && field.label == 'Author',
    );

    expect(authorField.value, 'Ada');
    expect(authorField.isPrivacySensitive, isTrue);
  });
}

Uint8List _pngWithTextChunk(String keyword, String value) {
  final signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  final ihdr = <int>[
    0,
    0,
    0,
    13,
    ...'IHDR'.codeUnits,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    2,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];
  final textData = <int>[...keyword.codeUnits, 0, ...value.codeUnits];
  final text = <int>[
    0,
    0,
    0,
    textData.length,
    ...'tEXt'.codeUnits,
    ...textData,
    0,
    0,
    0,
    0,
  ];
  final iend = <int>[0, 0, 0, 0, ...'IEND'.codeUnits, 0, 0, 0, 0];
  return Uint8List.fromList([...signature, ...ihdr, ...text, ...iend]);
}
