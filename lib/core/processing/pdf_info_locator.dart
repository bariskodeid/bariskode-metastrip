/// Locates PDF document Info dictionaries in latin-1 decoded PDF text.
///
/// Every scan here is a forward `String.indexOf` walk with no regular
/// expressions. Look-behind never crosses the previous keyword hit and each
/// skipped region is visited once, so hostile input is processed in linear
/// time. Positions are code-unit offsets, which equal byte offsets when the
/// text was decoded with `latin1`.
///
/// Only plain-text PDF syntax is understood. Objects stored inside
/// compressed object streams are not visible, so an Info reference whose
/// object lives in one is rejected with a [FormatException]. Keywords are
/// matched without excluding content streams or literal strings, so such
/// text can also make a valid PDF fail safe (see `_scanTrailers`).
library;

/// Half-open range `[start, end)` of code units in PDF text.
class PdfTextRange {
  /// Creates the range `[start, end)`.
  const PdfTextRange(this.start, this.end);

  /// Offset of the first code unit in the range.
  final int start;

  /// Offset just past the last code unit in the range.
  final int end;

  @override
  bool operator ==(Object other) =>
      other is PdfTextRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PdfTextRange($start, $end)';
}

/// An indirect object reference `number generation R`.
class PdfObjectRef {
  /// Creates the reference `number generation R`.
  const PdfObjectRef(this.number, this.generation);

  /// The object number.
  final int number;

  /// The generation number.
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is PdfObjectRef &&
      other.number == number &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(number, generation);

  @override
  String toString() => '$number $generation R';
}

/// One top-level `/Key value` entry of a PDF dictionary.
class PdfDictionaryEntry {
  /// Creates an entry whose key and value occupy the given offsets.
  const PdfDictionaryEntry({
    required this.key,
    required this.keyStart,
    required this.valueStart,
    required this.valueEnd,
  });

  /// The key name without its leading slash (`#xx` escapes are not decoded).
  final String key;

  /// Offset of the key's leading `/`.
  final int keyStart;

  /// Offset of the first code unit of the value.
  final int valueStart;

  /// Offset just past the value (for `N G R`, just past the `R`).
  final int valueEnd;
}

/// Ranges of every Info dictionary body (`<<`..`>>`, exclusive) reachable
/// from `/Info` in any trailer or xref-stream dictionary, all revisions.
///
/// Sources are classic `trailer << ... >>` dictionaries and the dictionaries
/// of `/Type /XRef` cross-reference stream objects; an `/Info` key anywhere
/// else is ignored. Each source may hold an indirect `/Info N G R` reference,
/// which resolves to every plain-text definition of that object (incremental
/// updates redefine it), or an inline `/Info << ... >>` dictionary. The
/// result is sorted by offset and holds each range once.
///
/// Throws a [FormatException] when a trailer, cross-reference stream, or
/// Info dictionary is malformed, when an Info object is not a dictionary, or
/// when an `/Info` reference has no plain-text definition (for example it
/// lives in a compressed object stream), so the caller never silently skips
/// an Info dictionary it cannot clean.
List<PdfTextRange> locatePdfInfoDictionaries(String latin1Text) {
  final text = latin1Text;
  final references = <PdfObjectRef>{};
  final ranges = <PdfTextRange>{};

  void collect(_PdfDictionary dictionary) {
    for (final entry in dictionary.entries) {
      if (entry.key != 'Info') continue;
      final reference = parsePdfReferenceAt(text, entry.valueStart);
      if (reference != null && reference.end == entry.valueEnd) {
        references.add(reference.ref);
      } else if (text.startsWith('<<', entry.valueStart)) {
        ranges.add(PdfTextRange(entry.valueStart + 2, entry.valueEnd - 2));
      } else {
        throw const FormatException('Malformed PDF Info reference');
      }
    }
  }

  _scanTrailers(text, collect);
  _scanXrefStreams(text, collect);

  final bodies = findPdfObjectBodiesFor(text, references);
  for (final reference in references) {
    final definitions = bodies[reference]!;
    if (definitions.isEmpty) {
      throw const FormatException(
        'PDF Info dictionary is not stored as plain text (compressed '
        'object streams are not supported)',
      );
    }
    for (final body in definitions) {
      final open = _skipWhitespaceAndComments(text, body.start);
      if (!text.startsWith('<<', open)) {
        throw const FormatException('PDF Info object is not a dictionary');
      }
      final dictionary = _scanDictionary(text, open);
      if (dictionary.end > body.end) {
        throw const FormatException('Malformed PDF Info dictionary');
      }
      ranges.add(PdfTextRange(open + 2, dictionary.end - 2));
    }
  }
  return ranges.toList()
    ..sort((left, right) => left.start.compareTo(right.start));
}

