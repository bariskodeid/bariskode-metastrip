import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/odf_property_descriptor.dart';
import 'package:xml/xml.dart';

/// The single entry that carries OpenDocument metadata.
const Set<String> _odfMetadataPaths = {'meta.xml'};

/// Strips OpenDocument (ODF) metadata from [bytes] (odt, ods, odp).
///
/// Removes the `meta.xml` entry by re-encoding the zip container without it;
/// every other entry (content.xml, styles.xml, media, ...) keeps its content
/// verbatim. When the document has no `meta.xml` entry the original [bytes]
/// are returned unchanged (the same instance, not re-encoded).
///
/// Throws [FormatException] when [bytes] is not a valid zip archive, when the
/// archive is too large to repack, or when stripping would leave no entries.
Uint8List stripOdf(Uint8List bytes, {String extension = 'odt'}) {
  final bool hasMeta;
  try {
    final preflight = preflightZip(bytes);
    final mimeDescriptor = preflight.where((entry) => entry.name == 'mimetype');
    final contentDescriptors =
        preflight.where((entry) => entry.name == 'content.xml');
    if (preflight.isEmpty ||
        mimeDescriptor.length != 1 ||
        contentDescriptors.length != 1 ||
        mimeDescriptor.single.localHeaderOffset != 0 ||
        mimeDescriptor.single.localExtraLength != 0 ||
        mimeDescriptor.single.compressionMethod != 0 ||
        mimeDescriptor.single.uncompressedSize > 256 ||
        mimeDescriptor.single.compressedSize > 256) {
      throw const FormatException('Invalid OpenDocument package');
    }
    final archive = decodeGuardedZip(bytes);
    final mimeEntry = archive.findFile('mimetype');
    final expectedMime = switch (extension) {
      'odt' => 'application/vnd.oasis.opendocument.text',
      'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
      'odp' => 'application/vnd.oasis.opendocument.presentation',
      _ => throw const FormatException('Unsupported OpenDocument package'),
    };
    final mimeBytes = mimeEntry == null
        ? null
        : decodeZipEntrySafely(mimeEntry, maxBytes: 256);
    if (mimeBytes == null || mimeBytes.length > 256) {
      throw const FormatException('Invalid OpenDocument package');
    }
    final mime = String.fromCharCodes(mimeBytes);
    if (mime != expectedMime || archive.findFile('content.xml') == null) {
      throw const FormatException('Invalid OpenDocument package');
    }
    final metaEntries = archive.files.where((entry) {
      final name = normalizeEntryPath(entry.name);
      return name == 'meta.xml' || name.endsWith('/meta.xml');
    });
    hasMeta = metaEntries.isNotEmpty;
  } on FormatException {
    throw const FormatException('Invalid office document');
  }
  if (!hasMeta) {
    return bytes;
  }
  return repackZipWithoutEntries(
    bytes,
    skipPaths: _odfMetadataPaths,
    storedFirstPath: 'mimetype',
  );
}

/// Facts returned by bounded ODF property mutation.
class OdfSelectiveResult {
  const OdfSelectiveResult({
    required this.bytes,
    required this.removedIds,
    required this.absentIds,
  });

  final Uint8List bytes;
  final Set<MetadataFieldId> removedIds;
  final Set<MetadataFieldId> absentIds;
}

