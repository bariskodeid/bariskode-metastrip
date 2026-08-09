import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

/// Human labels for well-known Vorbis comment keys.
const Map<String, String> _commentLabels = {
  'TITLE': 'Title',
  'ARTIST': 'Artist',
  'ALBUM': 'Album',
  'DATE': 'Date',
  'GENRE': 'Genre',
  'TRACKNUMBER': 'Track',
  'COMMENT': 'Comment',
  'COPYRIGHT': 'Copyright',
  'ENCODER': 'Encoder',
  'ENCODED-BY': 'Encoded By',
  'COMPOSER': 'Composer',
  'DESCRIPTION': 'Description',
  'ORGANIZATION': 'Organization',
  'CONTACT': 'Contact',
  'LICENSE': 'License',
  'LOCATION': 'Location',
};

/// Maximum number of comment entries read defensively.
const int _maxComments = 64;

/// Extracts Vorbis comments from raw [bytes] for the given [extension].
///
/// Supports FLAC (`flac`) metadata blocks and Ogg streams (`.ogg` and `.opus`,
/// including a pragmatic substring fallback for the comment header). Returns
/// a single status field when the container is invalid or holds no comments;
/// this function never throws.
Future<List<MetadataFieldEntity>> extractVorbis(
  Uint8List bytes, {
  required String extension,
}) async {
  try {
    final ext = extension.toLowerCase();
    if (ext == 'flac') return _extractFlac(bytes);
    if (ext == 'ogg' || ext == 'opus') return _extractOgg(bytes);
    return [
      statusField('Audio Vorbis', 'Status', 'Unable to parse Vorbis comments'),
    ];
  } catch (_) {
    return [
      statusField('Audio Vorbis', 'Status', 'Unable to parse Vorbis comments'),
    ];
  }
}

