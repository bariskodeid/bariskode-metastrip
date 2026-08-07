import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Section label used for every WebP field.
const String _webpSection = 'WebP Metadata';

/// Maximum number of chunks walked inside one WebP container.
const int _maxWebpChunks = 64;

/// Extracts EXIF and XMP metadata chunks from raw WebP [bytes].
///
/// Walks the RIFF chunk stream after the `WEBP` signature, surfacing `EXIF`
/// and `XMP ` chunks as fields. Returns a status field when the bytes are not
/// a WebP container or carry no metadata chunks; this function never throws.
Future<List<MetadataFieldEntity>> extractWebp(Uint8List bytes) async {
  try {
    if (!_isWebp(bytes)) {
      return [statusField(_webpSection, 'Status', 'Not a valid WebP file')];
    }

    final fields = <MetadataFieldEntity>[];
    var offset = 12;
    for (var i = 0; i < _maxWebpChunks && offset + 8 <= bytes.length; i++) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = ByteData.sublistView(
        bytes,
        offset + 4,
        offset + 8,
      ).getUint32(0, Endian.little);
      final dataStart = offset + 8;
      final dataEnd = dataStart + size;
      if (dataEnd > bytes.length) break;

      if (id == 'EXIF') {
        fields.add(
          MetadataFieldEntity(
            section: _webpSection,
            label: 'EXIF',
            value: truncateMetadataValue('EXIF data present ($size bytes)'),
          ),
        );
      } else if (id == 'XMP ') {
        final value = utf8.decode(
          bytes.sublist(dataStart, dataEnd),
          allowMalformed: true,
        ).trim();
        fields.add(
          MetadataFieldEntity(
            section: _webpSection,
            label: 'XMP',
            value: truncateMetadataValue(value),
          ),
        );
      }

      offset = dataEnd;
      if (size.isOdd) offset++; // pad byte alignment
    }

    if (fields.isEmpty) {
      return [statusField(_webpSection, 'Status', 'No WebP metadata found')];
    }
    return fields;
  } catch (_) {
    return [statusField(_webpSection, 'Status', 'No WebP metadata found')];
  }
}

/// Whether [bytes] starts with a `RIFF`/`WEBP` container signature.
bool _isWebp(Uint8List bytes) {
  if (bytes.length < 12) return false;
  if (bytes[0] != 0x52 ||
      bytes[1] != 0x49 ||
      bytes[2] != 0x46 ||
      bytes[3] != 0x46) {
    return false; // 'RIFF'
  }
  return bytes[8] == 0x57 && // 'W'
      bytes[9] == 0x45 && // 'E'
      bytes[10] == 0x42 && // 'B'
      bytes[11] == 0x50; // 'P'
}