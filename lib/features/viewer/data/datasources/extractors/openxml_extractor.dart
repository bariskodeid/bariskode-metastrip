import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/zip_extractor.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Section label shared by every Office Open XML field.
const String openXmlSection = 'Office Document';

/// Human labels for core properties in `docProps/core.xml`.
const Map<String, String> _corePropertyLabels = {
  'title': 'Title',
  'creator': 'Author',
  'subject': 'Subject',
  'keywords': 'Keywords',
  'description': 'Comments',
  'created': 'Created',
  'modified': 'Modified',
  'lastModifiedBy': 'Last Modified By',
  'revision': 'Revision',
  'category': 'Category',
  'contentStatus': 'Content Status',
};

/// Human labels for extended properties in `docProps/app.xml`.
const Map<String, String> _appPropertyLabels = {
  'Application': 'Application',
  'Company': 'Company',
  'AppVersion': 'App Version',
};

/// Extended properties surfaced only for presentations.
const Map<String, String> _presentationPropertyLabels = {
  'TotalTime': 'Total Time',
  'Slides': 'Slides',
};

/// Labels whose values may expose personal information.
const Set<String> _privacyLabels = {'Author', 'Last Modified By', 'Company'};

/// Extracts Office Open XML metadata from raw [bytes] for [extension].
///
/// [extension] must be `docx`, `xlsx` or `pptx`; presentation-only properties
/// are additionally surfaced for `pptx`. Reads the `docProps/core.xml` and
/// `docProps/app.xml` entries of the zip container using simple tag matching
/// with optional namespace prefixes and XML entity decoding. Returns a single
/// status field when the bytes are not a valid zip, when neither property
/// entry exists, or when no recognizable properties are found; this function
/// never throws.
Future<List<MetadataFieldEntity>> extractOpenXml(
  Uint8List bytes, {
  required String extension,
}) async {
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final core = _findEntry(archive, 'docProps/core.xml');
    final app = _findEntry(archive, 'docProps/app.xml');
    if (core == null && app == null) {
      return [
        statusField(
          openXmlSection,
          'Status',
          'No office document metadata found',
        ),
      ];
    }

    final fields = <MetadataFieldEntity>[];
    var totalDecompressed = 0;
    if (core != null) {
      final content = decodeArchiveFileSafely(
        core,
        maxBytes: AppConstants.maxZipEntryDecompressBytes,
      );
      if (content == null) return _invalidStatus();
      totalDecompressed += content.length;
      if (totalDecompressed > AppConstants.maxZipCumulativeDecompressBytes) {
        return _invalidStatus();
      }
      fields.addAll(_extractCoreProperties(content));
    }
    if (app != null) {
      final content = decodeArchiveFileSafely(
        app,
        maxBytes: AppConstants.maxZipEntryDecompressBytes,
      );
      if (content == null) return _invalidStatus();
      totalDecompressed += content.length;
      if (totalDecompressed > AppConstants.maxZipCumulativeDecompressBytes) {
        return _invalidStatus();
      }
      fields.addAll(_extractAppProperties(content, extension.toLowerCase()));
    }
    if (fields.isEmpty) {
      return [
        statusField(
          openXmlSection,
          'Status',
          'No office document metadata found',
        ),
      ];
    }
    return fields;
  } catch (_) {
    return [
      statusField(openXmlSection, 'Status', 'Invalid office document'),
    ];
  }
}

/// Extracts core property fields from the XML of [content].
List<MetadataFieldEntity> _extractCoreProperties(Uint8List content) {
  final fields = <MetadataFieldEntity>[];
  final xml = _decodeUtf8(content);
  for (final MapEntry(key: tag, value: label) in _corePropertyLabels.entries) {
    final value = _readTagValue(xml, tag);
    if (value == null) continue;
    fields.add(
      _field(
        label,
        value,
        isPrivacySensitive: _privacyLabels.contains(label),
      ),
    );
  }
  return fields;
}