/// Body range of every definition of object `number generation obj` (all
/// revisions). A body spans from just after `obj` to the next `endobj`.
///
/// Throws a [FormatException] when a matching object has no `endobj`.
List<PdfTextRange> findPdfObjectBodies(
  String latin1Text,
  int number,
  int generation,
) {
  final reference = PdfObjectRef(number, generation);
  return findPdfObjectBodiesFor(latin1Text, {reference})[reference]!;
}

/// Resolves every reference in [references] in one linear pass, mapping each
/// to the body ranges of its definitions (empty when it is not defined).
///
/// Object headers inside a matched body are ignored. Throws a
/// [FormatException] when a matching object has no `endobj`.
Map<PdfObjectRef, List<PdfTextRange>> findPdfObjectBodiesFor(
  String latin1Text,
  Set<PdfObjectRef> references,
) {
  final text = latin1Text;
  final result = {
    for (final reference in references) reference: <PdfTextRange>[],
  };
  if (references.isEmpty) return result;
  var from = 0;
  while (true) {
    final hit = text.indexOf('obj', from);
    if (hit < 0) break;
    final after = hit + 3;
    from = after;
    if (after < text.length && _isRegular(text.codeUnitAt(after))) continue;
    final reference = _objectHeaderBefore(text, hit);
    if (reference == null) continue;
    final bodies = result[reference];
    if (bodies == null) continue;
    final end = text.indexOf('endobj', after);
    if (end < 0) {
      throw const FormatException('Unterminated PDF object');
    }
    bodies.add(PdfTextRange(after, end));
    from = end + 6;
  }
  return result;
}

/// Top-level entries of the dictionary whose body is [body] (the range
/// between its `<<` and `>>`, as returned by [locatePdfInfoDictionaries]).
///
/// Nested dictionaries, arrays, and strings are skipped as single values.
/// Throws a [FormatException] when the dictionary is malformed.
List<PdfDictionaryEntry> readPdfDictionaryEntries(
  String latin1Text,
  PdfTextRange body,
) {
  final open = body.start - 2;
  if (open < 0 || !latin1Text.startsWith('<<', open)) {
    throw const FormatException('Not a PDF dictionary');
  }
  final dictionary = _scanDictionary(latin1Text, open);
  if (dictionary.end != body.end + 2) {
    throw const FormatException('Malformed PDF dictionary');
  }
  return dictionary.entries;
}

/// Parses an indirect reference `N G R` starting exactly at [start].
///
/// Returns the reference and the offset just past `R`, or null when the text
/// at [start] is not a reference (for example a plain number).
({PdfObjectRef ref, int end})? parsePdfReferenceAt(String text, int start) {
  var index = start;
  while (index < text.length && _isDigit(text.codeUnitAt(index))) {
    index++;
  }
  final numberEnd = index;
  if (numberEnd == start || numberEnd - start > _maxObjectNumberDigits) {
    return null;
  }
  if (index >= text.length || !_isWhitespace(text.codeUnitAt(index))) {
    return null;
  }
  while (index < text.length && _isWhitespace(text.codeUnitAt(index))) {
    index++;
  }
  final generationStart = index;
  while (index < text.length && _isDigit(text.codeUnitAt(index))) {
    index++;
  }
  final generationEnd = index;
  if (generationEnd == generationStart ||
      generationEnd - generationStart > _maxGenerationDigits) {
    return null;
  }
  if (index >= text.length || !_isWhitespace(text.codeUnitAt(index))) {
    return null;
  }
  while (index < text.length && _isWhitespace(text.codeUnitAt(index))) {
    index++;
  }
  if (index >= text.length || text.codeUnitAt(index) != 0x52) return null;
  index++;
  if (index < text.length && _isRegular(text.codeUnitAt(index))) return null;
  return (
    ref: PdfObjectRef(
      int.parse(text.substring(start, numberEnd)),
      int.parse(text.substring(generationStart, generationEnd)),
    ),
    end: index,
  );
}

