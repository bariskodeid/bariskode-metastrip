import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Extracts EXIF metadata fields from raw image [bytes].
///
/// Returns a single status field when no EXIF data is present or when the
/// bytes cannot be parsed as EXIF.
Future<List<MetadataFieldEntity>> extractExif(Uint8List bytes) async {
  try {
    final tags = await readExifFromBytes(_exifSource(bytes));
    if (tags.isEmpty) {
      return [statusField('Image EXIF', 'Status', 'No EXIF metadata found')];
    }

    return tags.entries
        .map(
          (entry) => MetadataFieldEntity(
            section: 'Image EXIF',
            label: entry.key,
            value: entry.value.printable,
            isPrivacySensitive: isExifPrivacySensitive(entry.key),
          ),
        )
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  } catch (_) {
    return [
      statusField('Image EXIF', 'Status', 'Unable to parse EXIF metadata'),
    ];
  }
}

/// Returns the bytes to hand to the `exif` package.
///
/// The package only scans the first ~4 KB of a JPEG for the Exif APP1
/// segment, so EXIF behind a large APPn block (C2PA/JUMBF in APP11, a big ICC
/// profile in APP2, or XMP in an earlier APP1) is missed. For a JPEG this lifts
/// the Exif APP1 into a minimal SOI + APP1 + EOI stream; every EXIF offset is
/// relative to the TIFF header inside that segment, so nothing else is needed.
Uint8List _exifSource(Uint8List bytes) {
  final segment = _findJpegExifSegment(bytes);
  if (segment == null) return bytes;
  return Uint8List(segment.length + 4)
    ..setRange(0, 2, const [0xFF, 0xD8])
    ..setRange(2, segment.length + 2, segment)
    ..setRange(segment.length + 2, segment.length + 4, const [0xFF, 0xD9]);
}

/// Walks the JPEG marker segments up to the scan and returns the first APP1
/// segment (marker through payload) that starts with `Exif\0\0`.
Uint8List? _findJpegExifSegment(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) return null;
    final marker = bytes[offset + 1];
    if (marker == 0xFF) {
      offset++; // fill byte
      continue;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      offset += 2; // standalone marker, no length
      continue;
    }
    if (marker == 0xDA || marker == 0xD9) return null; // scan or EOI
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    final end = offset + 2 + length;
    if (length < 2 || end > bytes.length) return null;
    if (marker == 0xE1 && length >= 8 && _hasExifHeader(bytes, offset + 4)) {
      return Uint8List.sublistView(bytes, offset, end);
    }
    offset = end;
  }
  return null;
}

bool _hasExifHeader(Uint8List bytes, int start) =>
    bytes[start] == 0x45 && // E
    bytes[start + 1] == 0x78 && // x
    bytes[start + 2] == 0x69 && // i
    bytes[start + 3] == 0x66 && // f
    bytes[start + 4] == 0 &&
    bytes[start + 5] == 0;
