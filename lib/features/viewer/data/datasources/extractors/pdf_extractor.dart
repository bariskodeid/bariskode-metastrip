import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/core/processing/pdf_info_locator.dart';
import 'package:metastrip/core/processing/pdf_string_decoder.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Keys extracted from the PDF document Info dictionary.
const List<String> _infoKeys = [
  'Title',
  'Author',
  'Subject',
  'Keywords',
  'Creator',
  'Producer',
  'CreationDate',
  'ModDate',
  'Trapped',
];

/// Extracts PDF metadata from raw [bytes] using a lightweight pure-Dart scan.
///
/// Reads the document Info dictionary referenced from the trailer (inline or
/// indirect) and any XMP packet embedded in the file. An Info dictionary that
/// cannot be read is reported as a status field next to the XMP packet.
/// Returns a single status field when the bytes are not a valid PDF, when no
/// metadata is found, or when parsing fails; this function never throws.
Future<List<MetadataFieldEntity>> extractPdf(Uint8List bytes) async {
  try {
    if (!_hasPdfSignature(bytes)) {
      return [statusField('PDF Document', 'Status', 'Not a valid PDF')];
    }

    final content = latin1.decode(bytes);
    final fields = <MetadataFieldEntity>[
      ..._extractInfoFields(content),
      ..._extractXmpFields(content),
    ];

    if (fields.isEmpty) {
      return [
        statusField('PDF Document', 'Status', 'No PDF metadata found'),
      ];
    }

    return fields;
  } catch (_) {
    return [
      statusField('PDF Document', 'Status', 'Unable to parse PDF metadata'),
    ];
  }
}

/// Returns whether [bytes] starts with the `%PDF-` header marker.
bool _hasPdfSignature(Uint8List bytes) {
  const header = [0x25, 0x50, 0x44, 0x46, 0x2D]; // '%PDF-'
  if (bytes.length < header.length) return false;
  for (var i = 0; i < header.length; i++) {
    if (bytes[i] != header[i]) return false;
  }
  return true;
}

/// Status value reported when the Info dictionary cannot be read safely.
const String _infoStatus = 'Unable to parse PDF Info dictionary';

/// Extracts the fields of the document Info dictionary that the trailer (or
/// a cross-reference stream) points at, across all revisions.
///
/// Each known key shows its effective value: the entry at the highest file
/// offset wins, which is the one written by the latest incremental update.
/// Returns an empty list when no trailer references an Info dictionary, and
/// a single status field when the Info dictionary or a selected value cannot
/// be read, for example when it lives in a compressed object stream.
List<MetadataFieldEntity> _extractInfoFields(String content) {
  try {
    final values = _readEffectiveInfoValues(content);
    return [
      for (final key in _infoKeys)
        if (values[key] case final value?)
          MetadataFieldEntity(
            section: 'PDF Document',
            label: key,
            value: truncateMetadataValue(value),
            id: MetadataFieldId.pdfInfoIdsByKey[key],
            isPrivacySensitive: isTextPrivacySensitive(key),
          ),
    ];
  } on FormatException {
    return [statusField('PDF Document', 'Status', _infoStatus)];
  }
}

/// Decoded effective value of every known Info key in latin-1 [text].
///
/// Every Info dictionary is parsed so a malformed revision fails closed. An
/// indirect `N G R` value must resolve to objects that are each a single
/// string, the same rule the remover enforces; its latest definition is
/// shown. Throws a [FormatException] for anything else.
Map<String, String> _readEffectiveInfoValues(String text) {
  final effective = <String, PdfDictionaryEntry>{};
  for (final dictionary in locatePdfInfoDictionaries(text)) {
    for (final entry in readPdfDictionaryEntries(text, dictionary)) {
      if (_infoKeys.contains(entry.key)) effective[entry.key] = entry;
    }
  }

  final references = <String, PdfObjectRef>{};
  final values = <String, String>{};
  for (final MapEntry(:key, value: entry) in effective.entries) {
    final reference = parsePdfReferenceAt(text, entry.valueStart);
    if (reference != null && reference.end == entry.valueEnd) {
      references[key] = reference.ref;
    } else {
      values[key] = _decodeValue(text, entry.valueStart, entry.valueEnd);
    }
  }
  if (references.isEmpty) return values;

  final bodies = findPdfObjectBodiesFor(text, references.values.toSet());
  for (final MapEntry(:key, value: reference) in references.entries) {
    final definitions = bodies[reference]!;
    if (definitions.isEmpty) {
      throw const FormatException('Unresolvable indirect PDF Info value');
    }
    final decoded = [
      for (final body in definitions) _decodeIndirectString(text, body),
    ];
    values[key] = decoded.last;
  }
  return values;
}

/// Decodes the direct value occupying `[start, end)` of [text].
///
/// Strings are decoded with BOM-aware PDF text rules, a name loses its
/// leading slash, and any other token (such as `true`) is shown verbatim.
String _decodeValue(String text, int start, int end) {
  if (text.startsWith('(', start)) {
    return decodePdfLiteral(text.substring(start + 1, end - 1));
  }
  if (text.startsWith('<', start) && !text.startsWith('<<', start)) {
    return decodePdfHex(text.substring(start + 1, end - 1));
  }
  if (text.startsWith('/', start)) return text.substring(start + 1, end);
  return text.substring(start, end);
}

/// Decodes the object [body] referenced by an indirect Info value, which
/// must hold exactly one literal or hex string.
String _decodeIndirectString(String text, PdfTextRange body) {
  final start = _skipPdfWhitespace(text, body.start, body.end);
  final isString = text.startsWith('(', start) ||
      (text.startsWith('<', start) && !text.startsWith('<<', start));
  final end = isString ? findPdfValueEnd(text, start) : null;
  if (end == null ||
      end > body.end ||
      _skipPdfWhitespace(text, end, body.end) != body.end) {
    throw const FormatException('Indirect PDF Info value is not a string');
  }
  return _decodeValue(text, start, end);
}

/// First offset in `[start, limit)` of [text] that is not PDF whitespace,
/// or [limit] when there is none.
int _skipPdfWhitespace(String text, int start, int limit) {
  var index = start;
  while (index < limit) {
    final unit = text.codeUnitAt(index);
    if (unit != 0x00 &&
        unit != 0x09 &&
        unit != 0x0A &&
        unit != 0x0C &&
        unit != 0x0D &&
        unit != 0x20) {
      break;
    }
    index++;
  }
  return index;
}

/// Extracts an XMP packet field when an `<?xpacket` marker is present.
///
/// The captured value runs from the opening marker to the closing `?>` of the
/// `<?xpacket end` declaration, or to the end of the content when the closing
/// marker is missing.
List<MetadataFieldEntity> _extractXmpFields(String content) {
  final start = content.indexOf('<?xpacket');
  if (start < 0) return const <MetadataFieldEntity>[];

  var end = content.length;
  final endMarker = content.indexOf('<?xpacket end', start);
  if (endMarker >= 0) {
    final closing = content.indexOf('?>', endMarker);
    if (closing >= 0) end = closing + 2;
  }

  return [
    MetadataFieldEntity(
      section: 'PDF Document',
      label: 'XMP Packet',
      value: truncateMetadataValue(content.substring(start, end)),
    ),
  ];
}
