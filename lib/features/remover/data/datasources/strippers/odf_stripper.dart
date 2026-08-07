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
Uint8List stripOdf(Uint8List bytes) {
  final bool hasMeta;
  try {
    hasMeta = zipArchiveContainsEntry(bytes, 'meta.xml');
  } on FormatException {
    throw const FormatException('Invalid office document');
  }
  if (!hasMeta) {
    return bytes;
  }
  return repackZipWithoutEntries(bytes, skipPaths: _odfMetadataPaths);
}
