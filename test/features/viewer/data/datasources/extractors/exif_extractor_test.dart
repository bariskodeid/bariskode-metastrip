import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/exif_extractor.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

void main() {
  test('reads EXIF that directly follows the JFIF header', () async {
    final fields = await extractExif(_jpeg([_jfif(), _exifApp1()]));

    expect(_value(fields, 'Image Make'), 'Pixel');
  });

  test('reads EXIF behind a large APP11 (C2PA/JUMBF) segment', () async {
    final fields = await extractExif(
      _jpeg([_jfif(), _segment(0xEB, Uint8List(6000)), _exifApp1()]),
    );

    expect(_value(fields, 'Image Make'), 'Pixel');
  });

  test('reads EXIF behind a large XMP APP1 segment', () async {
    final xmp = latin1.encode(
      'http://ns.adobe.com/xap/1.0/\u0000<x:xmpmeta>${'x' * 6000}</x:xmpmeta>',
    );
    final fields = await extractExif(
      _jpeg([_segment(0xE1, Uint8List.fromList(xmp)), _exifApp1()]),
    );

    expect(_value(fields, 'Image Make'), 'Pixel');
  });

  test('reports no EXIF when the JPEG has no Exif APP1', () async {
    final fields = await extractExif(
      _jpeg([_jfif(), _segment(0xEB, Uint8List(6000))]),
    );

    expect(_value(fields, 'Status'), 'No EXIF metadata found');
  });

  test('a segment length past the end of the file does not throw', () async {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xEB, 0xFF, 0xF0, 0]);

    final fields = await extractExif(bytes);

    expect(fields.single.section, 'Image EXIF');
    expect(fields.single.label, 'Status');
  });
}

String? _value(List<MetadataFieldEntity> fields, String label) {
  for (final field in fields) {
    if (field.label == label) return field.value;
  }
  return null;
}

Uint8List _jpeg(List<Uint8List> segments) {
  final builder = BytesBuilder()..add([0xFF, 0xD8]);
  segments.forEach(builder.add);
  // Minimal scan so the marker walk has a real end, then EOI.
  builder
    ..add(_segment(0xDA, Uint8List(10)))
    ..add([0x00, 0x00, 0xFF, 0xD9]);
  return builder.takeBytes();
}

Uint8List _segment(int marker, Uint8List payload) {
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF,
    marker,
    length >> 8,
    length & 0xFF,
    ...payload,
  ]);
}

Uint8List _jfif() => _segment(
  0xE0,
  Uint8List.fromList([...latin1.encode('JFIF'), 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]),
);

/// Big-endian TIFF with one IFD0 entry: Make = "Pixel".
Uint8List _exifApp1() {
  final value = latin1.encode('Pixel\u0000');
  const valueOffset = 8 + 2 + 12 + 4;
  final tiff = Uint8List.fromList([
    ...latin1.encode('MM'), 0x00, 0x2A, // byte order + magic
    0x00, 0x00, 0x00, 0x08, // IFD0 offset
    0x00, 0x01, // one entry
    0x01, 0x0F, 0x00, 0x02, // tag Make, type ASCII
    0x00, 0x00, 0x00, value.length, // count
    0x00, 0x00, 0x00, valueOffset, // value offset
    0x00, 0x00, 0x00, 0x00, // no next IFD
    ...value,
  ]);
  return _segment(
    0xE1,
    Uint8List.fromList([...latin1.encode('Exif'), 0, 0, ...tiff]),
  );
}
