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
  } else if (label == 0xFF && _isXmpApplication(bytes, cursor)) {
    // XMP is not sub-block framed: the UTF-8 packet follows the 11-byte
    // application identifier directly, ending at a 258-byte magic trailer.
    final start = cursor + 1 + 11;
    final trailer = _findXmpTrailer(bytes, start);
    String value;
    if (trailer < 0) {
      value = 'XMP packet present (no valid trailer)';
      cursor = _skipSubBlocks(bytes, cursor, null);
    } else {
      final packet = utf8
          .decode(bytes.sublist(start, trailer), allowMalformed: true)
          .trim();
      value = packet.isEmpty ? 'XMP packet present' : packet;
      cursor = trailer + _xmpTrailerLength;
    }
    fields.add(
      MetadataFieldEntity(
        section: _gifSection,
        label: 'XMP',
        value: truncateMetadataValue(value),
        isPrivacySensitive: true,
      ),
    );
  } else {
    // Graphic control (0xF9), other application (0xFF) and plain text (0x01)
    // extensions all share the sub-block framing.
    cursor = _skipSubBlocks(bytes, cursor, null);
  }
  return cursor;
}

/// Skips an image descriptor, its local color table and the LZW data.
///
/// The descriptor is 10 bytes counting the `0x2C` introducer (left, top,
/// width, height at two bytes each, then the packed byte at offset 9),
/// matching the remover's GIF walker. Returns the offset of the next block
/// after the image's sub-block stream.
int _skipImage(Uint8List bytes, int offset) {
  var cursor = offset + 10;
  if (cursor > bytes.length) return bytes.length;
  final packed = bytes[offset + 9];
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

/// Whether the sub-block at [offset] is the `XMP DataXMP` application id.
bool _isXmpApplication(Uint8List bytes, int offset) {
  const magic = 'XMP DataXMP';
  if (offset + 1 + magic.length > bytes.length) return false;
  if (bytes[offset] != magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (bytes[offset + 1 + i] != magic.codeUnitAt(i)) return false;
  }
  return true;
}

/// Length of the GIF XMP magic trailer: 0x01, 0xFF down to 0x00, 0x00.
const int _xmpTrailerLength = 258;

/// Returns the offset of the first valid XMP magic trailer at or after
/// [start], or -1 when none is present within [bytes].
int _findXmpTrailer(Uint8List bytes, int start) {
  for (var i = start; i + _xmpTrailerLength <= bytes.length; i++) {
    if (bytes[i] != 0x01) continue;
    var ok = true;
    for (var k = 0; k < 256 && ok; k++) {
      ok = bytes[i + 1 + k] == 0xFF - k;
    }
    if (ok && bytes[i + 257] == 0x00) return i;
  }
  return -1;
}
