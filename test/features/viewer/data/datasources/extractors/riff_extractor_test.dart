import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/riff_extractor.dart';

void main() {
  group('extractRiff', () {
    test('extracts LIST INFO sub-chunks from a WAV file', () async {
      final bytes = _wavBytes([
        _infoList({
          'INAM': 'Dreamscape',
          'ICOP': '2024 Studio West',
          'ICRD': '2024-01-01',
        }),
      ]);

      final fields = await extractRiff(bytes, extension: 'wav');
      final byLabel = {for (final field in fields) field.label: field};

      expect(fields, hasLength(3));
      expect(byLabel['Title']?.section, 'Audio RIFF');
      expect(byLabel['Title']?.value, 'Dreamscape');
      expect(byLabel['Date']?.value, '2024-01-01');
      expect(byLabel['Copyright']?.value, '2024 Studio West');
      expect(byLabel['Title']?.isPrivacySensitive, isFalse);
    });

    test('surfaces an embedded ID3 chunk in a WAV file', () async {
      final id3 = Uint8List.fromList(
        utf8.encode('ID3\x04\x00\x00\x00\x00\x00\x00'),
      );
      final bytes = _wavBytes([_chunk('ID3 ', id3)]);

      final fields = await extractRiff(bytes, extension: 'wav');

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Audio RIFF');
      expect(fields.single.label, 'ID3');
      expect(fields.single.value, contains('ID3'));
    });

    test('extracts NAME, AUTH and copyright chunks from an AIFF file',
        () async {
      final bytes = _aiffBytes([
        _chunk('NAME', _riffText('Aiff Title'), bigEndian: true),
        _chunk('AUTH', _riffText('Jane Doe'), bigEndian: true),
        _chunk('(c) ', _riffText('2024 Jane Doe'), bigEndian: true),
      ]);

      final fields = await extractRiff(bytes, extension: 'aiff');
      final byLabel = {for (final field in fields) field.label: field};

      expect(fields, hasLength(3));
      expect(byLabel['Title']?.value, 'Aiff Title');
      expect(byLabel['Author']?.value, 'Jane Doe');
      expect(byLabel['Author']?.isPrivacySensitive, isTrue);
      expect(byLabel['Copyright']?.value, '2024 Jane Doe');
    });

    test('returns a status field when a WAV has no metadata chunks', () async {
      final bytes = _wavBytes([
        _chunk('fmt ', Uint8List(16)),
        _chunk('data', Uint8List(100)),
      ]);

      final fields = await extractRiff(bytes, extension: 'wav');

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Audio RIFF');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No RIFF metadata found');
    });

    test('returns a status field for an invalid RIFF signature', () async {
      final bytes = Uint8List.fromList(
        utf8.encode('RIFF\x04\x00\x00\x00AVI LIST'),
      );

      final fields = await extractRiff(bytes, extension: 'wav');

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Not a valid RIFF file');
    });
  });
}

/// Builds a WAV container: `RIFF` + size + `WAVE` + [chunks].
Uint8List _wavBytes(List<Uint8List> chunks) {
  return _riffContainer('RIFF', 'WAVE', chunks, bigEndian: false);
}

/// Builds an AIFF container: `FORM` + size + `AIFF` + [chunks].
Uint8List _aiffBytes(List<Uint8List> chunks) {
  return _riffContainer('FORM', 'AIFF', chunks, bigEndian: true);
}

/// Builds a RIFF-style container with [signature] and [format], then chunks.
Uint8List _riffContainer(
  String signature,
  String format,
  List<Uint8List> chunks, {
  required bool bigEndian,
}) {
  final content = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    content.add(chunk);
  }
  final data = content.takeBytes();
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode(signature));
  builder.add(bigEndian ? _be32(4 + data.length) : _le32(4 + data.length));
  builder.add(latin1.encode(format));
  builder.add(data);
  return builder.takeBytes();
}

/// Builds a chunk with [id], LE/BE [size] and [data], padded when odd.
Uint8List _chunk(
  String id,
  Uint8List data, {
  bool bigEndian = false,
}) {
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode(id));
  builder.add(bigEndian ? _be32(data.length) : _le32(data.length));
  builder.add(data);
  if (data.length.isOdd) builder.addByte(0);
  return builder.takeBytes();
}

/// Builds a `LIST` chunk with the `INFO` type and [entries] as sub-chunks.
Uint8List _infoList(Map<String, String> entries) {
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('INFO'));
  entries.forEach((id, value) {
    builder.add(_chunk(id, _riffText(value)));
  });
  return _chunk('LIST', builder.takeBytes());
}

/// Encodes [value] as Latin-1 text bytes.
Uint8List _riffText(String value) {
  return Uint8List.fromList(latin1.encode(value));
}

/// Encodes [value] as a four-byte little-endian integer.
Uint8List _le32(int value) {
  return Uint8List.fromList([
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}

/// Encodes [value] as a four-byte big-endian integer.
Uint8List _be32(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}