/// Extracts extended property fields from the XML of [content].
///
/// Presentation-only properties (total editing time, slide count) are
/// extracted when [extension] is `pptx`.
List<MetadataFieldEntity> _extractAppProperties(
  Uint8List content,
  String extension,
) {
  final fields = <MetadataFieldEntity>[];
  final xml = _decodeUtf8(content);
  for (final MapEntry(key: tag, value: label) in _appPropertyLabels.entries) {
    final value = _readTagValue(xml, tag);
    if (value == null) continue;
    fields.add(
      _field(
        label,
        value,
        isPrivacySensitive: _privacyLabels.contains(label),
      ),
    );
  }
  if (extension != 'pptx') return fields;
  for (final MapEntry(key: tag, value: label)
      in _presentationPropertyLabels.entries) {
    final value = _readTagValue(xml, tag);
    if (value == null) continue;
    fields.add(_field(label, value));
  }
  return fields;
}

/// Returns the trimmed, entity-decoded text of the first [tag] element.
///
/// Matches both prefixed (`dc:title`) and unprefixed (`Title`) tags with
/// optional attributes on the opening tag.
String? _readTagValue(String xml, String tag) {
  final pattern = RegExp(
    '<(?:[A-Za-z_][\\w.-]*:)?${_escapeRegex(tag)}(?:\\s[^>]*)?>'
    '([\\s\\S]*?)</(?:[A-Za-z_][\\w.-]*:)?${_escapeRegex(tag)}\\s*>',
  );
  final match = pattern.firstMatch(xml);
  if (match == null) return null;
  final value = _decodeXmlEntities(match.group(1)!.trim());
  return value.isEmpty ? null : value;
}

/// Decodes the five named XML entities and numeric character references.
///
/// `&amp;` is decoded after the other named entities so that sequences such
/// as `&amp;lt;` stay literal, matching XML parsing semantics.
String _decodeXmlEntities(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAllMapped(_hexRefPattern, _decodeHexRef)
      .replaceAllMapped(_decimalRefPattern, _decodeDecimalRef);
}

final RegExp _hexRefPattern = RegExp(r'&#x([0-9a-fA-F]+);');
final RegExp _decimalRefPattern = RegExp(r'&#([0-9]+);');

String _decodeHexRef(Match match) {
  final code = int.tryParse(match.group(1)!, radix: 16);
  return code == null ? match.group(0)! : String.fromCharCode(code);
}

String _decodeDecimalRef(Match match) {
  final code = int.tryParse(match.group(1)!);
  return code == null ? match.group(0)! : String.fromCharCode(code);
}

/// Returns the first entry whose name matches [name] in [archive].
///
/// Names are compared through [normalizeEntryPath] and by `/`-suffixed suffix,
/// the same rule the remover strippers apply, so metadata stored at a non-root
/// location such as `a/docProps/core.xml` is found here and stripped there.
ArchiveFile? _findEntry(Archive archive, String name) {
  for (final file in archive.files) {
    final entryName = normalizeEntryPath(file.name);
    if (entryName == name || entryName.endsWith('/$name')) return file;
  }
  return null;
}

/// Decodes [content] as UTF-8 text, tolerating malformed sequences.
String _decodeUtf8(Uint8List content) {
  return utf8.decode(content, allowMalformed: true);
}

/// Returns the status field used when an office document cannot be parsed.
List<MetadataFieldEntity> _invalidStatus() {
  return [
    statusField(openXmlSection, 'Status', 'Invalid office document'),
  ];
}

/// Builds a metadata field in the office document section.
MetadataFieldEntity _field(
  String label,
  String value, {
  bool isPrivacySensitive = false,
}) {
  return MetadataFieldEntity(
    section: openXmlSection,
    label: label,
    value: truncateMetadataValue(value),
    isPrivacySensitive: isPrivacySensitive,
  );
}

/// Escapes regex special characters in [value].
String _escapeRegex(String value) {
  return value.replaceAllMapped(
    RegExp(r'[.*+?^${}()|[\]\\]'),
    (match) => '\\${match.group(0)}',
  );
}
