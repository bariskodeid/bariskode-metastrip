import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/openxml_property_descriptor.dart';
import 'package:xml/xml.dart';

/// `docProps` entries that carry Office Open XML metadata. Everything else
/// (`[Content_Types].xml`, `word/document.xml`, media, styles, ...) is
/// preserved.
const Set<String> _openXmlMetadataPaths = {
  'docProps/core.xml',
  'docProps/app.xml',
  'docProps/custom.xml',
};

const _contentTypesNamespace =
    'http://schemas.openxmlformats.org/package/2006/content-types';
const _relationshipsNamespace =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const _propertyRelationshipKinds = {
  'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties':
      'core',
  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties':
      'extended',
  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties':
      'custom',
  'http://purl.oclc.org/ooxml/package/relationships/metadata/core-properties':
      'core',
  'http://purl.oclc.org/ooxml/officeDocument/relationships/extended-properties':
      'extended',
  'http://purl.oclc.org/ooxml/officeDocument/relationships/custom-properties':
      'custom',
};

const _mainContentTypes = {
  'docx': {
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',
    'application/vnd.ms-word.document.main+xml',
  },
  'xlsx': {
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml',
    'application/vnd.ms-excel.sheet.main+xml',
  },
  'pptx': {
    'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml',
    'application/vnd.ms-powerpoint.presentation.main+xml',
  },
};

/// Strips Office Open XML metadata from [bytes] (docx, xlsx, pptx).
///
/// Resolves core, extended, and custom properties from the bounded root package
/// relationships, then removes those targets plus every safely normalized
/// conventional property part visible to the Viewer. The matching relationship
/// elements and content-type overrides are removed from the rebuilt package.
/// Packages without root relationships retain compatibility through exact
/// conventional property paths, with content-type declarations still updated.
///
/// Throws [FormatException] when [bytes] is not a valid zip archive, when the
/// archive is too large to repack, or when stripping would leave no entries.
Uint8List stripOpenXml(Uint8List bytes, {String extension = 'docx'}) {
  late final Set<String> metadataPaths;
  late final Map<String, Uint8List> replacements;
  try {
    final archive = decodeGuardedZip(bytes);
    final names =
        archive.files.map((entry) => normalizeEntryPath(entry.name)).toList();
    final mainPart = switch (extension) {
      'docx' => 'word/document.xml',
      'xlsx' => 'xl/workbook.xml',
      'pptx' => 'ppt/presentation.xml',
      _ => throw const FormatException('Unsupported office document'),
    };
    final manifestEntries = archive.files
        .where(
          (entry) => normalizeEntryPath(entry.name) == '[Content_Types].xml',
        )
        .toList();
    final manifestContent = manifestEntries.length == 1
        ? decodeZipEntrySafely(
            manifestEntries.single,
            maxBytes: maxPackageDescriptorSize,
          )
        : null;
    if (manifestEntries.length != 1 ||
        manifestContent == null ||
        names.where((name) => name == mainPart).length != 1 ||
        !_hasValidContentTypeManifest(
          manifestContent,
          mainPart,
          extension,
        )) {
      throw const FormatException('Invalid office document package');
    }
    final visiblePaths = names.where((name) {
      return _openXmlMetadataPaths.any(
        (path) => name == path || name.endsWith('/$path'),
      );
    });
    final relationships = _propertyRelationships(archive);
    metadataPaths = {...visiblePaths, ...?relationships?.paths};
    replacements = {
      if (relationships != null) '_rels/.rels': relationships.xml,
      '[Content_Types].xml': _removeContentTypeOverrides(
        manifestContent,
        metadataPaths,
      ),
    };
  } on FormatException {
    throw const FormatException('Invalid office document');
  }
  if (metadataPaths.isEmpty) {
    return bytes;
  }
  return repackZipWithoutEntries(
    bytes,
    skipPaths: metadataPaths,
    replacements: replacements,
    exactSkipPaths: true,
  );
}

