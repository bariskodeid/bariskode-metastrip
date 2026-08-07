import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/id3_stripper.dart';

void main() {
  group('stripId3', () {
    test('removes an ID3v2 tag from the front', () {
      final bytes = Uint8List.fromList([
        ...'ID3'.codeUnits,
        0x03,
        0x00, // version 2.3.0
        0x00, // no footer
        ..._synchsafe(10),
        ...List<int>.filled(10, 0xAA), // tag payload
        ...'AUDIO12345'.codeUnits,
      ]);

      final result = stripId3(bytes);

      expect(String.fromCharCodes(result), startsWith('AUDIO'));
      expect(String.fromCharCodes(result), isNot(contains('ID3')));
      expect(result, hasLength(10));
    });

    test('removes both an ID3v2 front tag and an ID3v1 tail tag', () {
      final bytes = Uint8List.fromList([
        ...'ID3'.codeUnits,
        0x04,
        0x00, // version 2.4.0
        0x00,
        ..._synchsafe(6),
        ...List<int>.filled(6, 0xBB),
        ...'AUDIO1234'.codeUnits,
        ..._id3v1Tag('A song about audio'),
      ]);

      final result = stripId3(bytes);

      expect(String.fromCharCodes(result), 'AUDIO1234');
      expect(String.fromCharCodes(result), isNot(contains('ID3')));
      expect(String.fromCharCodes(result), isNot(contains('TAG')));
    });

    test('removes a lone ID3v1 tail tag and keeps the audio', () {
      final bytes = Uint8List.fromList([
        ...'AUDIO1234'.codeUnits,
        ..._id3v1Tag('Lone v1 tag'),
      ]);

      final result = stripId3(bytes);

      expect(String.fromCharCodes(result), 'AUDIO1234');
    });

    test('returns the original bytes when no tag is present', () {
      final bytes = Uint8List.fromList('AUDIO1234'.codeUnits);

      final result = stripId3(bytes);

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('discards the extra 10-byte footer when the footer flag is set', () {
      final bytes = Uint8List.fromList([
        ...'ID3'.codeUnits,
        0x03,
        0x00,
        0x10, // footer present
        ..._synchsafe(10),
        ...List<int>.filled(10, 0xCC), // tag payload
        ...List<int>.filled(10, 0xDD), // tag footer
        ...'AUDIO12345'.codeUnits,
      ]);

      final result = stripId3(bytes);

      expect(String.fromCharCodes(result), 'AUDIO12345');
      expect(result, hasLength(10));
    });

    test('drops an APEv2 tag that precedes an ID3v1 tail', () {
      final bytes = Uint8List.fromList([
        ...'AUDIO1234'.codeUnits,
        ...'APETAGEX'.codeUnits,
        ...List<int>.filled(24, 0xEE), // APEv2 header remainder
        ...List<int>.filled(8, 0xEE), // APEv2 items
        ...'APETAGEX'.codeUnits,
        ...List<int>.filled(24, 0xFF), // APEv2 footer
        ..._id3v1Tag('With APEv2'),
      ]);

      final result = stripId3(bytes);

      expect(String.fromCharCodes(result), 'AUDIO1234');
      expect(String.fromCharCodes(result), isNot(contains('APETAGEX')));
    });

    test('throws FormatException when stripping leaves no audio', () {
      final bytes = Uint8List.fromList([
        ...'ID3'.codeUnits,
        0x03,
        0x00,
        0x00,
        ..._synchsafe(4),
        ...List<int>.filled(4, 0xAB), // entire file is the tag
      ]);

      expect(() => stripId3(bytes), throwsFormatException);
    });

    test('masks high bits in synchsafe size bytes like the extractor', () {
      // The first synchsafe byte has bit 7 set, which is invalid per the ID3
      // spec. The stripper must mask with 0x7F so the tag size stays 1
      // instead of exploding to a huge value.
      final bytes = Uint8List.fromList([
        ...'ID3'.codeUnits,
        0x03,
        0x00,
        0x00,
        0x80, 0x00, 0x00, 0x01, // masked => size 1
        0xAA, // 1 byte of tag payload
        ...'AUDIO12345'.codeUnits,
      ]);

      final result = stripId3(bytes);

      expect(String.fromCharCodes(result), startsWith('AUDIO'));
      expect(String.fromCharCodes(result), isNot(contains('ID3')));
      expect(result, hasLength(10));
    });
  });
}

List<int> _id3v1Tag(String title) {
  final titleBytes = title.codeUnits.take(30).toList();
  return [
    ...'TAG'.codeUnits,
    ...titleBytes,
    ...List<int>.filled(125 - titleBytes.length, 0),
  ];
}

List<int> _synchsafe(int value) {
  return [
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ];
}
