import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/png_text_extractor.dart';

void main() {
  test('zTXt value is inflated and gets png.text id', () async {
    final data = BytesBuilder()
      ..add(latin1.encode('Comment'))
      ..addByte(0)
      ..addByte(0) // compression method
      ..add(zlib.encode(utf8.encode('secret zip text')));
    final fields =
        await extractPngText(_png([_chunk('zTXt', data.takeBytes())]));

    expect(fields, hasLength(1));
    expect(fields.single.label, 'Comment');
    expect(fields.single.value, 'secret zip text');
    expect(fields.single.id, MetadataFieldId.pngText('Comment'));
  });

  test('compressed iTXt value is inflated', () async {
    final data = BytesBuilder()
      ..add(latin1.encode('Description'))
      ..addByte(0)
      ..addByte(1) // compressed
      ..addByte(0) // method
      ..addByte(0) // empty language tag
      ..addByte(0) // empty translated keyword
      ..add(zlib.encode(utf8.encode('compressed itxt')));
    final fields =
        await extractPngText(_png([_chunk('iTXt', data.takeBytes())]));

    expect(fields.single.label, 'Description');
    expect(fields.single.value, 'compressed itxt');
    expect(fields.single.id, MetadataFieldId.pngText('Description'));
  });

  test('eXIf chunk is surfaced as a privacy-sensitive presence field',
      () async {
    final fields = await extractPngText(
      _png([
        _chunk('eXIf', Uint8List.fromList([1, 2, 3, 4]))
      ]),
    );

    final exif = fields.singleWhere((f) => f.label == 'EXIF');
    expect(exif.isPrivacySensitive, isTrue);
    expect(exif.id, isNull);
  });

  test('zTXt inflating beyond the cap yields a status field, no throw',
      () async {
    final data = BytesBuilder()
      ..add(latin1.encode('Bomb'))
      ..addByte(0)
      ..addByte(0)
      ..add(zlib.encode(Uint8List(4 * 1024 * 1024)));
    final fields =
        await extractPngText(_png([_chunk('zTXt', data.takeBytes())]));

    expect(fields, hasLength(1));
    expect(fields.single.label, 'Bomb');
    expect(fields.single.value, contains('exceeds'));
  });
}

Uint8List _chunk(String type, Uint8List data) {
  final b = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(latin1.encode(type))
    ..add(data)
    ..add(Uint8List(4)); // CRC is not checked by the viewer
  return b.takeBytes();
}

Uint8List _png(List<Uint8List> chunks) {
  final b = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  for (final c in chunks) {
    b.add(c);
  }
  b.add(_chunk('IEND', Uint8List(0)));
  return b.takeBytes();
}
