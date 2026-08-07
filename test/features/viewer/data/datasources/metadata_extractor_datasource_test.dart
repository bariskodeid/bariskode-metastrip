import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
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

  test('extractBasic hashes the full file for bounded-read formats', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_mp3_hash_');
    addTearDown(() => dir.delete(recursive: true));

    // Larger than the 1MB bounded-read prefix, so the payload handed to the
    // extractor is only a prefix plus tail. The SHA-256 label must still be
    // honest and cover the whole file, not just the bounded payload.
    final tag = _id3v2File(version: 3, frames: const []);
    final filler = Uint8List(AppConstants.maxAudioScanBytes);
    final tail = Uint8List.fromList('TAIL'.codeUnits);
    final full = Uint8List.fromList([...tag, ...filler, ...tail]);
    final file = File('${dir.path}${Platform.pathSeparator}hash.mp3');
    await file.writeAsBytes(full);

    final metadata = await MetadataExtractorDatasource().extractBasic(
      FileItemEntity(
        path: file.path,
        name: 'hash.mp3',
        extension: 'mp3',
        sizeBytes: full.length,
        addedAt: DateTime.now(),
      ),
      computeHash: true,
    );

    final values = {
      for (final field in metadata.fields) field.label: field.value,
    };

    expect(values['SHA-256'], sha256.convert(full).toString());
  });
}

Uint8List _id3v2File({required int version, required List<Uint8List> frames}) {
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('ID3'));
  builder.addByte(version);
  builder.addByte(0); // revision
  builder.addByte(0); // flags
  final total = frames.fold<int>(0, (sum, frame) => sum + frame.length);
  builder.add(_synchsafe(total));
  for (final frame in frames) {
    builder.add(frame);
  }
  return builder.takeBytes();
}

Uint8List _synchsafe(int value) {
  return Uint8List.fromList([
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ]);
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