/// Offset just past the single value (string, name, token, reference, array,
/// or dictionary) starting exactly at [start], or null when the value is
/// malformed or no value starts there.
///
/// Uses the same value syntax as [readPdfDictionaryEntries].
int? findPdfValueEnd(String latin1Text, int start) {
  final end = _skipValue(latin1Text, start);
  return end < 0 ? null : end;
}

/// The range of the single literal or hex string that forms the whole object
/// [body] of [latin1Text], excluding surrounding whitespace.
///
/// This is the one rule for what an indirect Info value (`/Title 12 0 R`)
/// may resolve to. Throws a [FormatException] for any other body, including
/// a name, number, array, dictionary, several values, or a malformed string.
PdfTextRange findPdfIndirectStringRange(
  String latin1Text,
  PdfTextRange body,
) {
  var start = body.start;
  while (start < body.end && _isWhitespace(latin1Text.codeUnitAt(start))) {
    start++;
  }
  final isString = start < body.end &&
      (latin1Text.codeUnitAt(start) == 0x28 ||
          (latin1Text.codeUnitAt(start) == 0x3C &&
              !latin1Text.startsWith('<<', start)));
  final end = isString ? findPdfValueEnd(latin1Text, start) : null;
  if (end == null || end > body.end) {
    throw const FormatException('Indirect PDF Info value is not a string');
  }
  var after = end;
  while (after < body.end && _isWhitespace(latin1Text.codeUnitAt(after))) {
    after++;
  }
  if (after != body.end) {
    throw const FormatException('Indirect PDF Info value is not a string');
  }
  return PdfTextRange(start, end);
}

const _maxObjectNumberDigits = 10;
const _maxGenerationDigits = 5;

/// Feeds the dictionary after every `trailer` keyword to [collect].
///
/// Known limitation: the keyword is matched anywhere in the text, including
/// inside uncompressed content streams and literal strings. Text such as
/// `(trailer << x)` then makes [_scanDictionary] throw, so a valid PDF is
/// rejected (fails safe: no output, or an "Unable to parse" viewer status).
void _scanTrailers(String text, void Function(_PdfDictionary) collect) {
  const keyword = 'trailer';
  var from = 0;
  while (true) {
    final hit = text.indexOf(keyword, from);
    if (hit < 0) break;
    final end = hit + keyword.length;
    from = end;
    if (hit > 0 && _isRegular(text.codeUnitAt(hit - 1))) continue;
    if (end < text.length && _isRegular(text.codeUnitAt(end))) continue;
    final open = _skipWhitespaceAndComments(text, end);
    // Any keyword hit before [open] sits in skipped whitespace or comments.
    from = open;
    if (!text.startsWith('<<', open)) continue;
    final dictionary = _scanDictionary(text, open);
    collect(dictionary);
    from = dictionary.end;
  }
}

