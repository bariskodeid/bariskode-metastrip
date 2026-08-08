/// Maximum number of PDF Info key candidates processed in one scrub or
/// generated-byte validation pass.
const maxPdfInfoValueOccurrences = 4096;

/// Shared aggregate budget for bounded PDF Info scans.
final class PdfInfoOccurrenceBudget {
  var _count = 0;

  /// Records one key candidate or fails closed at the limit.
  void record() {
    _count++;
    if (_count > maxPdfInfoValueOccurrences) {
      throw const FormatException('Too many PDF Info value occurrences');
    }
  }
}

/// Half-open byte range occupied by a PDF Info value's mutable content.
final class PdfInfoValueRange {
  const PdfInfoValueRange(
    this.start,
    this.end,
    this.nextSearchOffset, {
    this.replacementAtStart,
  });

  final int start;
  final int end;
  final int nextSearchOffset;

  /// Optional byte written at [start] after the rest of the range is blanked.
  final int? replacementAtStart;
}

/// Parses the supported value following a PDF Info key ending at [keyEnd].
///
/// Literal strings use balanced-parenthesis parsing. Backslash escapes consume
/// the following byte, so escaped parentheses and backslashes do not affect
/// nesting depth. Hex strings and bare/name tokens retain the scrubber's
/// narrow existing behavior.
PdfInfoValueRange? parsePdfInfoValueRange(String text, int keyEnd) {
  var start = keyEnd;
  while (start < text.length && isPdfWhitespace(text.codeUnitAt(start))) {
    start++;
  }
  if (start >= text.length) return null;

  final unit = text.codeUnitAt(start);
  if (unit == 0x28) {
    var depth = 1;
    var end = start + 1;
    while (end < text.length) {
      final value = text.codeUnitAt(end);
      if (value == 0x5C) {
        if (end + 1 >= text.length) return null;
        end += 2;
      } else if (value == 0x28) {
        depth++;
        end++;
      } else if (value == 0x29) {
        depth--;
        if (depth == 0) {
          return PdfInfoValueRange(start + 1, end, end + 1);
        }
        end++;
      } else {
        end++;
      }
    }
    return null;
  }

  if (unit == 0x3C) {
    if (start + 1 < text.length && text.codeUnitAt(start + 1) == 0x3C) {
      return null;
    }
    final end = text.indexOf('>', start + 1);
    return end < 0 ? null : PdfInfoValueRange(start + 1, end, end + 1);
  }

  if (unit == 0x2F) {
    var end = start + 1;
    while (end < text.length && isPdfInfoNameChar(text.codeUnitAt(end))) {
      end++;
    }
    return end == start + 1
        ? null
        : PdfInfoValueRange(
            start + 1,
            end,
            end,
            replacementAtStart: 0x58,
          );
  }

  if (!isPdfTokenChar(unit)) return null;
  var end = start;
  while (end < text.length && isPdfTokenChar(text.codeUnitAt(end))) {
    end++;
  }
  return PdfInfoValueRange(start, end, end);
}

/// Whether [unit] is a PDF whitespace byte.
bool isPdfWhitespace(int unit) =>
    unit == 0x00 ||
    unit == 0x09 ||
    unit == 0x0A ||
    unit == 0x0C ||
    unit == 0x0D ||
    unit == 0x20;

/// Whether [unit] extends a PDF name after its leading slash.
bool isPdfInfoNameChar(int unit) =>
    !isPdfWhitespace(unit) && !isPdfDelimiter(unit);

/// Whether [unit] is one of the PDF lexical delimiters.
bool isPdfDelimiter(int unit) => switch (unit) {
      0x28 || // (
      0x29 || // )
      0x3C || // <
      0x3E || // >
      0x5B || // [
      0x5D || // ]
      0x7B || // {
      0x7D || // }
      0x2F || // /
      0x25 => // %
        true,
      _ => false,
    };

/// Whether [unit] belongs to the conservative PDF value-token subset.
bool isPdfTokenChar(int unit) {
  return !isPdfWhitespace(unit) && !isPdfDelimiter(unit);
}
