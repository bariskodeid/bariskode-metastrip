import 'dart:typed_data';

/// Length of the `fLaC` magic at the start of a FLAC file.
const int _flacMagicLength = 4;

/// Length of a FLAC metadata block header (flags byte + 3-byte big-endian
/// size).
const int _flacBlockHeaderLength = 4;

/// FLAC metadata block type for VORBIS_COMMENT.
const int _flacVorbisCommentType = 4;

/// Maximum number of leading Ogg pages scanned for a comment packet.
const int _oggMaxPages = 8;

/// Length of an Ogg page header (capture pattern through segment count).
const int _oggHeaderLength = 27;

/// Offset of the CRC field inside the Ogg page header (bytes 22..25).
const int _oggCrcOffset = 22;

/// Length of the Ogg CRC field within the page header.
const int _oggCrcFieldLength = 4;

const List<int> _flacMagic = [0x66, 0x4C, 0x61, 0x43]; // 'fLaC'
const List<int> _oggMagic = [0x4F, 0x67, 0x67, 0x53]; // 'OggS'
const List<int> _vorbisCommentMarker = [
  0x03,
  0x76,
  0x6F,
  0x72,
  0x62,
  0x69,
  0x73,
]; // '\x03vorbis'
const List<int> _opusTagMarker = [
  0x4F,
  0x70,
  0x75,
  0x73,
  0x54,
  0x61,
  0x67,
  0x73,
]; // 'OpusTags'

/// Strips Vorbis comments from raw [bytes] for the given [extension].
///
/// Supports FLAC (`flac`) and Ogg (`ogg`) containers.
///
/// **FLAC path**: after validating the `fLaC` magic, metadata blocks are
/// walked (flags byte, 3-byte big-endian length) and every VORBIS_COMMENT
/// block (type 4) is dropped while all other blocks are copied verbatim. The
/// audio frames following the last metadata block are appended untouched. If
/// the dropped comment block was the final metadata block, the last kept
/// block is promoted to carry the `last` flag so the stream stays
/// well-formed; when the comment block is the only metadata block, there is
/// no block to promote and the file has no audio stream, so a
/// [FormatException] is thrown instead of returning a broken file. Output
/// always starts with `fLaC`.
///
/// **Ogg path** (pragmatic, in-place): the first up to 8 pages are walked
/// (`OggS` header, 4-byte little-endian fields, segment count and lacing
/// table) and packets are reconstructed from the segment table. A packet
/// starting with `\x03vorbis` (Vorbis comment header) or `OpusTags` is
/// rewritten in place: the vendor string is kept but the comment count is
/// zeroed, and the packet is padded with zero bytes so its length — and
/// therefore the page length and segment table — stays unchanged. The page
/// CRC is then recomputed (standard reflected CRC-32, polynomial
/// `0x04C11DB7`, init 0, no final XOR, stored little-endian) over the header
/// without the CRC field plus the segment count, table and payload. All
/// other pages and packets are copied verbatim. When no comment packet is
/// found within the first 8 pages the original bytes are returned.
///
/// Known limitations of the Ogg approach: only the first 8 pages are
/// scanned; only comment packets fully contained in a single page are
/// rewritten (a comment packet split across pages is left untouched); and
/// the zero padding after the zeroed count is trailing garbage for strict
/// parsers that ignore the count field, though parsers honoring the count
/// stop at zero comments. The common layout (identification header on the
/// first page, self-contained comment packet on the second) is handled.
///
/// Bytes without a comment block/packet are returned unchanged (the same
/// instance). Throws [FormatException] for invalid input: a missing `fLaC` /
/// `OggS` magic, truncated blocks or pages, a FLAC whose only metadata block
/// is the comment block, a malformed comment packet, or an unsupported
/// [extension].
Uint8List stripVorbisComments(Uint8List bytes, {required String extension}) {
  switch (extension.toLowerCase()) {
    case 'flac':
      return _stripFlac(bytes);
    case 'ogg':
      return _stripOgg(bytes);
    default:
      throw FormatException('Unsupported extension: $extension');
  }
}

