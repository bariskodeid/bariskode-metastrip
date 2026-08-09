import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/openxml_property_descriptor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/zip_extractor.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:xml/xml.dart';

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
/// `docProps/app.xml` entries of the zip container using exact namespace and
/// local-name matching. Returns a single
/// status field when the bytes are not a valid zip, when neither property
/// entry exists, or when no recognizable properties are found; this function
/// never throws.
Future<List<MetadataFieldEntity>> extractOpenXml(
  Uint8List bytes, {
  required String extension,
}) async {
  try {
    final archive = decodeGuardedZip(bytes);
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
        maxBytes: maxPackageDescriptorSize,
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
        maxBytes: maxPackageDescriptorSize,
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
    final property = _readTagValue(
      xml,
      tag,
      namespace: _descriptorFor('core', tag)?.namespace,
    );
    if (property == null) continue;
    fields.add(
      _field(
        label,
        property.value,
        id: property.hasRemovableIdentity ? _coreId(tag) : null,
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
    final property = _readTagValue(
      xml,
      tag,
      namespace: _descriptorFor('app', tag)?.namespace,
    );
    if (property == null) continue;
    fields.add(
      _field(
        label,
        property.value,
        id: property.hasRemovableIdentity ? _appId(tag) : null,
        isPrivacySensitive: _privacyLabels.contains(label),
      ),
    );
  }
  if (extension != 'pptx') return fields;
  for (final MapEntry(key: tag, value: label)
      in _presentationPropertyLabels.entries) {
    final property = _readTagValue(
      xml,
      tag,
      namespace: _descriptorFor('app', tag)?.namespace,
    );
    if (property == null) continue;
    fields.add(
      _field(
        label,
        property.value,
        id: property.hasRemovableIdentity ? _appId(tag) : null,
      ),
    );
  }
  return fields;
}

typedef _TagValue = ({String value, bool hasRemovableIdentity});

/// Returns the first local-name match and whether its namespace is removable.
_TagValue? _readTagValue(
  String xml,
  String tag, {
  required String? namespace,
}) {
  if (namespace == null) return null;
  try {
    final document = XmlDocument.parse(xml);
    String? nonRemovableValue;
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != tag) continue;
      final value = element.innerText.trim();
      if (value.isEmpty) continue;
      if (element.name.namespaceUri == namespace) {
        return (
          value: value,
          hasRemovableIdentity: true,
        );
      }
      nonRemovableValue ??= value;
    }
    if (nonRemovableValue != null) {
      return (value: nonRemovableValue, hasRemovableIdentity: false);
    }
  } on XmlException {
    final value = _readMalformedTagValue(xml, tag);
    return value == null ? null : (value: value, hasRemovableIdentity: false);
  }
  return null;
}

String? _readMalformedTagValue(String xml, String tag) {
  final pattern = RegExp(
    '<(?:[A-Za-z_][\\w.-]*:)?${_escapeRegex(tag)}(?:\\s[^>]*)?>'
    '([\\s\\S]*?)</(?:[A-Za-z_][\\w.-]*:)?${_escapeRegex(tag)}\\s*>',
  );
  final match = pattern.firstMatch(xml);
  if (match == null) return null;
  final value = _decodeXmlEntities(match.group(1)!.trim());
  return value.isEmpty ? null : value;
}

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
  MetadataFieldId? id,
  bool isPrivacySensitive = false,
}) {
  return MetadataFieldEntity(
    section: openXmlSection,
    label: label,
    value: truncateMetadataValue(value),
    id: id,
    isPrivacySensitive: isPrivacySensitive,
  );
}

MetadataFieldId? _coreId(String tag) => _descriptorFor('core', tag) == null
    ? null
    : const {
        'title': MetadataFieldId.openXmlTitle,
        'creator': MetadataFieldId.openXmlAuthor,
        'subject': MetadataFieldId.openXmlSubject,
        'keywords': MetadataFieldId.openXmlKeywords,
        'description': MetadataFieldId.openXmlDescription,
        'created': MetadataFieldId.openXmlCreated,
        'modified': MetadataFieldId.openXmlModified,
        'lastModifiedBy': MetadataFieldId.openXmlLastModifiedBy,
        'revision': MetadataFieldId.openXmlRevision,
        'category': MetadataFieldId.openXmlCategory,
        'contentStatus': MetadataFieldId.openXmlContentStatus,
      }[tag];

MetadataFieldId? _appId(String tag) => _descriptorFor('app', tag) == null
    ? null
    : const {
        'Application': MetadataFieldId.openXmlApplication,
        'Company': MetadataFieldId.openXmlCompany,
        'AppVersion': MetadataFieldId.openXmlAppVersion,
        'TotalTime': MetadataFieldId.openXmlTotalTime,
        'Slides': MetadataFieldId.openXmlSlides,
      }[tag];

OpenXmlPropertyDescriptor? _descriptorFor(String part, String localName) {
  for (final descriptor in openXmlPropertyDescriptors.values) {
    if (descriptor.part == part && descriptor.localName == localName) {
      return descriptor;
    }
  }
  return null;
}

String _escapeRegex(String value) {
  return value.replaceAllMapped(
    RegExp(r'[.*+?^${}()|[\]\\]'),
    (match) => '\\${match.group(0)}',
  );
}
