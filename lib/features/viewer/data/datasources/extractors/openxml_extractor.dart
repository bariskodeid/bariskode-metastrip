import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/openxml_package_paths.dart';
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
/// are additionally surfaced for `pptx`. Reads the core and extended property
/// parts named by `_rels/.rels` (falling back to the conventional
/// `docProps/core.xml` and `docProps/app.xml`) using exact namespace and
/// local-name matching of direct children of the root element. Returns a single
/// status field when the bytes are not a valid zip, when neither property
/// entry exists, or when no recognizable properties are found; this function
/// never throws.
Future<List<MetadataFieldEntity>> extractOpenXml(
  Uint8List bytes, {
  required String extension,
}) async {
  try {
    final archive = decodeGuardedZip(bytes);
    final related = _relatedPropertyPaths(archive);
    final coreMatch =
        _resolvePart(archive, related['core'], 'docProps/core.xml');
    final appMatch = _resolvePart(archive, related['app'], 'docProps/app.xml');
    final core = coreMatch?.file;
    final app = appMatch?.file;
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
      fields.addAll(
          _extractCoreProperties(content, canonical: coreMatch!.canonical));
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
      fields.addAll(
        _extractAppProperties(
          content,
          extension.toLowerCase(),
          canonical: appMatch!.canonical,
        ),
      );
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
///
/// Ids are emitted only when [canonical] (the part the remover targets).
List<MetadataFieldEntity> _extractCoreProperties(
  Uint8List content, {
  required bool canonical,
}) {
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
        id: canonical && property.hasRemovableIdentity ? _coreId(tag) : null,
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
  String extension, {
  required bool canonical,
}) {
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
        id: canonical && property.hasRemovableIdentity ? _appId(tag) : null,
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
        id: canonical && property.hasRemovableIdentity ? _appId(tag) : null,
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
    final root = document.rootElement;
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (element.name.local != tag) continue;
      final value = element.innerText.trim();
      if (value.isEmpty) continue;
      if (element.parent == root && element.name.namespaceUri == namespace) {
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

/// Maps `core` and `app` to the package path their `_rels/.rels` relationship
/// targets, using the same target rules as the remover.
///
/// Unreadable, ambiguous or unresolvable relationships are skipped, so the
/// caller falls back to the conventional location; this never throws.
Map<String, String> _relatedPropertyPaths(Archive archive) {
  final result = <String, String>{};
  try {
    final rels = _exactEntries(archive, '_rels/.rels');
    if (rels.length != 1) return result;
    final content = decodeArchiveFileSafely(
      rels.single,
      maxBytes: maxPackageDescriptorSize,
    );
    if (content == null) return result;
    final xml = utf8.decode(content, allowMalformed: true);
    if (xml.toUpperCase().contains('<!DOCTYPE')) return result;
    final root = XmlDocument.parse(xml).rootElement;
    if (root.name.namespaceUri != openXmlRelationshipsNamespace) return result;
    final seen = <String>{};
    for (final relationship in root.children.whereType<XmlElement>()) {
      if (relationship.name.local != 'Relationship') continue;
      final kind =
          openXmlPropertyRelationshipKinds[relationship.getAttribute('Type')];
      if (kind != 'core' && kind != 'extended') continue;
      final part = kind == 'extended' ? 'app' : 'core';
      if (!seen.add(part)) {
        result.remove(part);
        continue;
      }
      if (relationship.getAttribute('TargetMode')?.toLowerCase() ==
          'external') {
        continue;
      }
      final target = relationship.getAttribute('Target');
      final path = target == null ? null : resolveOpenXmlPackageTarget(target);
      if (path != null) result[part] = path;
    }
  } on Object {
    return {};
  }
  return result;
}

/// A resolved property part and whether the remover targets the same part.
typedef _ResolvedPart = ({ArchiveFile file, bool canonical});

/// Returns the part at [relatedPath] when exactly one entry has it, otherwise
/// the conventional [fallbackName] entry.
///
/// A relationship target or an exact root [fallbackName] is canonical; a part
/// found only by the `/`-suffix fallback is shown but not canonical.
_ResolvedPart? _resolvePart(
  Archive archive,
  String? relatedPath,
  String fallbackName,
) {
  if (relatedPath != null) {
    final related = _exactEntries(archive, relatedPath);
    if (related.length == 1) return (file: related.single, canonical: true);
  }
  final file = _findEntry(archive, fallbackName);
  if (file == null) return null;
  return (file: file, canonical: normalizeEntryPath(file.name) == fallbackName);
}

/// Entries whose normalized name equals [path].
List<ArchiveFile> _exactEntries(Archive archive, String path) => [
      for (final file in archive.files)
        if (normalizeEntryPath(file.name) == path) file,
    ];

/// Returns the entry named [name] in [archive].
///
/// The exact root path wins regardless of archive order; only when no root
/// entry exists does the viewer fall back to the first `/`-suffixed match, the
/// same suffix rule the remover applies when stripping, so metadata stored at
/// a non-root location such as `a/docProps/core.xml` is still shown.
ArchiveFile? _findEntry(Archive archive, String name) {
  ArchiveFile? suffixMatch;
  for (final file in archive.files) {
    final entryName = normalizeEntryPath(file.name);
    if (entryName == name) return file;
    if (suffixMatch == null && entryName.endsWith('/$name')) {
      suffixMatch = file;
    }
  }
  return suffixMatch;
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
