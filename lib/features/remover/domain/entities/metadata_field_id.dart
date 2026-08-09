import 'dart:convert';

/// Stable identifier for a selectively removable metadata field.
///
/// PNG IDs reversibly contain the metadata keyword. They must not be logged,
/// persisted, or exported without appropriate redaction.
extension type const MetadataFieldId._(String value) {
  static const _pngPrefix = 'png.text.';
  static const _vorbisPrefix = 'vorbis.comment.';
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

  // These IDs are the allowlisted local names in the standard core/app
  // properties parts. They intentionally do not represent custom or legacy
  // Office properties.
  static const openXmlTitle = MetadataFieldId._('openxml.core.title');
  static const openXmlAuthor = MetadataFieldId._('openxml.core.creator');
  static const openXmlSubject = MetadataFieldId._('openxml.core.subject');
  static const openXmlKeywords = MetadataFieldId._('openxml.core.keywords');
  static const openXmlDescription =
      MetadataFieldId._('openxml.core.description');
  static const openXmlCreated = MetadataFieldId._('openxml.core.created');
  static const openXmlModified = MetadataFieldId._('openxml.core.modified');
  static const openXmlLastModifiedBy =
      MetadataFieldId._('openxml.core.lastModifiedBy');
  static const openXmlRevision = MetadataFieldId._('openxml.core.revision');
  static const openXmlCategory = MetadataFieldId._('openxml.core.category');
  static const openXmlContentStatus =
      MetadataFieldId._('openxml.core.contentStatus');
  static const openXmlApplication =
      MetadataFieldId._('openxml.app.Application');
  static const openXmlCompany = MetadataFieldId._('openxml.app.Company');
  static const openXmlAppVersion = MetadataFieldId._('openxml.app.AppVersion');
  static const openXmlTotalTime = MetadataFieldId._('openxml.app.TotalTime');
  static const openXmlSlides = MetadataFieldId._('openxml.app.Slides');

  /// Normalizes a Vorbis key using ASCII whitespace trimming and ASCII case
  /// folding. Vorbis keys are UTF-8 fields, but the key itself is restricted
  /// to printable ASCII after normalization.
  static String normalizeVorbisCommentKey(String key) {
    final trimmed = key
        .replaceFirst(RegExp(r'^[\x09-\x0D\x20]+'), '')
        .replaceFirst(RegExp(r'[\x09-\x0D\x20]+$'), '');
    if (trimmed.isEmpty || trimmed.contains('=')) {
      throw ArgumentError.value(key, 'key', 'Invalid Vorbis comment key');
    }
    for (final rune in trimmed.runes) {
      if (rune < 0x20 || rune > 0x7D) {
        throw ArgumentError.value(key, 'key', 'Invalid Vorbis comment key');
      }
    }
    return trimmed.toUpperCase();
  }

  /// Creates a canonical, case-insensitive ID for a Vorbis comment key.
  factory MetadataFieldId.vorbisComment(String key) {
    final normalized = normalizeVorbisCommentKey(key);
    return MetadataFieldId._('$_vorbisPrefix$normalized');
  }

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
    final openXmlId = _openXmlIdsByValue[value];
    if (openXmlId != null) return openXmlId;
    if (value.startsWith(_vorbisPrefix)) {
      final parsed = MetadataFieldId.vorbisComment(
        value.substring(_vorbisPrefix.length),
      );
      if (parsed.value != value) {
        throw const FormatException('Non-canonical Vorbis metadata field ID');
      }
      return parsed;
    }
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
  bool get isVorbisComment => value.startsWith(_vorbisPrefix);
  bool get isOpenXml => _openXmlIdsByValue.containsKey(value);

  /// Whether this exact Open XML ID is surfaced for [extension].
  bool isOpenXmlSupportedFor(String extension) {
    if (!isOpenXml) return false;
    return switch (extension.toLowerCase()) {
      'pptx' => true,
      'docx' || 'xlsx' => this != openXmlTotalTime && this != openXmlSlides,
      _ => false,
    };
  }

  static const Map<String, MetadataFieldId> _openXmlIdsByValue = {
    'openxml.core.title': openXmlTitle,
    'openxml.core.creator': openXmlAuthor,
    'openxml.core.subject': openXmlSubject,
    'openxml.core.keywords': openXmlKeywords,
    'openxml.core.description': openXmlDescription,
    'openxml.core.created': openXmlCreated,
    'openxml.core.modified': openXmlModified,
    'openxml.core.lastModifiedBy': openXmlLastModifiedBy,
    'openxml.core.revision': openXmlRevision,
    'openxml.core.category': openXmlCategory,
    'openxml.core.contentStatus': openXmlContentStatus,
    'openxml.app.Application': openXmlApplication,
    'openxml.app.Company': openXmlCompany,
    'openxml.app.AppVersion': openXmlAppVersion,
    'openxml.app.TotalTime': openXmlTotalTime,
    'openxml.app.Slides': openXmlSlides,
  };

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

  String? get vorbisCommentKey =>
      isVorbisComment ? value.substring(_vorbisPrefix.length) : null;

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