/// Value-free facts returned by selective Open XML property mutation.
typedef OpenXmlSelectiveResult = ({
  Uint8List bytes,
  Set<MetadataFieldId> removedIds,
  Set<MetadataFieldId> absentIds,
});

/// Removes only allowlisted core/app properties identified by stable IDs.
///
/// The package and descriptor bounds used by full cleanup are retained. Only
/// the exact standard property part is rewritten; custom properties, legacy
/// Office data, relationships, and content-type declarations are untouched.
/// Unknown IDs, malformed/ambiguous parts, duplicate selected properties, and
/// unsupported presentation-only IDs fail closed.
OpenXmlSelectiveResult stripOpenXmlSelective(
  Uint8List bytes, {
  required String extension,
  required Set<MetadataFieldId> selectedIds,
}) {
  if (selectedIds.isEmpty ||
      !selectedIds.every((id) => id.isOpenXmlSupportedFor(extension))) {
    throw const FormatException('Unsupported selective metadata field');
  }

  try {
    final archive = decodeGuardedZip(bytes);
    _validateOfficePackage(archive, extension);
    final paths = _selectivePropertyPaths(archive);
    final replacements = <String, Uint8List>{};
    final removed = <MetadataFieldId>{};
    for (final part in ['core', 'app']) {
      final partIds = selectedIds.where(
        (id) => openXmlPropertyDescriptors[id]?.part == part,
      );
      if (partIds.isEmpty) continue;
      final path = paths[part];
      if (path == null) continue;
      final entries = archive.files
          .where((entry) => normalizeEntryPath(entry.name) == path)
          .toList();
      if (entries.length != 1) {
        throw const FormatException('Invalid metadata property part');
      }
      final content = decodeZipEntrySafely(
        entries.single,
        maxBytes: maxPackageDescriptorSize,
      );
      if (content == null) {
        throw const FormatException('Invalid metadata property part');
      }
      final mutation =
          _removeSelectedProperties(content, partIds.toSet(), part);
      replacements[path] = mutation.bytes;
      removed.addAll(mutation.removedIds);
    }
    final output = replacements.isEmpty
        ? bytes
        : repackZipWithoutEntries(
            bytes,
            skipPaths: const {},
            replacements: replacements,
            exactSkipPaths: true,
          );
    validateOpenXmlSelective(
      bytes,
      output,
      extension: extension,
      selectedIds: selectedIds,
      expectedRemovedIds: removed,
    );
    return (
      bytes: output,
      removedIds: Set.unmodifiable(removed),
      absentIds: Set.unmodifiable(selectedIds.difference(removed)),
    );
  } on FormatException {
    rethrow;
  } on Object {
    rethrow;
  }
}

void _validateOfficePackage(Archive archive, String extension) {
  final mainPart = switch (extension) {
    'docx' => 'word/document.xml',
    'xlsx' => 'xl/workbook.xml',
    'pptx' => 'ppt/presentation.xml',
    _ => throw const FormatException('Unsupported office document'),
  };
  final manifests = archive.files
      .where((entry) => normalizeEntryPath(entry.name) == '[Content_Types].xml')
      .toList();
  final mains = archive.files
      .where((entry) => normalizeEntryPath(entry.name) == mainPart)
      .toList();
  if (manifests.length != 1 || mains.length != 1) {
    throw const FormatException('Invalid office document package');
  }
  final manifest = decodeZipEntrySafely(
    manifests.single,
    maxBytes: maxPackageDescriptorSize,
  );
  if (manifest == null ||
      !_hasValidContentTypeManifest(manifest, mainPart, extension)) {
    throw const FormatException('Invalid office document package');
  }
}

