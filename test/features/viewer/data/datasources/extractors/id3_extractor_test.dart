import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/id3_extractor.dart';

void main() {
  group('extractId3', () {
    test('extracts v2.3 Latin-1 text frames', () async {
      final bytes = _id3v2File(
        version: 3,
        frames: [
          _frame23('TIT2', _textFrame(0, latin1.encode('My Title'))),
          _frame23('TPE1', _textFrame(0, latin1.encode('My Artist'))),
          _frame23('TALB', _textFrame(0, latin1.encode('My Album'))),
        ],
      );

      final fields = await extractId3(bytes);
      final byLabel = {for (final field in fields) field.label: field};

      expect(fields, hasLength(3));
      expect(byLabel['Title']?.section, 'Audio ID3');
      expect(byLabel['Title']?.value, 'My Title');
      expect(byLabel['Artist']?.value, 'My Artist');
      expect(byLabel['Album']?.value, 'My Album');
      expect(byLabel['Title']?.isPrivacySensitive, isFalse);
    });

    test('decodes a UTF-16 text frame with a little-endian BOM', () async {
      final bytes = _id3v2File(
        version: 3,
        frames: [
          _frame23('TIT2', _textFrame(1, _utf16LeBom('Wärm Musik'))),
        ],
      );

      final fields = await extractId3(bytes);

      expect(fields.single.section, 'Audio ID3');
      expect(fields.single.label, 'Title');
      expect(fields.single.value, 'Wärm Musik');
    });

    test('extracts a v2.4 frame with a synchsafe size', () async {
      final bytes = _id3v2File(
        version: 4,
        frames: [
          _frame24('TIT2', _textFrame(3, utf8.encode('Jazz Éditor'))),
        ],
      );

      final fields = await extractId3(bytes);

      expect(fields.single.label, 'Title');
      expect(fields.single.value, 'Jazz Éditor');
    });

    test('reads an ID3v1.1 tail tag with track and genre', () async {
      final tag = List<int>.filled(128, 0);
      tag.setRange(0, 3, 'TAG'.codeUnits);
      _setFixed(tag, 3, 'Old Song');
      _setFixed(tag, 33, 'Old Artist');
      _setFixed(tag, 93, '2024');
      tag[125] = 0; // v1.1 marker byte
      tag[126] = 7; // track number
      tag[127] = 2; // genre: Country

      final fields = await extractId3(Uint8List.fromList(tag));
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Title']?.value, 'Old Song');
      expect(byLabel['Artist']?.value, 'Old Artist');
      expect(byLabel['Year']?.value, '2024');
      expect(byLabel['Track']?.value, '7');
      expect(byLabel['Genre']?.value, 'Country');
    });

    test('returns a status field when no tag is present', () async {
      final bytes = Uint8List.fromList(
        latin1.encode('plain audio bytes without any tags'),
      );

      final fields = await extractId3(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Audio ID3');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No ID3 metadata found');
    });

    test('returns a status field for a truncated ID3v2 header', () async {
      final bytes = Uint8List.fromList([
        ...latin1.encode('ID3'),
        3, // version
        0, // revision
        0, // flags
        ..._synchsafe(4096), // declared size exceeds available bytes
      ]);

      final fields = await extractId3(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Unable to parse ID3 metadata');
    });
  });
}

/// Builds a complete ID3v2 file with [frames] and a synchsafe header size.
Uint8List _id3v2File({
  required int version,
  required List<Uint8List> frames,
}) {
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

/// Builds an ID3v2.3 frame: id (4), size (4 BE), flags (2), data.
Uint8List _frame23(String id, Uint8List data) {
  return Uint8List.fromList([
    ...latin1.encode(id),
    ..._be32(data.length),
    0x00,
    0x00,
    ...data,
  ]);
}

/// Builds an ID3v2.4 frame: id (4), size (4 synchsafe), flags (2), data.
Uint8List _frame24(String id, Uint8List data) {
  return Uint8List.fromList([
    ...latin1.encode(id),
    ..._synchsafe(data.length),
    0x00,
    0x00,
    ...data,
  ]);
}

/// Builds a text frame payload: encoding byte followed by [text].
Uint8List _textFrame(int encoding, List<int> text) {
  return Uint8List.fromList([encoding, ...text]);
}

/// Encodes [text] as UTF-16LE with a little-endian BOM prefix.
Uint8List _utf16LeBom(String text) {
  final builder = BytesBuilder(copy: false);
  builder.add([0xFF, 0xFE]);
  for (final unit in text.codeUnits) {
    builder.add([unit & 0xFF, (unit >> 8) & 0xFF]);
  }
  return builder.takeBytes();
}

/// Writes [value] into [bytes] at [offset], padded with zeros to 30 chars.
void _setFixed(List<int> bytes, int offset, String value) {
  final codes = latin1.encode(value);
  bytes.setRange(offset, offset + codes.length, codes);
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

/// Encodes [value] as a four-byte synchsafe integer (7 bits per byte).
Uint8List _synchsafe(int value) {
  return Uint8List.fromList([
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ]);
}
