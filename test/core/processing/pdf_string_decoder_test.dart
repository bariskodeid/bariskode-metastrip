import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/pdf_string_decoder.dart';

void main() {
  group('decodePdfLiteral', () {
    test('resolves the named escapes', () {
      expect(
        decodePdfLiteral(r'a\nb\rc\td\be\ff\(g\)h\\i'),
        'a\nb\rc\td\be\ff(g)h\\i',
      );
    });

    test('resolves one to three digit octal escapes', () {
      expect(decodePdfLiteral(r'J\101ne'), 'JAne');
      expect(decodePdfLiteral(r'\61\0627'), '1' '2' '7');
      expect(decodePdfLiteral(r'\7'), '\x07');
      expect(decodePdfLiteral(r'\501'), 'A');
    });

    test('drops a backslash before an end-of-line', () {
      expect(decodePdfLiteral('ab\\\ncd'), 'abcd');
      expect(decodePdfLiteral('ab\\\rcd'), 'abcd');
      expect(decodePdfLiteral('ab\\\r\ncd'), 'abcd');
    });

    test('normalizes unescaped end-of-line markers to LF', () {
      expect(decodePdfLiteral('a\r\nb\rc\nd'), 'a\nb\nc\nd');
    });

    test('ignores a backslash before an unknown character', () {
      expect(decodePdfLiteral(r'\q'), 'q');
    });

    test('ignores a trailing lone backslash', () {
      expect(decodePdfLiteral('ab\\'), 'ab');
    });

    test('keeps nested parentheses', () {
      expect(decodePdfLiteral('a (b) c'), 'a (b) c');
    });

    test('decodes UTF-16BE after a BOM, including surrogate pairs', () {
      expect(decodePdfLiteral(r'\376\377\000A\000B'), 'AB');
      expect(
        decodePdfLiteral('\xFE\xFF\xD8\x3D\xDE\x00'),
        '\u{1F600}',
      );
    });

    test('drops an odd trailing byte of UTF-16BE text', () {
      expect(decodePdfLiteral('\xFE\xFF\x00A\x00'), 'A');
    });

    test('decodes UTF-8 after a BOM', () {
      expect(decodePdfLiteral('\xEF\xBB\xBFcaf\xC3\xA9'), 'café');
    });

    test('falls back to Latin-1 without a BOM', () {
      expect(decodePdfLiteral(r'caf\351'), 'café');
    });

    test('rejects code units above 0xFF', () {
      expect(() => decodePdfLiteral('Ā'), throwsFormatException);
    });
  });

  group('decodePdfHex', () {
    test('decodes hex digits and ignores whitespace', () {
      expect(decodePdfHex('41 42\n43'), 'ABC');
      expect(decodePdfHex('616263'), 'abc');
    });

    test('pads a trailing odd nibble with zero', () {
      expect(decodePdfHex('414'), 'A@');
    });

    test('decodes UTF-16BE after a BOM', () {
      expect(decodePdfHex('FEFF00410042'), 'AB');
    });

    test('decodes UTF-8 after a BOM', () {
      expect(decodePdfHex('EFBBBF636166C3A9'), 'café');
    });

    test('decodes an empty string', () {
      expect(decodePdfHex(''), '');
    });

    test('rejects non-hex characters', () {
      expect(() => decodePdfHex('4G'), throwsFormatException);
    });
  });
}