Map<String, String> _selectivePropertyPaths(Archive archive) {
  final conventionalCandidates = <String, List<String>>{
    for (final part in ['core', 'app'])
      part: archive.files
          .map((entry) => normalizeEntryPath(entry.name))
          .where((path) =>
              path == 'docProps/$part.xml' ||
              path.endsWith('/docProps/$part.xml'))
          .toList(),
  };
  final entries = archive.files
      .where((entry) => normalizeEntryPath(entry.name) == '_rels/.rels')
      .toList();
  if (entries.isEmpty) {
    if (conventionalCandidates.values.any((paths) => paths.length > 1)) {
      throw const FormatException('Ambiguous metadata property part');
    }
    return {
      for (final entry in conventionalCandidates.entries)
        if (entry.value.length == 1) entry.key: entry.value.single,
    };
  }
  if (entries.length != 1) {
    throw const FormatException('Invalid package relationships');
  }
  final content = decodeZipEntrySafely(
    entries.single,
    maxBytes: maxPackageDescriptorSize,
  );
  if (content == null) throw const FormatException('Invalid relationships');
  final document = _parseDescriptor(content, 'Relationships');
  if (document.rootElement.name.namespaceUri != _relationshipsNamespace) {
    throw const FormatException('Invalid relationships');
  }
  final relationships = document.rootElement.children.whereType<XmlElement>();
  if (relationships.length > 4096) {
    throw const FormatException('Invalid relationships');
  }
  final seenKinds = <String>{};
  final result = <String, String>{};
  for (final relationship in relationships) {
    if (relationship.name.local != 'Relationship') continue;
    final kind = _propertyRelationshipKinds[relationship.getAttribute('Type')];
    if (kind != 'core' && kind != 'extended') continue;
    final part = kind == 'extended' ? 'app' : kind!;
    if (!seenKinds.add(part) ||
        relationship.getAttribute('TargetMode')?.toLowerCase() == 'external') {
      throw const FormatException('Invalid property relationship');
    }
    final target = relationship.getAttribute('Target');
    final path = target == null ? null : _resolvePackageTarget(target);
    if (path == null ||
        archive.files
                .where((entry) => normalizeEntryPath(entry.name) == path)
                .length !=
            1 ||
        result[part] != null) {
      throw const FormatException('Ambiguous property relationship');
    }
    result[part] = path;
  }
  for (final entry in conventionalCandidates.entries) {
    final relationshipPath = result[entry.key];
    if (relationshipPath != null) {
      if (entry.value.any((path) => path != relationshipPath) ||
          entry.value.where((path) => path == relationshipPath).length > 1) {
        throw const FormatException('Ambiguous metadata property part');
      }
      continue;
    }
    if (entry.value.length > 1) {
      throw const FormatException('Ambiguous metadata property part');
    }
    if (entry.value.length == 1) result[entry.key] = entry.value.single;
  }
  return result;
}

({Uint8List bytes, Set<MetadataFieldId> removedIds}) _removeSelectedProperties(
  Uint8List content,
  Set<MetadataFieldId> selectedIds,
  String part,
) {
  final document = _parseDescriptor(
    content,
    part == 'core' ? 'coreProperties' : 'Properties',
  );
  final expectedRootNamespace = part == 'core'
      ? openXmlCorePropertiesNamespace
      : openXmlExtendedPropertiesNamespace;
  if (document.rootElement.name.namespaceUri != expectedRootNamespace) {
    throw const FormatException('Invalid metadata property part');
  }
  final children =
      document.rootElement.children.whereType<XmlElement>().toList();
  if (children.length > 4096) {
    throw const FormatException('Invalid metadata property part');
  }
  final removed = <MetadataFieldId>{};
  for (final id in selectedIds) {
    final spec = openXmlPropertyDescriptors[id]!;
    final matches = children
        .where((element) =>
            element.name.local == spec.localName &&
            element.name.namespaceUri == spec.namespace)
        .toList();
    if (matches.length > 1) {
      throw const FormatException('Duplicate metadata property');
    }
    if (matches.singleOrNull case final element?) {
      element.remove();
      removed.add(id);
    }
  }
  return (
    bytes: Uint8List.fromList(utf8.encode(document.toXmlString())),
    removedIds: removed,
  );
}