/// Feeds the dictionary of every `/Type /XRef` stream object to [collect].
///
/// `/XRef` names and object headers are both walked forward, so each `/Type
/// /XRef` hit is matched with the nearest preceding object header without
/// any backward search. Each object dictionary is scanned at most once and
/// hits inside an already scanned dictionary are skipped, keeping the pass
/// linear. Like [_scanTrailers], hits inside uncompressed content streams or
/// literal strings are not excluded and can make a valid PDF fail safe.
void _scanXrefStreams(String text, void Function(_PdfDictionary) collect) {
  const name = '/XRef';
  var pendingObj = text.indexOf('obj');
  var headerEnd = -1;
  var examinedHeaderEnd = -1;
  var scannedUntil = 0;
  var from = 0;
  while (true) {
    final hit = text.indexOf(name, from);
    if (hit < 0) break;
    final nameEnd = hit + name.length;
    from = nameEnd;
    if (hit < scannedUntil) continue;
    if (nameEnd < text.length && _isRegular(text.codeUnitAt(nameEnd))) {
      continue;
    }
    var typeEnd = hit;
    while (typeEnd > 0 && _isWhitespace(text.codeUnitAt(typeEnd - 1))) {
      typeEnd--;
    }
    final typeStart = typeEnd - 5;
    if (typeStart < 0 || !text.startsWith('/Type', typeStart)) continue;

    while (pendingObj >= 0 && pendingObj + 3 <= typeStart) {
      final after = pendingObj + 3;
      if ((after >= text.length || !_isRegular(text.codeUnitAt(after))) &&
          _objectHeaderBefore(text, pendingObj) != null) {
        headerEnd = after;
      }
      pendingObj = text.indexOf('obj', after);
    }
    if (headerEnd < 0 || headerEnd == examinedHeaderEnd) continue;
    final open = _skipWhitespaceAndComments(text, headerEnd);
    if (open >= typeStart) {
      // The hit sits in whitespace or comments before the object's value.
      scannedUntil = open;
      continue;
    }
    examinedHeaderEnd = headerEnd;
    if (!text.startsWith('<<', open)) continue;
    final dictionary = _scanDictionary(text, open);
    scannedUntil = dictionary.end;
    final isXrefStream = dictionary.entries.any(
      (entry) =>
          entry.key == 'Type' &&
          text.startsWith(name, entry.valueStart) &&
          entry.valueStart + name.length == entry.valueEnd,
    );
    if (isXrefStream) collect(dictionary);
  }
}

/// Parses the `N G` preceding an `obj` keyword at [objStart], or returns
/// null when the keyword is not an object header.
///
/// The walk back only crosses whitespace and digits, so it never passes the
/// previous `obj` keyword.
PdfObjectRef? _objectHeaderBefore(String text, int objStart) {
  var index = objStart - 1;
  if (index < 0 || !_isWhitespace(text.codeUnitAt(index))) return null;
  while (index >= 0 && _isWhitespace(text.codeUnitAt(index))) {
    index--;
  }
  final generationEnd = index + 1;
  while (index >= 0 && _isDigit(text.codeUnitAt(index))) {
    index--;
  }
  final generationStart = index + 1;
  if (generationStart == generationEnd ||
      generationEnd - generationStart > _maxGenerationDigits) {
    return null;
  }
  if (index < 0 || !_isWhitespace(text.codeUnitAt(index))) return null;
  while (index >= 0 && _isWhitespace(text.codeUnitAt(index))) {
    index--;
  }
  final numberEnd = index + 1;
  while (index >= 0 && _isDigit(text.codeUnitAt(index))) {
    index--;
  }
  final numberStart = index + 1;
  if (numberStart == numberEnd ||
      numberEnd - numberStart > _maxObjectNumberDigits) {
    return null;
  }
  if (index >= 0 && _isRegular(text.codeUnitAt(index))) return null;
  return PdfObjectRef(
    int.parse(text.substring(numberStart, numberEnd)),
    int.parse(text.substring(generationStart, generationEnd)),
  );
}

class _PdfDictionary {
  const _PdfDictionary(this.entries, this.end);

  final List<PdfDictionaryEntry> entries;

  /// Offset just past the closing `>>`.
  final int end;
}

/// Scans the dictionary opening with `<<` at [open] and returns its
/// top-level entries. Throws a [FormatException] when it is malformed.
_PdfDictionary _scanDictionary(String text, int open) {
  final entries = <PdfDictionaryEntry>[];
  var index = open + 2;
  while (true) {
    index = _skipWhitespaceAndComments(text, index);
    if (index >= text.length) {
      throw const FormatException('Unterminated PDF dictionary');
    }
    final unit = text.codeUnitAt(index);
    if (unit == 0x3E) {
      if (text.startsWith('>>', index)) {
        return _PdfDictionary(entries, index + 2);
      }
      throw const FormatException('Malformed PDF dictionary');
    }
    if (unit != 0x2F) {
      throw const FormatException('Malformed PDF dictionary key');
    }
    final keyStart = index;
    index++;
    while (index < text.length && _isRegular(text.codeUnitAt(index))) {
      index++;
    }
    final key = text.substring(keyStart + 1, index);
    final valueStart = _skipWhitespaceAndComments(text, index);
    final valueEnd = _skipValue(text, valueStart);
    if (valueEnd < 0) {
      throw const FormatException('Malformed PDF dictionary value');
    }
    entries.add(
      PdfDictionaryEntry(
        key: key,
        keyStart: keyStart,
        valueStart: valueStart,
        valueEnd: valueEnd,
      ),
    );
    index = valueEnd;
  }
}

