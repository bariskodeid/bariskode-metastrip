import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
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
/// Reads the document Info dictionary (via direct or indirect references) and
/// any XMP packet embedded in the file. Returns a single status field when the
/// bytes are not a valid PDF, when no metadata is found, or when parsing
/// fails; this function never throws.
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

/// Maximum number of `N 0 obj ... endobj` regions scanned for the Info
/// dictionary. A hostile PDF can carry thousands of object headers; capping
/// the scan keeps extraction linear even when few regions are useful.
const int _maxPdfObjectRegions = 64;

/// Upper bound on the distance between an `obj` object header and its
/// `endobj` terminator. A header without a terminator inside this window is
/// treated as malformed and the scan stops instead of searching the whole
/// document.
const int _maxPdfRegionBytes = 1024 * 1024;

/// Extracts Info dictionary entries by scanning `N 0 obj ... endobj` regions.
///
/// Resolves `/Info M 0 R` indirect references and also accepts an Info
/// dictionary declared directly inside an object body. Returns an empty list
/// when no `/Info` reference is found.
List<MetadataFieldEntity> _extractInfoFields(String content) {
  final headerPattern = RegExp(r'(\d+)\s+0\s+obj');
  final regions = <int, String>{};
  var cursor = 0;
  while (regions.length < _maxPdfObjectRegions) {
    final matches = headerPattern.allMatches(content, cursor);
    final iterator = matches.iterator;
    if (!iterator.moveNext()) break;
    final header = iterator.current;
    final regionStart = header.end;
    final windowEnd = regionStart + _maxPdfRegionBytes < content.length
        ? regionStart + _maxPdfRegionBytes
        : content.length;
    final endObj = content.indexOf('endobj', regionStart);
    if (endObj < 0 || endObj > windowEnd) break;
    regions[int.parse(header.group(1)!)] =
        content.substring(regionStart, endObj);
    cursor = endObj + 6; // advance past 'endobj'
  }
  if (regions.isEmpty) return const <MetadataFieldEntity>[];

  const directPattern = r'/Info\s*<<([\s\S]*?)>>';
  const indirectPattern = r'/Info\s+(\d+)\s+0\s+R';

  for (final body in regions.values) {
    final direct = RegExp(directPattern).firstMatch(body);
    if (direct != null) {
      return _parseInfoDictionary(direct.group(1)!);
    }

    final indirect = RegExp(indirectPattern).firstMatch(body);
    if (indirect != null) {
      final target = regions[int.parse(indirect.group(1)!)];
      if (target != null) {
        final dictionary = RegExp(r'<<([\s\S]*?)>>').firstMatch(target);
        if (dictionary != null) {
          return _parseInfoDictionary(dictionary.group(1)!);
        }
      }
    }
  }

  return const <MetadataFieldEntity>[];
}

/// Extracts fields for every known Info key present in [dictionaryBody].
///
/// Values may be literal strings, hex strings, or plain tokens; only the
/// recognized keys are surfaced, each flagged by [isTextPrivacySensitive].
List<MetadataFieldEntity> _parseInfoDictionary(String dictionaryBody) {
  final fields = <MetadataFieldEntity>[];
  for (final key in _infoKeys) {
    final value = _readDictionaryValue(dictionaryBody, key);
    if (value == null) continue;
    fields.add(
      MetadataFieldEntity(
        section: 'PDF Document',
        label: key,
        value: truncateMetadataValue(value),
        isPrivacySensitive: isTextPrivacySensitive(key),
      ),
    );
  }
  return fields;
}

/// Reads a single value for [key] from an Info dictionary body.
///
/// Supports literal strings `(text)`, hex strings `<...>`, and bare data
/// tokens (such as `true`). Returns null when the key is absent.
String? _readDictionaryValue(String body, String key) {
  const valuePattern = r'((?:\((?:\\.|[^\\()])*\))|<[0-9A-Fa-f\s]*>'
      r'|[^\s/<]+)';
  final match = RegExp('/$key\\s*$valuePattern').firstMatch(body);
  if (match == null) return null;

  final raw = match.group(1)!;
  if (raw.startsWith('(')) return _decodeLiteralString(raw);
  if (raw.startsWith('<')) return _decodeHexString(raw);
  return raw;
}

/// Decodes a PDF literal string, resolving escape sequences.
String _decodeLiteralString(String raw) {
  final buffer = StringBuffer();
  var index = 1; // skip opening paren
  final end = raw.length - 1; // skip closing paren
  while (index < end) {
    final char = raw[index];
    if (char == r'\' && index + 1 < end) {
      final next = raw[index + 1];
      final replacement = switch (next) {
        'n' => '\n',
        'r' => '\r',
        't' => '\t',
        'b' => '\b',
        'f' => '\f',
        '(' => '(',
        ')' => ')',
        r'\' => r'\',
        _ => next,
      };
      buffer.write(replacement);
      index += 2;
    } else {
      buffer.write(char);
      index++;
    }
  }
  return buffer.toString();
}

/// Decodes a PDF hex string such as `<48656C6C6F>` to latin-1 text.
///
/// Whitespace inside the string is ignored and a trailing odd nibble is
/// padded with a zero as permitted by the PDF specification.
String _decodeHexString(String raw) {
  final digits = raw.substring(1, raw.length - 1).replaceAll(RegExp(r'\s'), '');
  if (digits.isEmpty) return '';
  final padded = digits.length.isOdd ? '${digits}0' : digits;
  final bytes = <int>[];
  for (var i = 0; i < padded.length; i += 2) {
    bytes.add(int.parse(padded.substring(i, i + 2), radix: 16));
  }
  return latin1.decode(bytes);
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