/// Removes only exact, allowlisted ODF properties from the one `meta.xml`
/// part. The full [stripOdf] route remains intentionally separate.
OdfSelectiveResult stripOdfSelective(
  Uint8List bytes, {
  required String extension,
  required Set<MetadataFieldId> selectedIds,
}) {
  if (selectedIds.isEmpty ||
      !selectedIds.every((id) => id.isOdfSupportedFor(extension))) {
    throw const FormatException('Unsupported selective metadata field');
  }
  final package = _validateOdfPackage(bytes, extension);
  final metaPath = package.metaPath;
  if (metaPath == null) {
    return OdfSelectiveResult(
      bytes: bytes,
      removedIds: const {},
      absentIds: Set.unmodifiable(selectedIds),
    );
  }
  final content = package.metaBytes;
  if (content == null) throw const FormatException('Invalid ODF metadata part');
  final mutation = _removeProperties(content, selectedIds);
  final output = mutation.removedIds.isEmpty
      ? bytes
      : repackZipWithoutEntries(
          bytes,
          skipPaths: const {},
          replacements: {
            metaPath: mutation.bytes,
          },
          exactSkipPaths: true,
          storedFirstPath: 'mimetype',
        );
  validateOdfSelective(
    bytes,
    output,
    extension: extension,
    selectedIds: selectedIds,
    expectedRemovedIds: mutation.removedIds,
  );
  return OdfSelectiveResult(
    bytes: output,
    removedIds: Set.unmodifiable(mutation.removedIds),
    absentIds: Set.unmodifiable(selectedIds.difference(mutation.removedIds)),
  );
}

class _ValidatedOdfPackage {
  const _ValidatedOdfPackage(this.preflight, this.metaPath, this.metaBytes);
  final List<ZipPreflightEntry> preflight;
  final String? metaPath;
  final Uint8List? metaBytes;
}

_ValidatedOdfPackage _validateOdfPackage(Uint8List bytes, String extension) {
  try {
    final preflight = preflightZip(bytes);
    _validateInventoryBounds(preflight);
    final mime = preflight.where((entry) => entry.name == 'mimetype').toList();
    final content =
        preflight.where((entry) => entry.name == 'content.xml').toList();
    if (preflight.isEmpty ||
        mime.length != 1 ||
        content.length != 1 ||
        mime.single.localHeaderOffset != 0 ||
        mime.single.localExtraLength != 0 ||
        mime.single.compressionMethod != 0 ||
        mime.single.uncompressedSize > 256 ||
        mime.single.compressedSize > 256) {
      throw const FormatException('Invalid OpenDocument package');
    }
    // ZipDecoder creates lazy entries. Only the required members below are
    // decoded; unrelated entries remain represented by preflight metadata.
    final archive = decodeGuardedZip(bytes);
    final mimeBytes = decodeZipEntrySafely(
      archive.findFile('mimetype')!,
      maxBytes: 256,
    );
    final expected = switch (extension) {
      'odt' => 'application/vnd.oasis.opendocument.text',
      'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
      'odp' => 'application/vnd.oasis.opendocument.presentation',
      _ => throw const FormatException('Unsupported OpenDocument package'),
    };
    if (mimeBytes == null ||
        String.fromCharCodes(mimeBytes) != expected ||
        decodeZipEntrySafely(
              archive.findFile('content.xml')!,
              maxBytes: maxRepackEntrySize,
            ) ==
            null) {
      throw const FormatException('Invalid OpenDocument package');
    }
    final metaPath = _metaPath(archive);
    final metaBytes = metaPath == null
        ? null
        : decodeZipEntrySafely(
            archive.findFile(metaPath)!,
            maxBytes: maxPackageDescriptorSize,
          );
    if (metaPath != null && metaBytes == null) {
      throw const FormatException('Invalid ODF metadata part');
    }
    return _ValidatedOdfPackage(preflight, metaPath, metaBytes);
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException('Invalid OpenDocument package');
  }
}

String? _metaPath(Archive archive) {
  final paths = archive.files
      .map((entry) => normalizeEntryPath(entry.name))
      .where((name) => name == 'meta.xml')
      .toList();
  if (paths.length > 1) {
    throw const FormatException('Ambiguous ODF metadata part');
  }
  return paths.singleOrNull;
}

