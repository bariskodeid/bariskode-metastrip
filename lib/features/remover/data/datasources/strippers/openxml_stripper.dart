import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
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
