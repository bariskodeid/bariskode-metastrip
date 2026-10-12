import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
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
/// with comment packets reassembled across pages). Returns
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
/// Walks `OggS` pages and concatenates segment data until a lacing value below
/// 255 ends a packet, so a comment packet spanning several pages is
/// reassembled. Only packets starting with the `vorbis` / `OpusTags`
/// markers are buffered, and a reassembled packet larger than
/// [AppConstants.maxAudioScanBytes] is rejected.
List<MetadataFieldEntity> _extractOgg(Uint8List bytes) {
  const signature = [0x4F, 0x67, 0x67, 0x53]; // 'OggS'
  var offset = 0;
  var foundPage = false;
  final packet = BytesBuilder(copy: false);
  var skipping = false; // current packet is not a comment packet

  while (offset + 27 <= bytes.length) {
    if (!_startsWith(bytes, signature, offset)) break;
    foundPage = true;

    final segmentCount = bytes[offset + 26];
    final tableStart = offset + 27;
    final tableEnd = tableStart + segmentCount;
    if (tableEnd > bytes.length) break;

    var cursor = tableEnd;
    for (var i = 0; i < segmentCount; i++) {
      final lace = bytes[tableStart + i];
      if (cursor + lace > bytes.length) {
        cursor = bytes.length + 1;
        break;
      }
      if (!skipping) {
        packet.add(Uint8List.sublistView(bytes, cursor, cursor + lace));
        if (packet.length > AppConstants.maxAudioScanBytes) {
          return [
            statusField(
              'Audio Vorbis',
              'Status',
              'Unable to parse Vorbis comments',
            ),
          ];
        }
        if (packet.length >= 8 && !_isCommentPacketStart(packet)) {
          skipping = true;
          packet.clear();
        }
      }
      cursor += lace;
      if (lace < 255) {
        if (!skipping) {
          final parsed = _parseCommentPacket(packet.takeBytes());
          if (parsed != null) return parsed;
        }
        skipping = false;
        packet.clear();
      }
    }
    if (cursor > bytes.length) break; // truncated page
    if (cursor <= offset) break; // defensive: no progress
    offset = cursor;
  }

  if (foundPage) {
    return [
      statusField('Audio Vorbis', 'Status', 'No Vorbis comments found'),
    ];
  }
  return [
    statusField('Audio Vorbis', 'Status', 'Unable to parse Vorbis comments'),
  ];
}

/// Whether the buffered packet prefix is a Vorbis or Opus comment marker.
bool _isCommentPacketStart(BytesBuilder packet) {
  final head = packet.toBytes();
  return (head[0] == 0x03 && _asciiEquals(head, 1, 'vorbis')) ||
      _asciiEquals(head, 0, 'OpusTags');
}

/// Parses [packet] when it starts with a Vorbis/Opus comment marker.
List<MetadataFieldEntity>? _parseCommentPacket(Uint8List packet) {
  if (packet.length >= 7 &&
      packet[0] == 0x03 &&
      _asciiEquals(packet, 1, 'vorbis')) {
    return _parseCommentBlock(packet.sublist(7));
  }
  if (packet.length >= 8 && _asciiEquals(packet, 0, 'OpusTags')) {
    return _parseCommentBlock(packet.sublist(8));
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
  void add(String rawKey, String value) {
    String label;
    MetadataFieldId? id;
    try {
      final normalizedKey = MetadataFieldId.normalizeVorbisCommentKey(rawKey);
      label = _commentLabels[normalizedKey] ?? normalizedKey;
      id = MetadataFieldId.vorbisComment(normalizedKey);
    } on ArgumentError {
      // Not removable by stable ID; still shown to the user.
      label = rawKey;
    }
    fields.add(
      MetadataFieldEntity(
        section: 'Audio Vorbis',
        label: label,
        value: truncateMetadataValue(value),
        id: id,
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
    final entry = utf8.decode(
      data.sublist(offset, offset + entryLength),
      allowMalformed: true,
    );
    offset += entryLength;

    final equals = entry.indexOf('=');
    if (equals <= 0) continue;
    add(entry.substring(0, equals), entry.substring(equals + 1));
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
