import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Section label used for every BMP field.
const String _bmpSection = 'BMP';

/// Extracts metadata from raw BMP [bytes].
///
/// BMP has no single standardized metadata container that this extractor
/// currently parses. Returns a scoped status for signature-valid input and an
/// invalid status for bytes that lack the `BM` signature; this function never
/// throws.
Future<List<MetadataFieldEntity>> extractBmp(Uint8List bytes) async {
  if (bytes.length < 2 || bytes[0] != 0x42 || bytes[1] != 0x4D) {
    return [statusField(_bmpSection, 'Status', 'Not a valid BMP file')];
  }
  return [
    statusField(_bmpSection, 'Status', 'No supported BMP metadata detected'),
  ];
}