/// Scans FLAC metadata blocks for a VORBIS_COMMENT block (type 4).
List<MetadataFieldEntity> _extractFlac(Uint8List bytes) {
  const signature = [0x66, 0x4C, 0x61, 0x43]; // 'fLaC'
  if (!_startsWith(bytes, signature, 0)) {
    return [
      statusField('Audio Vorbis', 'Status', 'Unable to parse Vorbis comments'),
    ];
  }

  var offset = 4;
  while (offset + 4 <= bytes.length) {
    final flags = bytes[offset];
    final isLast = flags & 0x80 != 0;
    final blockType = flags & 0x7F;
    final blockSize = (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final bodyStart = offset + 4;
    final bodyEnd = bodyStart + blockSize;
    if (bodyEnd > bytes.length) break;

    if (blockType == 4) {
      final comment = _parseCommentBlock(bytes.sublist(bodyStart, bodyEnd));
      if (comment != null) return comment;
    }

    if (isLast) break;
    offset = bodyEnd;
  }

  return [
    statusField('Audio Vorbis', 'Status', 'No Vorbis comments found'),
  ];
}

/// Scans Ogg pages and returns parsed comments from the comment packet.
///
/// Walks `OggS` pages, reconstructs packets from segment lacing values and
/// looks for the `\x03vorbis` / `OpusTags` comment packets. A conservative
/// substring fallback handles comment packets spanning pages.
List<MetadataFieldEntity> _extractOgg(Uint8List bytes) {
  const signature = [0x4F, 0x67, 0x67, 0x53]; // 'OggS'
  var offset = 0;
  var foundPage = false;

  while (offset + 27 <= bytes.length) {
    if (!_startsWith(bytes, signature, offset)) break;
    foundPage = true;

    final segmentCount = bytes[offset + 26];
    final tableStart = offset + 27;
    final tableEnd = tableStart + segmentCount;
    if (tableEnd > bytes.length) break;

    final result = _scanPagePackets(bytes, tableStart, tableEnd);
    if (result != null) return result;

    var cursor = tableEnd;
    for (var i = 0; i < segmentCount; i++) {
      cursor += bytes[tableStart + i];
    }
    if (cursor <= offset) break; // defensive: no progress
    offset = cursor;
  }

  if (foundPage) {
    final fallback = _findCommentFallback(bytes);
    if (fallback != null) return fallback;
    return [
      statusField('Audio Vorbis', 'Status', 'No Vorbis comments found'),
    ];
  }
  return [
    statusField('Audio Vorbis', 'Status', 'Unable to parse Vorbis comments'),
  ];
}

/// Rebuilds packets from one Ogg page and parses a comment packet if present.
///
/// Returns the parsed fields when any packet on the page carries a Vorbis or
/// Opus comment body, otherwise null.
List<MetadataFieldEntity>? _scanPagePackets(
  Uint8List bytes,
  int tableStart,
  int tableEnd,
) {
  var cursor = tableEnd;
  var packetStart = cursor;
  for (var i = 0; i < tableEnd - tableStart; i++) {
    final lace = bytes[tableStart + i];
    if (cursor + lace > bytes.length) return null;
    cursor += lace;
    if (lace < 255) {
      final packet = bytes.sublist(packetStart, cursor);
      final parsed = _parseCommentPacket(packet);
      if (parsed != null) return parsed;
      packetStart = cursor;
    }
  }
  return null;
}

/// Parses [packet] when it starts with a Vorbis/Opus comment marker.
List<MetadataFieldEntity>? _parseCommentPacket(Uint8List packet) {
  if (packet.length >= 2 &&
      packet[0] == 0x03 &&
      _asciiEquals(packet, 1, 'vorbis')) {
    return _parseCommentBlock(packet.sublist(7));
  }
  if (packet.length >= 8 && _asciiEquals(packet, 0, 'OpusTags')) {
    return _parseCommentBlock(packet.sublist(8));
  }
  return null;
}

/// Fallback: search for a comment header and parse what follows.
///
/// This belt-and-braces scan trades precision for robustness, handling files
/// whose comment packet spans multiple Ogg pages.
List<MetadataFieldEntity>? _findCommentFallback(Uint8List bytes) {
  const vorbisComment = [0x03, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73];
  const opusTag = [
    0x4F,
    0x70,
    0x75,
    0x73,
    0x54,
    0x61,
    0x67,
    0x73
  ]; // 'OpusTags'
  for (var i = 0; i + 8 <= bytes.length; i++) {
    if (_startsWith(bytes, vorbisComment, i)) {
      final comment = _parseCommentBlock(
        bytes.sublist(i + vorbisComment.length),
      );
      if (comment != null) return comment;
    }
    if (_startsWith(bytes, opusTag, i)) {
      final comment = _parseCommentBlock(bytes.sublist(i + opusTag.length));
      if (comment != null) return comment;
    }
  }
  return null;
}

/// Parses a VORBIS_COMMENT block body, returning fields or null.
///
/// Layout: 4-byte vendor length, vendor string, 4-byte comment count, then per
/// entry a 4-byte length and a `KEY=VALUE` UTF-8 payload. Returns null when
/// the block is malformed, an empty list when it is valid but comment-free.
List<MetadataFieldEntity>? _parseCommentBlock(Uint8List data) {
  if (data.length < 8) return null;
  final view = ByteData.sublistView(data);
  int offset = 0;

  final vendorLength = view.getUint32(offset, Endian.little);
  offset += 4 + vendorLength;
  if (offset + 4 > data.length) return null;

  final count = ByteData.sublistView(
    data,
    offset,
    offset + 4,
  ).getUint32(0, Endian.little);
  offset += 4;

  final fields = <MetadataFieldEntity>[];
  void add(String key, String value) {
    final normalizedKey = MetadataFieldId.normalizeVorbisCommentKey(key);
    final label = _commentLabels[normalizedKey] ?? normalizedKey;
    fields.add(
      MetadataFieldEntity(
        section: 'Audio Vorbis',
        label: label,
        value: truncateMetadataValue(value),
        id: MetadataFieldId.vorbisComment(normalizedKey),
        isPrivacySensitive: isTextPrivacySensitive(label),
      ),
    );
  }

  for (var i = 0; i < count && i < _maxComments; i++) {
    if (offset + 4 > data.length) break;
    final entryLength = ByteData.sublistView(
      data,
      offset,
      offset + 4,
    ).getUint32(0, Endian.little);
    offset += 4;
    if (offset + entryLength > data.length) break;
    final entry = utf8.decode(data.sublist(offset, offset + entryLength));
    offset += entryLength;

    final equals = entry.indexOf('=');
    if (equals <= 0) continue;
    final key = MetadataFieldId.normalizeVorbisCommentKey(
      entry.substring(0, equals),
    );
    final value = entry.substring(equals + 1);
    if (key.isNotEmpty) add(key, value);
  }
  return fields;
}

/// Whether [bytes] starts with [prefix] at [offset].
bool _startsWith(Uint8List bytes, List<int> prefix, int offset) {
  if (offset + prefix.length > bytes.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[offset + i] != prefix[i]) return false;
  }
  return true;
}

/// Whether [bytes] contains the ASCII [text] starting at [offset].
bool _asciiEquals(Uint8List bytes, int offset, String text) {
  final codes = text.codeUnits;
  if (offset + codes.length > bytes.length) return false;
  for (var i = 0; i < codes.length; i++) {
    if (bytes[offset + i] != codes[i]) return false;
  }
  return true;
}
