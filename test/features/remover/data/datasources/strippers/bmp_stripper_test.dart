import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/bmp_stripper.dart';

const _fileHeaderSize = 14;
const _dibHeaderSize = 40;
const _pixelOffset = _fileHeaderSize + _dibHeaderSize;
const _maxDimension = 100000;

void main() {
  group('stripBmp', () {
    for (final bitCount in [24, 32]) {
      test('preserves $bitCount-bit pixels and canonicalizes the header', () {
        final input = _bmp(
          width: 2,
          height: 3,
          bitCount: bitCount,
          reserved1: 0x1234,
          reserved2: 0x5678,
          declaredFileSize: 0,
          declaredImageSize: 0,
          trailingBytes: [0x58, 0x4D, 0x50, 0x21],
        );
        final expectedPixels = input.sublist(_pixelOffset,
            _pixelOffset + _pixelSpan(width: 2, height: 3, bitCount: bitCount));

        final result = stripBmp(input);
        final header = ByteData.sublistView(result);

        expect(result.length, _pixelOffset + expectedPixels.length);
        expect(header.getUint32(2, Endian.little), result.length);
        expect(header.getUint16(6, Endian.little), 0);
        expect(header.getUint16(8, Endian.little), 0);
        expect(header.getUint32(34, Endian.little), expectedPixels.length);
        expect(result.sublist(_pixelOffset), expectedPixels);
        expect(result, isNot(containsAllInOrder([0x58, 0x4D, 0x50, 0x21])));

        final mutableOffsets = <int>{
          ...List<int>.generate(4, (index) => 2 + index),
          6,
          7,
          8,
          9,
          ...List<int>.generate(4, (index) => 34 + index),
        };
        for (var offset = 0; offset < _pixelOffset; offset++) {
          if (!mutableOffsets.contains(offset)) {
            expect(result[offset], input[offset],
                reason: 'header byte $offset');
          }
        }
      });
    }

    test('accepts row padding and preserves every payload byte', () {
      final input = _bmp(width: 1, height: 2, bitCount: 24);
      final expectedPixels = input.sublist(_pixelOffset);

      final result = stripBmp(input);

      expect(expectedPixels.length, 8);
      expect(result.sublist(_pixelOffset), expectedPixels);
    });

    test('accepts dimensions at the supported upper bound', () {
      final input = _bmp(
        width: _maxDimension,
        height: 1,
        bitCount: 24,
      );

      final result = stripBmp(input);

      expect(result.length, _pixelOffset + 300000);
    });

    test('rejects malformed and unsupported BMP variants', () {
      final valid = _bmp(width: 2, height: 2, bitCount: 24);
      final cases = <String, Uint8List>{
        'null-equivalent empty input': Uint8List(0),
        'invalid signature': _withBytes(valid, 0, [0x5A, 0x5A]),
        'truncated file header': Uint8List.fromList(valid.sublist(0, 13)),
        'truncated DIB header': Uint8List.fromList(valid.sublist(0, 53)),
        'BITMAPCOREHEADER': _withUint32(valid, 14, 12),
        'BITMAPV4HEADER': _withUint32(valid, 14, 108),
        'zero width': _withInt32(valid, 18, 0),
        'zero height': _withInt32(valid, 22, 0),
        'negative width': _withInt32(valid, 18, -1),
        'top-down height': _withInt32(valid, 22, -1),
        'width above bound': _withInt32(valid, 18, _maxDimension + 1),
        'height above bound': _withInt32(valid, 22, _maxDimension + 1),
        'planes zero': _withUint16(valid, 26, 0),
        'planes two': _withUint16(valid, 26, 2),
        '1-bit pixels': _withUint16(valid, 28, 1),
        '16-bit pixels': _withUint16(valid, 28, 16),
        'BI_RLE8 compression': _withUint32(valid, 30, 1),
        'BI_BITFIELDS compression': _withUint32(valid, 30, 3),
        'pixel offset before byte 54': _withUint32(valid, 10, 53),
        'pixel offset after byte 54': _withUint32(valid, 10, 55),
        'truncated pixel payload': Uint8List.fromList(
          valid.sublist(0, valid.length - 1),
        ),
        'computed pixel span exceeds available bytes': _withDimensions(
          valid,
          width: _maxDimension,
          height: _maxDimension,
        ),
      };

      for (final MapEntry(key: name, value: bytes) in cases.entries) {
        expect(
          () => stripBmp(bytes),
          throwsFormatException,
          reason: name,
        );
      }
    });

    test('requires the exact computed pixel span before trailing data', () {
      final valid = _bmp(width: 2, height: 2, bitCount: 32);
      final oneByteShortWithTrailer = Uint8List.fromList([
        ...valid.sublist(0, valid.length - 1),
        0xAA,
        0xBB,
      ]);
      final input = _withUint32(oneByteShortWithTrailer, 2, 0);

      final result = stripBmp(input);

      expect(result.length, valid.length);
      expect(result.last, 0xAA);
      expect(result, isNot(contains(0xBB)));
    });

    test('rejects contradictory declared sizes', () {
      final valid = _bmp(width: 2, height: 2, bitCount: 24);

      expect(
        () => stripBmp(_withUint32(valid, 2, 53)),
        throwsFormatException,
      );
      expect(
        () => stripBmp(_withUint32(valid, 34, 1)),
        throwsFormatException,
      );
    });

    test('validator rejects changed header and pixel bytes', () {
      final input = _bmp(width: 2, height: 2, bitCount: 24);
      final output = stripBmp(input);

      final changedHeader = Uint8List.fromList(output)..[38] ^= 1;
      expect(
        () => validateBmpOutput(input, changedHeader),
        throwsFormatException,
      );

      final changedPixels = Uint8List.fromList(output)
        ..[54] = (output[54] + 1) & 0xFF;
      expect(
        () => validateBmpOutput(input, changedPixels),
        throwsFormatException,
      );
    });
  });
}

