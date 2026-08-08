import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/format/format_registry.dart' as capabilities;
import 'package:metastrip/features/viewer/data/datasources/extractors/bmp_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/exif_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/gif_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/id3_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/odf_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/openxml_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/pdf_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/png_text_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/riff_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/vorbis_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/webp_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/zip_extractor.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Describes how one file extension is introspected by the datasource.
///
/// The spec decides how many bytes are read from disk (`boundedRead` versus
/// `maxBytes`) and which extractor parses the payload. `extractor` may be null
/// for formats that only surface filesystem fields.
class FormatExtractionSpec {
  const FormatExtractionSpec({
    required this.extractor,
    required this.boundedRead,
    required this.maxBytes,
    this.skipSection = 'Contents',
    this.skipLabel = 'Scan',
  });

  /// Parser for the payload, or null when the format is filesystem-only.
  ///
  /// The closure captures any extension argument the extractor needs (for
  /// example `extractVorbis`), so callers only pass the raw bytes.
  final Future<List<MetadataFieldEntity>> Function(Uint8List bytes)? extractor;

  /// Whether only a bounded prefix (plus an MP3 tail) is read from disk.
  ///
  /// When true `maxBytes` is ignored and [AppConstants.maxAudioScanBytes]
  /// limits the read. When false the full payload is read up to `maxBytes`.
  final bool boundedRead;

  /// Maximum payload size in bytes for full-read mode; 0 when bounded.
  final int maxBytes;

  /// Section used for the skip status field when the file exceeds `maxBytes`.
  final String skipSection;

  /// Label used for the skip status field when the file exceeds `maxBytes`.
  final String skipLabel;
}

/// Registered extension-to-spec map (keys are lower-cased extensions).
final Map<String, FormatExtractionSpec> _specs = {
  // Images with inline metadata.
  for (final extension in ['jpg', 'jpeg', 'tif', 'tiff'])
    extension: FormatExtractionSpec(
      extractor: (bytes) => extractExif(bytes),
      boundedRead: false,
      maxBytes: AppConstants.maxInlineExifSizeBytes,
      skipSection: 'Image EXIF',
      skipLabel: 'EXIF Scan',
    ),
  'png': const FormatExtractionSpec(
    extractor: extractPngText,
    boundedRead: false,
    maxBytes: AppConstants.maxInlineExifSizeBytes,
    skipSection: 'PNG Text',
    skipLabel: 'PNG Text Scan',
  ),
  'gif': const FormatExtractionSpec(
    extractor: extractGif,
    boundedRead: false,
    maxBytes: AppConstants.maxInlineExifSizeBytes,
    skipSection: 'GIF Text',
  ),
  'webp': const FormatExtractionSpec(
    extractor: extractWebp,
    boundedRead: false,
    maxBytes: AppConstants.maxInlineExifSizeBytes,
    skipSection: 'WebP Metadata',
  ),
  'bmp': const FormatExtractionSpec(
    extractor: extractBmp,
    boundedRead: false,
    maxBytes: AppConstants.maxInlineExifSizeBytes,
    skipSection: 'BMP',
  ),
  // Audio formats.
  'mp3': const FormatExtractionSpec(
    extractor: extractId3,
    boundedRead: true,
    maxBytes: 0,
    skipSection: 'Audio ID3',
  ),
  for (final extension in ['flac', 'ogg', 'opus'])
    extension: FormatExtractionSpec(
      extractor: (bytes) => extractVorbis(bytes, extension: extension),
      boundedRead: true,
      maxBytes: 0,
      skipSection: 'Audio Vorbis',
    ),
  for (final extension in ['wav', 'aiff'])
    extension: FormatExtractionSpec(
      extractor: (bytes) => extractRiff(bytes, extension: extension),
      boundedRead: false,
      maxBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
      skipSection: 'Audio RIFF',
    ),
  // Documents.
  'pdf': const FormatExtractionSpec(
    extractor: extractPdf,
    boundedRead: false,
    maxBytes: AppConstants.maxPdfExtractionSizeBytes,
    skipSection: 'PDF Document',
  ),
  for (final extension in ['docx', 'xlsx', 'pptx'])
    extension: FormatExtractionSpec(
      extractor: (bytes) => extractOpenXml(bytes, extension: extension),
      boundedRead: false,
      maxBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
      skipSection: openXmlSection,
    ),
  for (final extension in ['odt', 'ods', 'odp'])
    extension: const FormatExtractionSpec(
      extractor: extractOdf,
      boundedRead: false,
      maxBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
      skipSection: odfSection,
    ),
  // Archives.
  for (final extension in ['zip', 'apk', 'epub'])
    extension: FormatExtractionSpec(
      extractor: (bytes) => extractZip(bytes, extension: extension),
      boundedRead: false,
      maxBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
      skipSection: archiveSection,
    ),
};

/// Returns the extraction spec for [extension], or null when the extension
/// only surfaces filesystem fields.
///
/// Matching is case-insensitive; unknown extensions such as `mp4`, `heic` or
/// `rtf` resolve to null.
FormatExtractionSpec? formatSpecFor(String extension) {
  final normalized = capabilities.FormatRegistry.normalizeExtension(extension);
  final capability = capabilities.FormatRegistry.standard.lookup(normalized);
  if (capability?.supportsExtraction != true) {
    return null;
  }
  return _specs[normalized];
}

/// Every extension that has a registered extraction spec.
Set<String> get supportedExtractionExtensions => Set.unmodifiable(_specs.keys);

/// Reports missing or undeclared concrete extraction handler routes.
List<String> get extractionHandlerConsistencyIssues =>
    capabilities.FormatRegistry.standard
        .handlerMapConsistencyIssues(extractionHandlerExtensions: _specs.keys);
