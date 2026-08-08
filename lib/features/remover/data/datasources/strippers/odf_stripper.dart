import 'dart:typed_data';

import 'package:metastrip/core/processing/zip_repack.dart';

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
    if (metaEntries.length > 1) {
      throw const FormatException('Invalid OpenDocument package');
    }
    hasMeta = metaEntries.length == 1;
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
