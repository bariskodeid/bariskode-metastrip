import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/zip_extractor.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Section label shared by every ODF field.
const String odfSection = 'ODF Document';

/// Human labels for metadata elements in `meta.xml`.
const Map<String, String> _metaLabels = {
  'title': 'Title',
  'creator': 'Author',
  'subject': 'Subject',
  'description': 'Description',
  'keyword': 'Keywords',
  'generator': 'Generator',
  'initial-creator': 'Initial Creator',
  'creation-date': 'Created',
  'print-date': 'Printed',
  'modification-date': 'Modified',
};

/// Labels whose values may expose personal information.
const Set<String> _privacyLabels = {'Author', 'Initial Creator'};

/// Extracts OpenDocument (ODF) metadata from raw [bytes].
///
/// Reads the `meta.xml` entry of the zip container using simple tag matching
/// with optional namespace prefixes and XML entity decoding. Returns a single
/// status field when the bytes are not a valid zip, when `meta.xml` is
/// missing, or when no recognizable metadata is found; this function never
/// throws.
Future<List<MetadataFieldEntity>> extractOdf(Uint8List bytes) async {
  try {
    final archive = decodeGuardedZip(bytes);
    final meta = _findEntry(archive, 'meta.xml');
    if (meta == null) {
      return [
        statusField(odfSection, 'Status', 'No ODF metadata found'),
      ];
    }

    final content = decodeArchiveFileSafely(
      meta,
      maxBytes: maxPackageDescriptorSize,
    );
    if (content == null) {
      return [
        statusField(odfSection, 'Status', 'Unable to parse ODF metadata'),
      ];
    }
    if (content.length > AppConstants.maxZipCumulativeDecompressBytes) {
      return [
        statusField(odfSection, 'Status', 'Unable to parse ODF metadata'),
      ];
    }

    final fields = _extractMetaFields(content);
    if (fields.isEmpty) {
      return [
        statusField(odfSection, 'Status', 'No ODF metadata found'),
      ];
    }
    return fields;
  } catch (_) {
    return [
      statusField(odfSection, 'Status', 'Invalid ODF document'),
    ];
  }
}

/// Extracts metadata fields from the XML of [content].
List<MetadataFieldEntity> _extractMetaFields(Uint8List content) {
  final fields = <MetadataFieldEntity>[];
  final xml = _decodeUtf8(content);
  for (final MapEntry(key: tag, value: label) in _metaLabels.entries) {
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
/// the same rule the remover strippers apply, so metadata stored at a
/// non-root location such as `a/meta.xml` is found here and stripped there.
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

/// Builds a metadata field in the ODF document section.
MetadataFieldEntity _field(
  String label,
  String value, {
  bool isPrivacySensitive = false,
}) {
  return MetadataFieldEntity(
    section: odfSection,
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
