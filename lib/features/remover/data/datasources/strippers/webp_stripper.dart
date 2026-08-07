import 'dart:typed_data';

/// Maximum number of chunks walked within one WebP container before giving up.
///
/// Real WebP files hold at most a handful of chunks plus one chunk per
/// animation frame; a longer walk indicates a corrupt size field, so the walk
/// aborts instead of looping.
const int _maxWebpChunks = 10000;

/// Length of a RIFF chunk header: id (4) + size (4).
const int _chunkHeaderLength = 8;

/// WebP chunks carrying metadata; dropped by [stripWebp].
const Set<String> _webpDroppedChunks = {'EXIF', 'XMP '};

/// VP8X feature-flag bits (WebP container spec, first payload byte, bits
/// counted LSB-first): bit 7-6 reserved, bit 5 (0x20) ICC profile, bit 4
/// (0x10) alpha, bit 3 (0x08) EXIF metadata, bit 2 (0x04) XMP metadata,
/// bit 1 (0x02) animation, bit 0 reserved.
const int _vp8xExifFlag = 0x08;
const int _vp8xXmpFlag = 0x04;

/// Strips metadata chunks from raw WebP [bytes].
///
/// Validates the `RIFF`/`WEBP` container signature and walks the chunk stream
/// from offset 12. Each chunk is a 4-byte ASCII id, a 4-byte little-endian
/// payload size and the payload itself, followed by a pad byte when the
/// payload size is odd. `EXIF` and `XMP ` (trailing space) chunks are dropped;
/// every other chunk (`VP8 `, `VP8L`, `VP8X`, `ANIM`, `ANMF`, `ICCP`, `ALPH`,
/// ...) is copied verbatim, including its original pad byte.
///
/// When a `VP8X` extended header (payload ≥ 10 bytes) is present and a
/// metadata chunk was dropped, its feature-flag byte (the first payload byte)
/// is updated: the EXIF bit (0x08) is cleared after an `EXIF` drop and the
/// XMP bit (0x04) after an `XMP ` drop. The RIFF size field (offset 4,
/// little-endian) is rewritten as `output length - 8`.
///
/// Files without any metadata chunk are returned unchanged (the same
/// instance). Throws [FormatException] for a missing signature, a truncated
/// chunk header or payload, or a chunk walk longer than [_maxWebpChunks] (the
/// guard against corrupt size fields).
Uint8List stripWebp(Uint8List bytes) {
  if (!_isWebp(bytes)) {
    throw const FormatException('Not a valid WebP file');
  }

  final output = BytesBuilder(copy: false)..add(bytes.sublist(0, 12));
  var offset = 12;
  var droppedExif = false;
  var droppedXmp = false;
  var vp8xFlagOffset = -1;
  var removedAny = false;

  for (var i = 0; i < _maxWebpChunks; i++) {
    if (offset >= bytes.length) break;
    if (offset + _chunkHeaderLength > bytes.length) {
      throw const FormatException('Truncated WebP chunk header');
    }
    final id = String.fromCharCodes(
      bytes.sublist(offset, offset + _chunkHeaderLength - 4),
    );
    final size = ByteData.sublistView(
      bytes,
      offset + 4,
      offset + _chunkHeaderLength,
    ).getUint32(0, Endian.little);
    final dataEnd = offset + _chunkHeaderLength + size;
    if (dataEnd > bytes.length) {
      throw const FormatException('Truncated WebP chunk data');
    }
    // Odd payload sizes carry a pad byte; a final chunk at EOF may omit it.
    final chunkEnd =
        size.isOdd && dataEnd < bytes.length ? dataEnd + 1 : dataEnd;

    if (_webpDroppedChunks.contains(id)) {
      if (id == 'EXIF') droppedExif = true;
      if (id == 'XMP ') droppedXmp = true;
      removedAny = true;
    } else {
      if (id == 'VP8X' && size >= 10 && vp8xFlagOffset < 0) {
        // The feature flags live in the first payload byte; record its
        // position inside the rebuilt output, not the input.
        vp8xFlagOffset = output.length + _chunkHeaderLength;
      }
      output.add(bytes.sublist(offset, chunkEnd));
    }
    offset = chunkEnd;
  }

  if (offset < bytes.length) {
    throw const FormatException('WebP chunk walk limit exceeded');
  }
  if (!removedAny) return bytes;

  final result = output.takeBytes();
  if (vp8xFlagOffset >= 0) {
    var flags = result[vp8xFlagOffset];
    if (droppedExif) flags &= ~_vp8xExifFlag;
    if (droppedXmp) flags &= ~_vp8xXmpFlag;
    result[vp8xFlagOffset] = flags;
  }
  ByteData.sublistView(result).setUint32(4, result.length - 8, Endian.little);
  return result;
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