import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/riff_stripper.dart';

void main() {
  group('stripRiff - WAV', () {
    test('drops a LIST INFO chunk and keeps fmt and data', () {
      final infoSubchunks = <int>[
        ...'INAM'.codeUnits,
        ..._le32(5),
        ...'Title'.codeUnits,
        0x00, // pad for the odd 5-byte payload
        ...'IART'.codeUnits,
        ..._le32(8),
        ...'Artist  '.codeUnits,
      ];
      final bytes = _wav([
        ('fmt ', List<int>.filled(16, 0x10)),
        ('LIST', [...'INFO'.codeUnits, ...infoSubchunks]),
        ('data', List<int>.filled(64, 0x7F)),
      ]);

      final result = stripRiff(bytes, extension: 'wav');

      expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(result.sublist(8, 12)), 'WAVE');
      expect(
        ByteData.sublistView(result).getUint32(4, Endian.little),
        result.length - 8,
      );
      final chunks = _chunksOf(result, endian: Endian.little);
      expect(chunks.map((chunk) => chunk.$1), ['fmt ', 'data']);
      expect(chunks.first.$2, hasLength(16));
      expect(chunks.last.$2, hasLength(64));
      expect(String.fromCharCodes(result), isNot(contains('INFO')));
      expect(String.fromCharCodes(result), isNot(contains('INAM')));
    });

    test('drops ID3 and bext chunks and keeps data', () {
      final bytes = _wav([
        ('ID3 ', [...'TIT2'.codeUnits, ...List<int>.filled(20, 0xAA)]),
        ('bext', [...'Description'.codeUnits, ...List<int>.filled(10, 0xBB)]),
        ('data', List<int>.filled(48, 0x12)),
      ]);

      final result = stripRiff(bytes, extension: 'wav');

      expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
      final chunks = _chunksOf(result, endian: Endian.little);
      expect(chunks.map((chunk) => chunk.$1), ['data']);
      expect(chunks.single.$2, hasLength(48));
      expect(String.fromCharCodes(result), isNot(contains('ID3')));
      expect(String.fromCharCodes(result), isNot(contains('bext')));
      expect(
        ByteData.sublistView(result).getUint32(4, Endian.little),
        result.length - 8,
      );
    });

    test('returns the original bytes when no metadata chunk exists', () {
      final bytes = _wav([
        ('fmt ', List<int>.filled(16, 0x10)),
        ('data', List<int>.filled(32, 0xAB)),
      ]);

      final result = stripRiff(bytes, extension: 'wav');

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException when the file is not RIFF/WAVE', () {
      final notRiff = Uint8List.fromList('NOT A RIFF FILE'.codeUnits);
      final riffButNotWave = Uint8List.fromList([
        ...'RIFF'.codeUnits,
        ..._le32(4),
        ...'AVI '.codeUnits,
      ]);

      expect(
        () => stripRiff(notRiff, extension: 'wav'),
        throwsFormatException,
      );
      expect(
        () => stripRiff(riffButNotWave, extension: 'wav'),
        throwsFormatException,
      );
    });

    test('keeps an odd-sized fmt chunk with its pad byte aligned', () {
      final bytes = _wav([
        ('fmt ', List<int>.filled(18, 0x11)), // odd size -> pad byte follows
        ('LIST', [...'INFO'.codeUnits, ...'INAM'.codeUnits]),
        ('data', List<int>.filled(40, 0x22)),
      ]);

      final result = stripRiff(bytes, extension: 'wav');

      final chunks = _chunksOf(result, endian: Endian.little);
      expect(chunks.map((chunk) => chunk.$1), ['fmt ', 'data']);
      expect(chunks[0].$2, hasLength(18));
      expect(chunks[1].$2, hasLength(40));
      expect(
        ByteData.sublistView(result).getUint32(4, Endian.little),
        result.length - 8,
      );
    });

    test('throws FormatException when the chunk walk exceeds 512 chunks', () {
      final manyChunks = List<(String, List<int>)>.generate(
        520,
        (_) => ('xxxx', <int>[]),
      );
      final bytes = _wav(manyChunks);

      expect(
        () => stripRiff(bytes, extension: 'wav'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'RIFF chunk walk limit exceeded',
          ),
        ),
      );
    });
  });

  group('stripRiff - AIFF', () {
    test('drops NAME/AUTH/copyright/ANNO chunks and keeps COMM and SSND', () {
      final bytes = _aiff([
        ('NAME', [...'Song Title'.codeUnits]), // 10 bytes, even
        ('AUTH', [...'Some Artist'.codeUnits]), // 11 bytes, odd -> pad
        ('(c) ', [...'2026'.codeUnits]),
        ('ANNO', [...'Notes here'.codeUnits]),
        ('COMM', List<int>.filled(18, 0x01)),
        ('SSND', List<int>.filled(100, 0x77)),
      ]);

      final result = stripRiff(bytes, extension: 'aiff');

      expect(String.fromCharCodes(result.sublist(0, 4)), 'FORM');
      expect(String.fromCharCodes(result.sublist(8, 12)), 'AIFF');
      expect(
        ByteData.sublistView(result).getUint32(4, Endian.big),
        result.length - 8,
      );
      final chunks = _chunksOf(result, endian: Endian.big);
      expect(chunks.map((chunk) => chunk.$1), ['COMM', 'SSND']);
      expect(chunks[0].$2, hasLength(18));
      expect(chunks[1].$2, hasLength(100));
      expect(String.fromCharCodes(result), isNot(contains('NAME')));
      expect(String.fromCharCodes(result), isNot(contains('AUTH')));
      expect(String.fromCharCodes(result), isNot(contains('ANNO')));
      expect(String.fromCharCodes(result), isNot(contains('2026')));
    });

    test('returns the original bytes when no metadata chunk exists', () {
      final bytes = _aiff([
        ('COMM', List<int>.filled(18, 0x01)),
        ('SSND', List<int>.filled(50, 0x33)),
      ]);

      final result = stripRiff(bytes, extension: 'aiff');

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException when the file is not FORM/AIFF', () {
      final notForm = Uint8List.fromList('NOT A FORM FILE'.codeUnits);
      final formButNotAiff = Uint8List.fromList([
        ...'FORM'.codeUnits,
        ..._be32(4),
        ...'WAVE'.codeUnits,
      ]);

      expect(
        () => stripRiff(notForm, extension: 'aiff'),
        throwsFormatException,
      );
      expect(
        () => stripRiff(formButNotAiff, extension: 'aiff'),
        throwsFormatException,
      );
    });
  });

  group('stripRiff - extension handling', () {
    test('throws FormatException for an unsupported extension', () {
      final bytes = _wav([
        ('fmt ', List<int>.filled(16, 0x10)),
        ('data', List<int>.filled(32, 0xAB)),
      ]);

      expect(
        () => stripRiff(bytes, extension: 'mp3'),
        throwsFormatException,
      );
    });
  });
}

