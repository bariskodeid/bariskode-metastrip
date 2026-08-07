import 'dart:typed_data';

import 'package:metastrip/core/processing/zip_repack.dart';

/// `docProps` entries that carry Office Open XML metadata. Everything else
/// (`[Content_Types].xml`, `word/document.xml`, media, styles, ...) is
/// preserved.
const Set<String> _openXmlMetadataPaths = {
  'docProps/core.xml',
  'docProps/app.xml',
  'docProps/custom.xml',
};

/// Strips Office Open XML metadata from [bytes] (docx, xlsx, pptx).
///
/// Removes the `docProps/core.xml`, `docProps/app.xml` and
/// `docProps/custom.xml` entries by re-encoding the zip container without
/// them; every other entry keeps its content verbatim. When the document has
/// no `docProps/core.xml` entry the original [bytes] are returned unchanged
/// (the same instance, not re-encoded).
///
/// Throws [FormatException] when [bytes] is not a valid zip archive, when the
/// archive is too large to repack, or when stripping would leave no entries.
Uint8List stripOpenXml(Uint8List bytes) {
  final bool hasCoreProperties;
  try {
    hasCoreProperties = zipArchiveContainsEntry(bytes, 'docProps/core.xml');
  } on FormatException {
    throw const FormatException('Invalid office document');
  }
  if (!hasCoreProperties) {
    return bytes;
  }
  return repackZipWithoutEntries(bytes, skipPaths: _openXmlMetadataPaths);
}