/// Offset just past the single value at [start], or -1 when malformed.
int _skipValue(String text, int start) {
  if (start >= text.length) return -1;
  final reference = parsePdfReferenceAt(text, start);
  if (reference != null) return reference.end;
  final unit = text.codeUnitAt(start);
  if (unit == 0x28) return _skipLiteralString(text, start);
  if (unit == 0x3C) {
    if (text.startsWith('<<', start)) return _skipNested(text, start);
    final end = text.indexOf('>', start + 1);
    return end < 0 ? -1 : end + 1;
  }
  if (unit == 0x5B) return _skipNested(text, start);
  if (unit == 0x2F || _isRegular(unit)) {
    var end = start + 1;
    while (end < text.length && _isRegular(text.codeUnitAt(end))) {
      end++;
    }
    return end;
  }
  return -1;
}

/// Offset just past the balanced literal string opening at [start], or -1.
int _skipLiteralString(String text, int start) {
  var depth = 0;
  var index = start;
  while (index < text.length) {
    final unit = text.codeUnitAt(index);
    if (unit == 0x5C) {
      index += 2;
      continue;
    }
    if (unit == 0x28) {
      depth++;
    } else if (unit == 0x29) {
      depth--;
      if (depth == 0) return index + 1;
    }
    index++;
  }
  return -1;
}

/// Offset just past the dictionary or array opening at [start], or -1.
///
/// Uses a depth counter instead of recursion so deep nesting cannot overflow
/// the stack.
int _skipNested(String text, int start) {
  var depth = 0;
  var index = start;
  while (index < text.length) {
    final unit = text.codeUnitAt(index);
    switch (unit) {
      case 0x25: // %
        index = _skipComment(text, index);
        continue;
      case 0x28: // (
        index = _skipLiteralString(text, index);
        if (index < 0) return -1;
        continue;
      case 0x3C: // <
        if (text.startsWith('<<', index)) {
          depth++;
          index += 2;
        } else {
          final end = text.indexOf('>', index + 1);
          if (end < 0) return -1;
          index = end + 1;
        }
        continue;
      case 0x3E: // >
        if (!text.startsWith('>>', index)) return -1;
        depth--;
        index += 2;
        if (depth == 0) return index;
        if (depth < 0) return -1;
        continue;
      case 0x5B: // [
        depth++;
        index++;
        continue;
      case 0x5D: // ]
        depth--;
        index++;
        if (depth == 0) return index;
        if (depth < 0) return -1;
        continue;
      default:
        index++;
    }
  }
  return -1;
}

int _skipWhitespaceAndComments(String text, int start) {
  var index = start;
  while (index < text.length) {
    final unit = text.codeUnitAt(index);
    if (_isWhitespace(unit)) {
      index++;
    } else if (unit == 0x25) {
      index = _skipComment(text, index);
    } else {
      break;
    }
  }
  return index;
}

/// Offset of the end-of-line that terminates the comment at [start].
int _skipComment(String text, int start) {
  var index = start + 1;
  while (index < text.length) {
    final unit = text.codeUnitAt(index);
    if (unit == 0x0A || unit == 0x0D) break;
    index++;
  }
  return index;
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

bool _isWhitespace(int unit) =>
    unit == 0x00 ||
    unit == 0x09 ||
    unit == 0x0A ||
    unit == 0x0C ||
    unit == 0x0D ||
    unit == 0x20;

bool _isDelimiter(int unit) => switch (unit) {
      0x28 ||
      0x29 ||
      0x3C ||
      0x3E ||
      0x5B ||
      0x5D ||
      0x7B ||
      0x7D ||
      0x2F ||
      0x25 =>
        true,
      _ => false,
    };

/// Whether [unit] is a PDF regular character (part of a name or keyword).
bool _isRegular(int unit) => !_isWhitespace(unit) && !_isDelimiter(unit);