/// Verifies selected-property absence and all unselected ZIP entry contents.
void validateOpenXmlSelective(
  Uint8List input,
  Uint8List output, {
  required String extension,
  required Set<MetadataFieldId> selectedIds,
  required Set<MetadataFieldId> expectedRemovedIds,
}) {
  final before = decodeGuardedZip(input);
  final after = decodeGuardedZip(output);
  _validateOfficePackage(after, extension);
  final beforePaths = _selectivePropertyPaths(before);
  final afterPaths = _selectivePropertyPaths(after);
  if (!_mapEquals(beforePaths, afterPaths)) {
    throw const FormatException('Property paths changed');
  }
  final mutablePaths = {
    for (final part in ['core', 'app'])
      if (selectedIds.any(
            (id) => openXmlPropertyDescriptors[id]!.part == part,
          ) &&
          beforePaths[part] != null)
        beforePaths[part]!,
  };
  final beforeContent = _entryContents(before);
  final afterContent = _entryContents(after);
  if (!beforeContent.keys.toSet().containsAll(afterContent.keys) ||
      !afterContent.keys.toSet().containsAll(beforeContent.keys)) {
    throw const FormatException('Package entries changed');
  }
  for (final path in beforeContent.keys.where(
    (path) => !mutablePaths.contains(path) && path != '[Content_Types].xml',
  )) {
    if (!_bytesEqual(beforeContent[path]!, afterContent[path]!)) {
      throw const FormatException('Unselected package content changed');
    }
  }
  final observedRemoved = <MetadataFieldId>{};
  for (final part in ['core', 'app']) {
    final ids = selectedIds
        .where((id) => openXmlPropertyDescriptors[id]!.part == part)
        .toSet();
    if (ids.isEmpty || beforePaths[part] == null) continue;
    final beforeMutation =
        _removeSelectedProperties(beforeContent[beforePaths[part]]!, ids, part);
    final afterMutation =
        _removeSelectedProperties(afterContent[afterPaths[part]]!, ids, part);
    observedRemoved.addAll(beforeMutation.removedIds);
    if (afterMutation.removedIds.isNotEmpty) {
      throw const FormatException('Selected property remains');
    }
    if (!_bytesEqual(beforeMutation.bytes, afterMutation.bytes)) {
      throw const FormatException('Unselected properties changed');
    }
  }
  if (!observedRemoved.containsAll(expectedRemovedIds) ||
      !expectedRemovedIds.containsAll(observedRemoved)) {
    throw const FormatException('Removal facts do not match output');
  }
}

Map<String, Uint8List> _entryContents(Archive archive) {
  final result = <String, Uint8List>{};
  var totalSize = 0;
  for (final entry in archive.files) {
    final path = normalizeEntryPath(entry.name);
    if (entry.isFile == false || path.endsWith('/')) {
      continue;
    }
    if (result.containsKey(path)) {
      throw const FormatException('Duplicate entry');
    }
    final raw = entry.content;
    if (raw is! List<int> || raw.length > maxRepackEntrySize) {
      throw const FormatException('Invalid ZIP entry');
    }
    totalSize += raw.length;
    if (totalSize > maxRepackTotalSize) {
      throw const FormatException('Archive too large to validate');
    }
    result[path] = Uint8List.fromList(raw);
  }
  return result;
}

bool _bytesEqual(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}

bool _hasValidContentTypeManifest(
  Uint8List content,
  String mainPart,
  String extension,
) {
  try {
    final xml = utf8.decode(content, allowMalformed: false);
    if (xml.toUpperCase().contains('<!DOCTYPE')) return false;
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    if (root.name.local != 'Types' ||
        root.name.namespaceUri != _contentTypesNamespace) {
      return false;
    }
    final declarations = root.children.whereType<XmlElement>().toList();
    if (declarations.length > 4096) return false;
    return declarations.where((element) {
          return element.name.local == 'Override' &&
              element.name.namespaceUri == _contentTypesNamespace &&
              element.getAttribute('PartName') == '/$mainPart' &&
              _mainContentTypes[extension]!
                  .contains(element.getAttribute('ContentType'));
        }).length ==
        1;
  } catch (_) {
    return false;
  }
}

