import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Section label used for every GIF field.
const String _gifSection = 'GIF Text';

/// Maximum number of comment extensions surfaced per file.
const int _maxGifComments = 8;

/// Extracts comment extensions from raw GIF [bytes].
///
/// Walks the GIF block stream (header, logical screen descriptor, global
/// color table and subsequent blocks), collecting `0x21 0xFE` comment
/// extensions and safely skipping image data, graphic control and application
/// extensions. Returns a single status field when the bytes are not a GIF or
/// hold no comments; this function never throws.
Future<List<MetadataFieldEntity>> extractGif(Uint8List bytes) async {
  try {
    if (!_isGif(bytes)) {
      return [statusField(_gifSection, 'Status', 'Not a valid GIF')];
    }

    final fields = <MetadataFieldEntity>[];
    var offset = _offsetAfterDescriptor(bytes);
    while (offset < bytes.length && fields.length < _maxGifComments) {
      final introducer = bytes[offset];
      if (introducer == 0x3B) break; // trailer
      if (introducer == 0x21) {
        offset = _scanExtension(bytes, offset, fields);
      } else if (introducer == 0x2C) {
        offset = _skipImage(bytes, offset);
      } else {
        break; // unknown block introducer
      }
    }

    if (fields.isEmpty) {
      return [statusField(_gifSection, 'Status', 'No GIF metadata found')];
    }
    return fields;
  } catch (_) {
    return [statusField(_gifSection, 'Status', 'No GIF metadata found')];
  }
}

/// Whether [bytes] starts with a `GIF87a` or `GIF89a` signature.
bool _isGif(Uint8List bytes) {
  if (bytes.length < 6) return false;
  if (bytes[0] != 0x47 || bytes[1] != 0x49 || bytes[2] != 0x46) return false;
  return bytes[3] == 0x38 &&
      (bytes[4] == 0x37 || bytes[4] == 0x39) &&
      bytes[5] == 0x61;
}

/// Returns the offset just past the 7-byte logical screen descriptor and the
/// global color table (when present) of [bytes].
int _offsetAfterDescriptor(Uint8List bytes) {
  var offset = 13; // 6-byte header + 7-byte logical screen descriptor
  if (offset > bytes.length) return bytes.length;
  final flags = bytes[10];
  if ((flags & 0x80) != 0) {
    offset += 3 * (1 << ((flags & 0x07) + 1));
  }
  return offset > bytes.length ? bytes.length : offset;
}

/// Processes the extension block starting at [offset] (`0x21` introducer).
///
/// Comment extensions (`0xFE`) are decoded into [fields]; all other extension
/// labels are skipped as sub-block streams. Returns the next block offset.
int _scanExtension(
  Uint8List bytes,
  int offset,
  List<MetadataFieldEntity> fields,
) {
  if (offset + 2 > bytes.length) return bytes.length;
  final label = bytes[offset + 1];
  var cursor = offset + 2;
  if (label == 0xFE) {
    final data = BytesBuilder(copy: false);
    cursor = _skipSubBlocks(bytes, cursor, data);
    final comment = utf8.decode(data.takeBytes(), allowMalformed: true).trim();
    if (comment.isNotEmpty) {
      fields.add(
        MetadataFieldEntity(
          section: _gifSection,
          label: 'Comment',
          value: truncateMetadataValue(comment),
          isPrivacySensitive: isTextPrivacySensitive('comment'),
        ),
      );
    }
  } else {
    // Graphic control (0xF9), application (0xFF) and plain text (0x01)
    // extensions all share the sub-block framing.
    cursor = _skipSubBlocks(bytes, cursor, null);
  }
  return cursor;
}

/// Skips an image descriptor, its local color table and the LZW data.
///
/// Returns the offset of the next block after the image's sub-block stream.
int _skipImage(Uint8List bytes, int offset) {
  var cursor = offset + 9; // 9-byte image descriptor
  if (cursor > bytes.length) return bytes.length;
  final packed = bytes[offset + 8];
  if ((packed & 0x80) != 0) {
    cursor += 3 * (1 << ((packed & 0x07) + 1));
  }
  if (cursor >= bytes.length) return bytes.length;
  cursor++; // LZW minimum code size byte
  return _skipSubBlocks(bytes, cursor, null);
}

/// Skips the sub-block stream starting at [offset], appending data bytes to
/// [sink] when provided. Returns the offset just past the terminator.
int _skipSubBlocks(Uint8List bytes, int offset, BytesBuilder? sink) {
  var cursor = offset;
  var length = cursor < bytes.length ? bytes[cursor] : -1;
  while (length != 0 && cursor + 1 + length <= bytes.length) {
    if (sink != null) sink.add(bytes.sublist(cursor + 1, cursor + 1 + length));
    cursor += 1 + length;
    length = cursor < bytes.length ? bytes[cursor] : -1;
  }
  if (cursor < bytes.length) cursor++; // zero-length terminator
  return cursor;
}