Uint8List _bmp({
  required int width,
  required int height,
  required int bitCount,
  int reserved1 = 0,
  int reserved2 = 0,
  int? declaredFileSize,
  int? declaredImageSize,
  List<int> trailingBytes = const [],
}) {
  final pixelSpan = _pixelSpan(
    width: width,
    height: height,
    bitCount: bitCount,
  );
  final bytes = Uint8List(_pixelOffset + pixelSpan + trailingBytes.length);
  final header = ByteData.sublistView(bytes);
  bytes.setAll(0, 'BM'.codeUnits);
  header
    ..setUint32(
      2,
      declaredFileSize ?? bytes.length,
      Endian.little,
    )
    ..setUint16(6, reserved1, Endian.little)
    ..setUint16(8, reserved2, Endian.little)
    ..setUint32(10, _pixelOffset, Endian.little)
    ..setUint32(14, _dibHeaderSize, Endian.little)
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, bitCount, Endian.little)
    ..setUint32(30, 0, Endian.little)
    ..setUint32(34, declaredImageSize ?? pixelSpan, Endian.little)
    ..setInt32(38, 2835, Endian.little)
    ..setInt32(42, 2835, Endian.little);
  for (var index = 0; index < pixelSpan; index++) {
    bytes[_pixelOffset + index] = (index * 37 + 11) & 0xFF;
  }
  bytes.setAll(_pixelOffset + pixelSpan, trailingBytes);
  return bytes;
}

int _pixelSpan({
  required int width,
  required int height,
  required int bitCount,
}) {
  final rowStride = ((width * bitCount + 31) ~/ 32) * 4;
  return rowStride * height;
}

Uint8List _withBytes(Uint8List source, int offset, List<int> values) {
  final copy = Uint8List.fromList(source)..setAll(offset, values);
  return copy;
}

Uint8List _withUint16(Uint8List source, int offset, int value) {
  final copy = Uint8List.fromList(source);
  ByteData.sublistView(copy).setUint16(offset, value, Endian.little);
  return copy;
}

Uint8List _withUint32(Uint8List source, int offset, int value) {
  final copy = Uint8List.fromList(source);
  ByteData.sublistView(copy).setUint32(offset, value, Endian.little);
  return copy;
}

Uint8List _withInt32(Uint8List source, int offset, int value) {
  final copy = Uint8List.fromList(source);
  ByteData.sublistView(copy).setInt32(offset, value, Endian.little);
  return copy;
}

Uint8List _withDimensions(
  Uint8List source, {
  required int width,
  required int height,
}) {
  final copy = _withInt32(source, 18, width);
  return _withInt32(copy, 22, height);
}