({Set<String> paths, Uint8List xml})? _propertyRelationships(
  Archive archive,
) {
  final entries = archive.files
      .where((entry) => normalizeEntryPath(entry.name) == '_rels/.rels')
      .toList();
  if (entries.isEmpty) return null;
  if (entries.length != 1 || entries.single.size > maxPackageDescriptorSize) {
    throw const FormatException('Invalid package relationships');
  }
  final content = decodeZipEntrySafely(
    entries.single,
    maxBytes: maxPackageDescriptorSize,
  );
  if (content == null) {
    throw const FormatException('Invalid package relationships');
  }
  final document = _parseDescriptor(content, 'Relationships');
  if (document.rootElement.name.namespaceUri != _relationshipsNamespace) {
    throw const FormatException('Invalid package relationships');
  }
  final relationships = document.rootElement.children
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'Relationship')
      .toList();
  if (relationships.length > 4096) {
    throw const FormatException('Invalid package relationships');
  }
  final ids = <String>{};
  final kinds = <String>{};
  final paths = <String>{};
  for (final relationship in relationships) {
    final id = relationship.getAttribute('Id');
    if (id == null || id.isEmpty || !ids.add(id)) {
      throw const FormatException('Invalid package relationships');
    }
    final type = relationship.getAttribute('Type');
    final kind = _propertyRelationshipKinds[type];
    if (kind == null) continue;
    if (!kinds.add(kind) ||
        relationship.getAttribute('TargetMode')?.toLowerCase() == 'external') {
      throw const FormatException('Invalid property relationship');
    }
    final target = relationship.getAttribute('Target');
    final path = target == null ? null : _resolvePackageTarget(target);
    if (path == null || !paths.add(path)) {
      throw const FormatException('Invalid property relationship');
    }
    final matches = archive.files
        .where((entry) => normalizeEntryPath(entry.name) == path)
        .length;
    if (matches != 1) {
      throw const FormatException('Invalid property relationship');
    }
    relationship.remove();
  }
  return (
    paths: paths,
    xml: Uint8List.fromList(utf8.encode(document.toXmlString()))
  );
}

String? _resolvePackageTarget(String target) {
  if (target.isEmpty ||
      target.contains('\\') ||
      target.contains('?') ||
      target.contains('#') ||
      RegExp('%(?:2f|5c)', caseSensitive: false).hasMatch(target)) {
    return null;
  }
  final uri = Uri.tryParse(target);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final segments = <String>[];
  for (final segment in target.replaceFirst(RegExp('^/+'), '').split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) return null;
      segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  final path = normalizeEntryPath(segments.join('/'));
  return path.isEmpty ? null : path;
}

Uint8List _removeContentTypeOverrides(
  Uint8List content,
  Set<String> removedPaths,
) {
  final document = _parseDescriptor(content, 'Types');
  if (document.rootElement.name.namespaceUri != _contentTypesNamespace) {
    throw const FormatException('Invalid content type manifest');
  }
  for (final element
      in document.rootElement.children.whereType<XmlElement>().toList()) {
    if (element.name.local != 'Override') continue;
    final partName = element.getAttribute('PartName');
    if (partName != null &&
        removedPaths.contains(_resolvePackageTarget(partName))) {
      element.remove();
    }
  }
  return Uint8List.fromList(utf8.encode(document.toXmlString()));
}

XmlDocument _parseDescriptor(Uint8List content, String rootName) {
  final xml = utf8.decode(content, allowMalformed: false);
  if (xml.toUpperCase().contains('<!DOCTYPE')) {
    throw const FormatException('Invalid XML descriptor');
  }
  final document = XmlDocument.parse(xml);
  if (document.rootElement.name.local != rootName) {
    throw const FormatException('Invalid XML descriptor');
  }
  return document;
}
