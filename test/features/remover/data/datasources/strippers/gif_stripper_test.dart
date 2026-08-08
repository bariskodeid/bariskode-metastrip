import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/gif_stripper.dart';

void main() {
  group('stripGif', () {
    test('drops a comment extension and keeps a valid GIF', () {
      final bytes = _gif([
        ...[0x21, 0xFE], // comment extension
        ..._subBlock([...'Private note'.codeUnits]),
        0x00, // terminator
        ..._image(),
      ]);

      final result = stripGif(bytes);

      expect(identical(result, bytes), isFalse);
      expect(String.fromCharCodes(result.sublist(0, 6)), 'GIF89a');
      expect(result.last, 0x3B);
      expect(_indexOf(result, [0x21, 0xFE]), -1);
      expect(String.fromCharCodes(result), isNot(contains('Private note')));
      // The image descriptor and its data survive the rebuild.
      expect(_indexOf(result, _image()), greaterThanOrEqualTo(6));
    });

    test('drops an XMP application extension and keeps other blocks', () {
      final bytes = _gif([
        ...[0x21, 0xFF], // application extension
        ..._subBlock([
          ...'XMP DataXMP'.codeUnits,
          0x00,
          ...'<x:xmpmeta>secret</x:xmpmeta>'.codeUnits,
        ]),
        0x00,
        ..._image(),
      ]);

      final result = stripGif(bytes);

      expect(identical(result, bytes), isFalse);
      expect(String.fromCharCodes(result), isNot(contains('XMP DataXMP')));
      expect(String.fromCharCodes(result), isNot(contains('secret')));
      expect(String.fromCharCodes(result.sublist(0, 6)), 'GIF89a');
      expect(result.last, 0x3B);
    });

    test('returns the original bytes when no metadata extension exists', () {
      final bytes = _gif([..._image()]);

      final result = stripGif(bytes);

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException when the file is not a valid GIF', () {
      final notGif = Uint8List.fromList('NOT A GIF FILE'.codeUnits);
      final badVersion = Uint8List.fromList([
        ...'GIF'.codeUnits,
        0x38, 0x36, 0x61, // 'GIF86a' is not a valid version
        ...List<int>.filled(7, 0),
      ]);

      expect(() => stripGif(notGif), throwsFormatException);
      expect(() => stripGif(badVersion), throwsFormatException);
    });

    test('keeps graphic control, plain text and non-XMP app extensions', () {
      final graphicControl = <int>[
        0x21,
        0xF9,
        0x04,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00
      ];
      final plainText = <int>[
        0x21, 0x01, // plain text extension
        ..._subBlock([0x01, 0x02, 0x03]),
        0x00,
      ];
      final netScape = <int>[
        0x21, 0xFF, // application extension, not XMP
        ..._subBlock([...'NETSCAPE2.0'.codeUnits]),
        0x00,
      ];
      final bytes =
          _gif([...graphicControl, ...plainText, ...netScape, ..._image()]);

      final result = stripGif(bytes);

      expect(identical(result, bytes), isTrue); // nothing dropped
      expect(String.fromCharCodes(result), contains('NETSCAPE2.0'));
      expect(_indexOf(result, graphicControl), 13);
      expect(_indexOf(result, plainText), greaterThan(13));
      expect(_indexOf(result, netScape), greaterThan(13));
      expect(_indexOf(result, _image()), greaterThan(13));
    });

    test('throws FormatException when the block walk exceeds 10000 blocks', () {
      final manyBlocks = <int>[];
      for (var i = 0; i < 10001; i++) {
        manyBlocks.addAll([0x21, 0x01, 0x00]); // empty plain-text extension
      }
      final bytes = _gif(manyBlocks);

      expect(
        () => stripGif(bytes),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'GIF block walk limit exceeded',
          ),
        ),
      );
    });
  });
}

/// Builds a minimal GIF89a: header + 7-byte logical screen descriptor without
/// a global color table + [blocks] + trailer `0x3B`.
Uint8List _gif(List<int> blocks) {
  return Uint8List.fromList([
    ...'GIF89a'.codeUnits,
    0x01, 0x00, // width 1
    0x01, 0x00, // height 1
    0x00, // packed: no global color table
    0x00, // background index
    0x00, // aspect ratio
    ...blocks,
    0x3B,
  ]);
}

/// Serializes one sub-block: size byte + [data].
List<int> _subBlock(List<int> data) => [data.length, ...data];

/// Builds a 1x1 image descriptor with a local LZW sub-block stream.
List<int> _image() {
  return [
    0x2C, // image descriptor introducer
    0x00, 0x00, 0x00, 0x00, // left, top
    0x01, 0x00, 0x01, 0x00, // width, height
    0x00, // packed: no local color table
    0x02, // LZW minimum code size
    ..._subBlock([0x01, 0x02, 0x03, 0x04]),
    0x00,
  ];
}

/// Returns the first index of [needle] inside [haystack], or -1.
int _indexOf(Uint8List haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}
