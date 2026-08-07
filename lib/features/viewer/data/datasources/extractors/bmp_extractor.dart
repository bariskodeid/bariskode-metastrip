import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Section label used for every BMP field.
const String _bmpSection = 'BMP';

/// Extracts metadata from raw BMP [bytes].
///
/// BMP has no standardized metadata container: the BITMAPV4/V5 header fields
/// are rarely populated and there is no chunk or text layer to walk, so a
/// valid file yields a single explanatory status field. Returns an invalid
/// status when [bytes] lack the `BM` signature; this function never throws.
Future<List<MetadataFieldEntity>> extractBmp(Uint8List bytes) async {
  if (bytes.length < 2 || bytes[0] != 0x42 || bytes[1] != 0x4D) {
    return [statusField(_bmpSection, 'Status', 'Not a valid BMP file')];
  }
  return [
    statusField(_bmpSection, 'Status', 'BMP has no metadata container'),
  ];
}