/// Removes VORBIS_COMMENT metadata blocks from a FLAC stream.
Uint8List _stripFlac(Uint8List bytes) {
  if (!_startsWith(bytes, _flacMagic, 0)) {
    throw const FormatException('Not a valid FLAC file');
  }

  final output = BytesBuilder(copy: false);
  output.add(bytes.sublist(0, _flacMagicLength));

  var offset = _flacMagicLength;
  var foundComment = false;
  var droppedLastComment = false;
  var lastStoredBlockStart = -1;

  while (offset + _flacBlockHeaderLength <= bytes.length) {
    final flags = bytes[offset];
    final isLast = flags & 0x80 != 0;
    final blockType = flags & 0x7F;
    final blockSize = (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final bodyEnd = offset + _flacBlockHeaderLength + blockSize;
    if (bodyEnd > bytes.length) {
      throw const FormatException('Truncated FLAC metadata block');
    }

    if (blockType == _flacVorbisCommentType) {
      foundComment = true;
      droppedLastComment = isLast;
      offset = bodyEnd;
      if (isLast) break;
      continue;
    }

    lastStoredBlockStart = output.length;
    output.add(bytes.sublist(offset, bodyEnd));
    offset = bodyEnd;
    if (isLast) break;
  }

  if (!foundComment) {
    return bytes;
  }
  if (offset < bytes.length) {
    output.add(bytes.sublist(offset));
  }
  if (droppedLastComment && lastStoredBlockStart < 0) {
    throw const FormatException('FLAC has no audio stream');
  }

  final result = output.takeBytes();
  if (droppedLastComment) {
    result[lastStoredBlockStart] |= 0x80;
  }
  return result;
}

/// Rewrites Vorbis/Opus comment packets in place across the leading Ogg
/// pages, preserving page boundaries and recomputing page CRCs.
Uint8List _stripOgg(Uint8List bytes) {
  if (!_startsWith(bytes, _oggMagic, 0)) {
    throw const FormatException('Not a valid Ogg file');
  }

  final output = Uint8List.fromList(bytes);
  var modified = false;
  var offset = 0;
  var pagesSeen = 0;

  while (
      offset + _oggHeaderLength <= bytes.length && pagesSeen < _oggMaxPages) {
    if (!_startsWith(bytes, _oggMagic, offset)) break;
    final segmentCount = bytes[offset + 26];
    final tableStart = offset + _oggHeaderLength;
    final tableEnd = tableStart + segmentCount;
    if (tableEnd > bytes.length) {
      throw const FormatException('Truncated Ogg page');
    }
    var bodyEnd = tableEnd;
    for (var i = 0; i < segmentCount; i++) {
      bodyEnd += bytes[tableStart + i];
    }
    if (bodyEnd > bytes.length) {
      throw const FormatException('Truncated Ogg page');
    }

    var packetStart = tableEnd;
    var packetEnd = tableEnd;
    for (var i = 0; i < segmentCount; i++) {
      packetEnd += bytes[tableStart + i];
      if (bytes[tableStart + i] < 255) {
        if (_isCommentPacket(bytes, packetStart, packetEnd)) {
          _replaceCommentPacket(output, packetStart, packetEnd);
          modified = true;
          _writeOggPageCrc(output, offset, bodyEnd);
        }
        packetStart = packetEnd;
      }
    }

    offset = bodyEnd;
    pagesSeen++;
  }

  if (!modified) return bytes;
  return output;
}

/// Whether the packet in [bytes] starting at [start] (ending at [end])
/// begins with a Vorbis or Opus comment marker.
bool _isCommentPacket(Uint8List bytes, int start, int end) {
  final length = end - start;
  return (length >= _vorbisCommentMarker.length &&
          _startsWith(bytes, _vorbisCommentMarker, start)) ||
      (length >= _opusTagMarker.length &&
          _startsWith(bytes, _opusTagMarker, start));
}

/// Rewrites the comment packet in [output] (offsets [start]..[end]) in place.
///
/// Keeps the marker and vendor string, zeroes the comment count and pads the
/// rest of the packet with zero bytes so its length is unchanged and the
/// segment table stays valid.
void _replaceCommentPacket(Uint8List output, int start, int end) {
  final length = end - start;
  final markerLength = _startsWith(output, _opusTagMarker, start)
      ? _opusTagMarker.length
      : _vorbisCommentMarker.length;

  final view = ByteData.sublistView(output, start, end);
  final vendorLength = view.getUint32(markerLength, Endian.little);
  final countOffset = markerLength + 4 + vendorLength;
  if (countOffset + 4 > length) {
    throw const FormatException('Malformed Vorbis comment packet');
  }

  final minimal = Uint8List(length);
  minimal.setRange(
    0,
    markerLength,
    output,
    start,
  );
  ByteData.sublistView(minimal).setUint32(
    markerLength,
    vendorLength,
    Endian.little,
  );
  minimal.setRange(
    markerLength + 4,
    markerLength + 4 + vendorLength,
    output,
    start + markerLength + 4,
  );
  ByteData.sublistView(minimal).setUint32(countOffset, 0, Endian.little);
  output.setRange(start, end, minimal);
}

/// Recomputes and writes the CRC of the Ogg page [output] spanning
/// [pageStart]..[pageEnd], zeroing/overwriting the 4-byte CRC field.
void _writeOggPageCrc(Uint8List output, int pageStart, int pageEnd) {
  final crc = _oggPageCrc(output.sublist(pageStart, pageEnd));
  ByteData.sublistView(output).setUint32(
    pageStart + _oggCrcOffset,
    crc,
    Endian.little,
  );
}

/// Computes the Ogg page CRC over a full [pageBytes] page.
///
/// Standard reflected CRC-32: polynomial `0x04C11DB7` (`0xEDB88320` in
/// reflected form), init 0, no final XOR. Covers every byte of the page
/// except the CRC field itself: the header up to the CRC (bytes 0..21) plus
/// the segment count, segment table and payload (bytes 26..end).
int _oggPageCrc(Uint8List pageBytes) {
  var crc = 0;
  void update(int value) {
    crc ^= value;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }

  for (var i = 0; i < _oggCrcOffset; i++) {
    update(pageBytes[i]);
  }
  for (var i = _oggCrcOffset + _oggCrcFieldLength; i < pageBytes.length; i++) {
    update(pageBytes[i]);
  }
  return crc;
}

/// Whether [bytes] starts with [prefix] at [offset].
bool _startsWith(Uint8List bytes, List<int> prefix, int offset) {
  if (offset + prefix.length > bytes.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[offset + i] != prefix[i]) return false;
  }
  return true;
}