({Uint8List bytes, Set<MetadataFieldId> removedIds}) _removeProperties(
  Uint8List content,
  Set<MetadataFieldId> selectedIds,
) {
  final document = _parseMeta(content);
  final metadataRoots = document.rootElement.children
      .whereType<XmlElement>()
      .where((element) =>
          element.name.local == 'meta' &&
          element.name.namespaceUri ==
              'urn:oasis:names:tc:opendocument:xmlns:office:1.0')
      .toList();
  if (metadataRoots.length != 1) {
    throw const FormatException('Invalid ODF metadata root');
  }
  final children =
      metadataRoots.single.children.whereType<XmlElement>().toList();
  if (children.length > 4096) {
    throw const FormatException('ODF metadata too large');
  }
  final removed = <MetadataFieldId>{};
  for (final id in selectedIds) {
    final descriptor = odfPropertyDescriptors[id]!;
    final matches = children
        .where((element) =>
            element.name.local == descriptor.localName &&
            element.name.namespaceUri == descriptor.namespace)
        .toList();
    if (id != MetadataFieldId.odfKeywords && matches.length > 1) {
      throw const FormatException('Duplicate ODF metadata property');
    }
    if (matches.isNotEmpty) {
      for (final match in matches) {
        match.remove();
      }
      removed.add(id);
    }
  }
  return (
    bytes: Uint8List.fromList(utf8.encode(document.toXmlString())),
    removedIds: removed
  );
}

XmlDocument _parseMeta(Uint8List content) {
  try {
    final xml = utf8.decode(content, allowMalformed: false);
    if (xml.toUpperCase().contains('<!DOCTYPE')) {
      throw const FormatException('Invalid ODF metadata part');
    }
    final document = XmlDocument.parse(xml);
    if (document.rootElement.name.namespaceUri !=
            'urn:oasis:names:tc:opendocument:xmlns:office:1.0' ||
        document.rootElement.name.local != 'document-meta') {
      throw const FormatException('Invalid ODF metadata root');
    }
    var nodeCount = 0;
    void checkBounds(XmlNode node, int depth) {
      nodeCount++;
      if (nodeCount > 8192 || depth > 64) {
        throw const FormatException('ODF metadata too complex');
      }
      for (final child in node.children) {
        checkBounds(child, depth + 1);
      }
    }

    checkBounds(document, 0);
    return document;
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException('Invalid ODF metadata part');
  }
}

/// Validates generated or locally persisted selective output.
void validateOdfSelective(
  Uint8List input,
  Uint8List output, {
  required String extension,
  required Set<MetadataFieldId> selectedIds,
  required Set<MetadataFieldId> expectedRemovedIds,
}) {
  final before = _validateOdfPackage(input, extension);
  final after = _validateOdfPackage(output, extension);
  final beforeEntries = _entryInventory(before.preflight, input);
  final afterEntries = _entryInventory(after.preflight, output);
  final beforeMetaPath = before.metaPath;
  final afterMetaPath = after.metaPath;
  if (beforeMetaPath != afterMetaPath) {
    throw const FormatException('ODF metadata path changed');
  }
  if (beforeEntries.length != afterEntries.length) {
    throw const FormatException('ODF package entries changed');
  }
  final afterByName = {
    for (final entry in afterEntries) entry.normalizedName: entry,
  };
  for (final beforeEntry in beforeEntries) {
    final afterEntry = afterByName[beforeEntry.normalizedName];
    if (afterEntry == null ||
        beforeEntry.name != afterEntry.name ||
        beforeEntry.isFile != afterEntry.isFile) {
      throw const FormatException('ODF package entries changed');
    }
    if (beforeEntry.normalizedName != beforeMetaPath &&
        (beforeEntry.compressionMethod != afterEntry.compressionMethod ||
            beforeEntry.uncompressedSize != afterEntry.uncompressedSize ||
            beforeEntry.crc32 != afterEntry.crc32 ||
            beforeEntry.contentDigest != afterEntry.contentDigest)) {
      throw const FormatException('Unselected ODF package content changed');
    }
  }
  if (beforeMetaPath != null) {
    final beforeDocument = _parseMeta(before.metaBytes!);
    final afterDocument = _parseMeta(after.metaBytes!);
    final beforeMutation = _removeProperties(before.metaBytes!, selectedIds);
    final afterMutation = _removeProperties(after.metaBytes!, selectedIds);
    if (afterMutation.removedIds.isNotEmpty ||
        beforeMutation.removedIds.length != expectedRemovedIds.length ||
        !beforeMutation.removedIds.containsAll(expectedRemovedIds) ||
        _semanticXml(beforeDocument, selectedIds) !=
            _semanticXml(afterDocument, selectedIds)) {
      throw const FormatException(
          'ODF selective preservation validation failed');
    }
  } else if (expectedRemovedIds.isNotEmpty) {
    throw const FormatException('ODF removal facts do not match output');
  }
}