/// Builds a WAV file from [chunks]: 'RIFF' + little-endian size + 'WAVE' +
/// each chunk as id + little-endian size + payload + pad byte for odd sizes.
Uint8List _wav(List<(String, List<int>)> chunks) {
  final body = <int>[
    ...'WAVE'.codeUnits,
    ...chunks.expand((chunk) => _chunk(chunk, endian: Endian.little)),
  ];
  return Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._le32(body.length),
    ...body,
  ]);
}

/// Builds an AIFF file from [chunks]: 'FORM' + big-endian size + 'AIFF' +
/// each chunk as id + big-endian size + payload + pad byte for odd sizes.
Uint8List _aiff(List<(String, List<int>)> chunks) {
  final body = <int>[
    ...'AIFF'.codeUnits,
    ...chunks.expand((chunk) => _chunk(chunk, endian: Endian.big)),
  ];
  return Uint8List.fromList([
    ...'FORM'.codeUnits,
    ..._be32(body.length),
    ...body,
  ]);
}

/// Serializes one chunk: id + [endian] size + payload + pad for odd sizes.
List<int> _chunk((String, List<int>) chunk, {required Endian endian}) {
  final (id, data) = chunk;
  final size = data.length;
  return [
    ...id.codeUnits,
    ..._uint32(size, endian),
    ...data,
    if (size.isOdd) 0x00,
  ];
}

/// Walks the chunks of a rebuilt RIFF container starting at offset 12.
List<(String, Uint8List)> _chunksOf(Uint8List bytes, {required Endian endian}) {
  final chunks = <(String, Uint8List)>[];
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = ByteData.sublistView(
      bytes,
      offset + 4,
      offset + 8,
    ).getUint32(0, endian);
    chunks.add((id, bytes.sublist(offset + 8, offset + 8 + size)));
    offset += 8 + size;
    if (size.isOdd) offset++;
  }
  return chunks;
}

List<int> _uint32(int value, Endian endian) =>
    endian == Endian.little ? _le32(value) : _be32(value);

List<int> _le32(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

List<int> _be32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
