import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/webp_stripper.dart';

/// VP8X flags used in the test fixtures, matching the WebP container spec:
/// bit 3 (0x08) EXIF metadata, bit 2 (0x04) XMP metadata, bit 1 (0x02)
/// animation.
const int _exifFlag = 0x08;
const int _xmpFlag = 0x04;
const int _animationFlag = 0x02;

void main() {
  group('stripWebp', () {
    test('drops EXIF and XMP chunks and clears the VP8X flags', () {
      final vp8Payload = List<int>.filled(16, 0x9D);
      final bytes = _webp([
        ('VP8X', [_exifFlag | _xmpFlag, ...List<int>.filled(9, 0x00)]),
        ('EXIF', [...'Exif data here'.codeUnits]),
        ('XMP ', [...'<x:xmpmeta>secret</x:xmpmeta>'.codeUnits]),
        ('VP8 ', vp8Payload),
      ]);

      final result = stripWebp(bytes);

      expect(identical(result, bytes), isFalse);
      expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(result.sublist(8, 12)), 'WEBP');
      expect(
        ByteData.sublistView(result).getUint32(4, Endian.little),
        result.length - 8,
      );
      final chunks = _chunksOf(result);
      expect(chunks.map((chunk) => chunk.$1), ['VP8X', 'VP8 ']);
      expect(chunks.first.$2[0], 0x00); // EXIF and XMP bits cleared
      expect(chunks.last.$2, vp8Payload);
      expect(String.fromCharCodes(result), isNot(contains('Exif data here')));
      expect(String.fromCharCodes(result), isNot(contains('secret')));
    });

    test('clears only the EXIF bit when only EXIF is dropped', () {
      final bytes = _webp([
        ('VP8X', [_exifFlag | _animationFlag, ...List<int>.filled(9, 0x00)]),
        ('EXIF', [...'some exif'.codeUnits]),
        ('VP8 ', List<int>.filled(8, 0x11)),
      ]);

      final result = stripWebp(bytes);

      final chunks = _chunksOf(result);
      expect(chunks.map((chunk) => chunk.$1), ['VP8X', 'VP8 ']);
      // Animation bit stays; only the EXIF bit is cleared.
      expect(chunks.first.$2[0], _animationFlag);
    });

    test('returns the original bytes when no metadata chunk exists', () {
      final bytes = _webp([
        ('VP8 ', List<int>.filled(16, 0xAA)),
        ('VP8L', List<int>.filled(8, 0xBB)),
      ]);

      final result = stripWebp(bytes);

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException when the file is not RIFF/WEBP', () {
      final notRiff = Uint8List.fromList('NOT A WEBP FILE'.codeUnits);
      final riffButNotWebp = Uint8List.fromList([
        ...'RIFF'.codeUnits,
        ..._le32(4),
        ...'AVI '.codeUnits,
      ]);

      expect(() => stripWebp(notRiff), throwsFormatException);
      expect(() => stripWebp(riffButNotWebp), throwsFormatException);
    });

    test('drops an odd-sized EXIF chunk with its pad byte cleanly', () {
      final exifPayload = List<int>.generate(9, (index) => 0x40 + index);
      final vp8Payload = List<int>.generate(32, (index) => index);
      final bytes = _webp([
        ('VP8 ', vp8Payload), // 32 bytes, even
        ('EXIF', exifPayload), // 9 bytes, odd -> pad byte follows
        ('VP8L', List<int>.filled(24, 0x7F)),
      ]);

      final result = stripWebp(bytes);

      final chunks = _chunksOf(result);
      expect(chunks.map((chunk) => chunk.$1), ['VP8 ', 'VP8L']);
      expect(chunks[0].$2, vp8Payload);
      expect(chunks[1].$2, List<int>.filled(24, 0x7F));
      expect(
        ByteData.sublistView(result).getUint32(4, Endian.little),
        result.length - 8,
      );
      expect(String.fromCharCodes(result), isNot(contains('EXIF')));
    });
  });
}

/// Builds a WebP container from [chunks]: 'RIFF' + little-endian size + 'WEBP'
/// + each chunk as id + little-endian size + payload + pad byte for odd sizes.
Uint8List _webp(List<(String, List<int>)> chunks) {
  final body = <int>[
    ...'WEBP'.codeUnits,
    ...chunks.expand(_chunk),
  ];
  return Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._le32(body.length),
    ...body,
  ]);
}

/// Serializes one chunk: id + little-endian size + payload + pad for odd sizes.
List<int> _chunk((String, List<int>) chunk) {
  final (id, data) = chunk;
  final size = data.length;
  return [
    ...id.codeUnits,
    ..._le32(size),
    ...data,
    if (size.isOdd) 0x00,
  ];
}

/// Walks the chunks of a rebuilt WebP container starting at offset 12.
List<(String, Uint8List)> _chunksOf(Uint8List bytes) {
  final chunks = <(String, Uint8List)>[];
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = ByteData.sublistView(
      bytes,
      offset + 4,
      offset + 8,
    ).getUint32(0, Endian.little);
    chunks.add((id, bytes.sublist(offset + 8, offset + 8 + size)));
    offset += 8 + size;
    if (size.isOdd) offset++;
  }
  return chunks;
}

List<int> _le32(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];