class _OdfEntrySnapshot {
  const _OdfEntrySnapshot({
    required this.name,
    required this.normalizedName,
    required this.isFile,
    required this.compressionMethod,
    required this.uncompressedSize,
    required this.crc32,
    required this.contentDigest,
  });

  final String name;
  final String normalizedName;
  final bool isFile;
  final int compressionMethod;
  final int uncompressedSize;
  final int crc32;
  final Digest contentDigest;
}

List<_OdfEntrySnapshot> _entryInventory(
  List<ZipPreflightEntry> entries,
  Uint8List bytes,
) {
  final result = <_OdfEntrySnapshot>[];
  final names = <String>{};
  final archive = decodeGuardedZip(bytes);
  for (final entry in entries) {
    final path = normalizeEntryPath(entry.name);
    if (!names.add(path)) {
      throw const FormatException('Invalid ODF package entry');
    }
    result.add(_OdfEntrySnapshot(
      name: entry.name,
      normalizedName: path,
      isFile: !path.endsWith('/'),
      compressionMethod: entry.compressionMethod,
      uncompressedSize: entry.uncompressedSize,
      crc32: entry.crc32,
      contentDigest: _entryDigest(archive, path),
    ));
  }
  return result;
}

Digest _entryDigest(Archive archive, String path) {
  final archiveEntry = archive.findFile(path);
  if (archiveEntry == null) {
    throw const FormatException('Unable to verify ODF package content');
  }
  final content = decodeZipEntrySafely(
    archiveEntry,
    maxBytes: maxRepackEntrySize,
  );
  if (content == null) {
    throw const FormatException('Unable to verify ODF package content');
  }
  return sha256.convert(content);
}

void _validateInventoryBounds(List<ZipPreflightEntry> entries) {
  var total = 0;
  for (final entry in entries) {
    if (entry.uncompressedSize > maxRepackEntrySize ||
        total > maxRepackTotalSize - entry.uncompressedSize) {
      throw const FormatException('ODF package too large');
    }
    total += entry.uncompressedSize;
  }
}

String _semanticXml(XmlDocument document, Set<MetadataFieldId> selectedIds) {
  String visit(XmlNode node) {
    if (node is XmlElement) {
      final selected = selectedIds.any((id) {
        final descriptor = odfPropertyDescriptors[id]!;
        return node.name.local == descriptor.localName &&
            node.name.namespaceUri == descriptor.namespace;
      });
      if (selected && _isCanonicalMetaChild(node)) {
        return '';
      }
      final attributes = node.attributes
          .map((attribute) =>
              '${attribute.name.namespaceUri}|${attribute.name.local}=${attribute.value}')
          .toList()
        ..sort();
      return '<${node.name.namespaceUri}|${node.name.local} '
          '${attributes.join(';')}>${node.children.map(visit).join()}</${node.name.namespaceUri}|${node.name.local}>';
    }
    if (node is XmlComment) return '<!--${node.value}-->';
    if (node is XmlProcessing) return node.toXmlString();
    if (node is XmlCDATA) return '<![CDATA[${node.value}]]>';
    if (node is XmlText) return 'TEXT:${node.value}';
    return node.toXmlString();
  }

  return document.children.map(visit).join();
}

bool _isCanonicalMetaChild(XmlElement element) {
  final parent = element.parent;
  final root = parent?.parent;
  return parent is XmlElement &&
      parent.name.local == 'meta' &&
      parent.name.namespaceUri ==
          'urn:oasis:names:tc:opendocument:xmlns:office:1.0' &&
      root is XmlElement &&
      root.name.local == 'document-meta' &&
      root.name.namespaceUri ==
          'urn:oasis:names:tc:opendocument:xmlns:office:1.0' &&
      root.parent is XmlDocument;
}
