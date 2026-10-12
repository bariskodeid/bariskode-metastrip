/// Decodes PDF literal and hex strings into display text.
///
/// Both decoders first turn the string syntax into bytes, then interpret the
/// bytes as a PDF text string: UTF-16BE after an `FE FF` byte order mark,
/// UTF-8 after an `EF BB BF` mark, and otherwise PDFDocEncoding, which is
/// approximated here by Latin-1.
///
/// Inputs are latin-1 decoded PDF text, so each code unit is one byte. Both
/// decoders run in one forward pass with no regular expressions.
library;

import 'dart:convert';

/// Decodes the content of a PDF literal string, [rawBetweenParens] being the
/// text between its outer `(` and `)`.
///
/// Resolves the escapes `\n \r \t \b \f \( \) \\`, octal escapes `\ddd` of
/// one to three digits (overflow beyond one byte is ignored), and line
/// continuations (a backslash before an end-of-line marker). An unescaped
/// `CR` or `CR LF` becomes `LF`. A backslash before any other character is
/// dropped. Balanced nested parentheses are kept as-is.
///
/// Throws a [FormatException] when a code unit is above `0xFF`, which means
/// the input was not latin-1 decoded PDF text.
String decodePdfLiteral(String rawBetweenParens) {
  final raw = rawBetweenParens;
  final bytes = <int>[];
  var index = 0;
  while (index < raw.length) {
    final unit = _byteAt(raw, index);
    if (unit == _carriageReturn) {
      bytes.add(_lineFeed);
      index = _skipLineFeedAfterCr(raw, index + 1);
      continue;
    }
    if (unit != _backslash) {
      bytes.add(unit);
      index++;
      continue;
    }
    index++;
    if (index >= raw.length) break;
    final escaped = _byteAt(raw, index);
    if (_isOctalDigit(escaped)) {
      var value = 0;
      var digits = 0;
      while (digits < 3 &&
          index < raw.length &&
          _isOctalDigit(_byteAt(raw, index))) {
        value = value * 8 + (_byteAt(raw, index) - 0x30);
        digits++;
        index++;
      }
      bytes.add(value & 0xFF);
      continue;
    }
    index++;
    switch (escaped) {
      case 0x6E: // n
        bytes.add(_lineFeed);
      case 0x72: // r
        bytes.add(_carriageReturn);
      case 0x74: // t
        bytes.add(0x09);
      case 0x62: // b
        bytes.add(0x08);
      case 0x66: // f
        bytes.add(0x0C);
      case _carriageReturn:
        index = _skipLineFeedAfterCr(raw, index);
      case _lineFeed:
        break;
      default:
        // `\(`, `\)`, `\\`, and unknown escapes all yield the character.
        bytes.add(escaped);
    }
  }
  return _decodeTextBytes(bytes);
}

/// Decodes the content of a PDF hex string, [rawBetweenAngles] being the
/// text between its `<` and `>`.
///
/// Whitespace is ignored and a trailing odd nibble is padded with zero, as
/// the PDF specification allows.
///
/// Throws a [FormatException] when any other character is not a hex digit.
String decodePdfHex(String rawBetweenAngles) {
  final bytes = <int>[];
  int? high;
  for (var index = 0; index < rawBetweenAngles.length; index++) {
    final unit = rawBetweenAngles.codeUnitAt(index);
    if (_isWhitespace(unit)) continue;
    final nibble = _hexValue(unit);
    if (nibble < 0) {
      throw const FormatException('Invalid PDF hex string');
    }
    if (high == null) {
      high = nibble;
    } else {
      bytes.add(high << 4 | nibble);
      high = null;
    }
  }
  if (high != null) bytes.add(high << 4);
  return _decodeTextBytes(bytes);
}

const _backslash = 0x5C;
const _carriageReturn = 0x0D;
const _lineFeed = 0x0A;

/// Interprets [bytes] as a PDF text string, honoring a leading BOM.
String _decodeTextBytes(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    final units = <int>[];
    for (var index = 2; index + 1 < bytes.length; index += 2) {
      units.add(bytes[index] << 8 | bytes[index + 1]);
    }
    return String.fromCharCodes(units);
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  return latin1.decode(bytes);
}

/// The byte at [index] of latin-1 decoded [text].
int _byteAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit > 0xFF) {
    throw const FormatException('PDF string is not latin-1 decoded text');
  }
  return unit;
}

/// Offset past an optional `LF` at [index], which follows a `CR`.
int _skipLineFeedAfterCr(String text, int index) =>
    index < text.length && text.codeUnitAt(index) == _lineFeed
        ? index + 1
        : index;

bool _isOctalDigit(int unit) => unit >= 0x30 && unit <= 0x37;

bool _isWhitespace(int unit) =>
    unit == 0x00 ||
    unit == 0x09 ||
    unit == 0x0A ||
    unit == 0x0C ||
    unit == 0x0D ||
    unit == 0x20;

/// The value of hex digit [unit], or -1 when it is not one.
int _hexValue(int unit) {
  if (unit >= 0x30 && unit <= 0x39) return unit - 0x30;
  if (unit >= 0x41 && unit <= 0x46) return unit - 0x41 + 10;
  if (unit >= 0x61 && unit <= 0x66) return unit - 0x61 + 10;
  return -1;
}
