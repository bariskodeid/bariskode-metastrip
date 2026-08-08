import 'dart:convert';

/// Stable identifier for a selectively removable metadata field.
///
/// PNG IDs reversibly contain the metadata keyword. They must not be logged,
/// persisted, or exported without appropriate redaction.
extension type const MetadataFieldId._(String value) {
  static const _pngPrefix = 'png.text.';
  static const _maxPngKeywordBytes = 79;
  static const _maxEncodedPngKeywordLength = 106;

  static const pdfInfoTitle = MetadataFieldId._('pdf.info.title');
  static const pdfInfoAuthor = MetadataFieldId._('pdf.info.author');
  static const pdfInfoSubject = MetadataFieldId._('pdf.info.subject');
  static const pdfInfoKeywords = MetadataFieldId._('pdf.info.keywords');
  static const pdfInfoCreator = MetadataFieldId._('pdf.info.creator');
  static const pdfInfoProducer = MetadataFieldId._('pdf.info.producer');
  static const pdfInfoCreationDate = MetadataFieldId._('pdf.info.creationDate');
  static const pdfInfoModDate = MetadataFieldId._('pdf.info.modDate');
  static const pdfInfoTrapped = MetadataFieldId._('pdf.info.trapped');

  static const Map<String, MetadataFieldId> _pdfIdsByValue = {
    'pdf.info.title': pdfInfoTitle,
    'pdf.info.author': pdfInfoAuthor,
    'pdf.info.subject': pdfInfoSubject,
    'pdf.info.keywords': pdfInfoKeywords,
    'pdf.info.creator': pdfInfoCreator,
    'pdf.info.producer': pdfInfoProducer,
    'pdf.info.creationDate': pdfInfoCreationDate,
    'pdf.info.modDate': pdfInfoModDate,
    'pdf.info.trapped': pdfInfoTrapped,
  };

  static const Map<String, MetadataFieldId> pdfInfoIdsByKey = {
    'Title': pdfInfoTitle,
    'Author': pdfInfoAuthor,
    'Subject': pdfInfoSubject,
    'Keywords': pdfInfoKeywords,
    'Creator': pdfInfoCreator,
    'Producer': pdfInfoProducer,
    'CreationDate': pdfInfoCreationDate,
    'ModDate': pdfInfoModDate,
    'Trapped': pdfInfoTrapped,
  };

  /// Creates a reversible ID from the exact, untruncated PNG text keyword.
  factory MetadataFieldId.pngText(String keyword) {
    final bytes = _validatedPngKeywordBytes(keyword);
    final encoded = base64Url.encode(bytes).replaceAll('=', '');
    return MetadataFieldId._('$_pngPrefix$encoded');
  }

  /// Parses and validates a stable field ID.
  factory MetadataFieldId.parse(String value) {
    final pdfId = _pdfIdsByValue[value];
    if (pdfId != null) return pdfId;
    if (!value.startsWith(_pngPrefix)) {
      throw const FormatException('Unsupported metadata field ID');
    }

    final encoded = value.substring(_pngPrefix.length);
    if (encoded.isEmpty ||
        encoded.length > _maxEncodedPngKeywordLength ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(encoded)) {
      throw const FormatException('Malformed PNG metadata field ID');
    }
    try {
      final padded = encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=');
      final keyword = latin1.decode(base64Url.decode(padded));
      final parsed = MetadataFieldId.pngText(keyword);
      if (parsed.value != value) {
        throw const FormatException('Non-canonical PNG metadata field ID');
      }
      return parsed;
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('Malformed PNG metadata field ID');
    }
  }

  bool get isPngText => value.startsWith(_pngPrefix);
  bool get isPdfInfo => _pdfIdsByValue.containsKey(value);

  String? get pngKeyword {
    if (!isPngText) return null;
    final encoded = value.substring(_pngPrefix.length);
    if (encoded.length > _maxEncodedPngKeywordLength) return null;
    final padded = encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=');
    return latin1.decode(base64Url.decode(padded));
  }

  String? get pdfInfoKey {
    for (final entry in pdfInfoIdsByKey.entries) {
      if (entry.value == this) return entry.key;
    }
    return null;
  }

  static List<int> _validatedPngKeywordBytes(String keyword) {
    if (keyword.isEmpty || keyword.length > _maxPngKeywordBytes) {
      throw ArgumentError.value(
        keyword,
        'keyword',
        'Must contain 1-79 Latin-1 bytes',
      );
    }
    final bytes = <int>[];
    for (final rune in keyword.runes) {
      if (rune > 0xFF ||
          rune < 0x20 ||
          rune == 0x7F ||
          (rune >= 0x80 && rune <= 0x9F)) {
        throw ArgumentError.value(
          keyword,
          'keyword',
          'Contains a non-Latin-1 or control byte',
        );
      }
      bytes.add(rune);
    }
    if (bytes.first == 0x20 || bytes.last == 0x20 || keyword.contains('  ')) {
      throw ArgumentError.value(
        keyword,
        'keyword',
        'Spaces may not lead, trail, or repeat',
      );
    }
    return bytes;
  }
}
