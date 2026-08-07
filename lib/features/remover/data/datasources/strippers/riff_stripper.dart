import 'dart:typed_data';

/// Length of a RIFF/FORM container header: magic (4) + size (4) + format (4).
const int _containerHeaderLength = 12;

/// Length of a RIFF chunk header: id (4) + size (4).
const int _chunkHeaderLength = 8;

/// Length of a four-character-code chunk id.
const int _chunkIdLength = 4;

/// Maximum number of chunks walked within one container before giving up.
///
/// Real WAV/AIFF files hold at most a handful of chunks; a longer walk
/// indicates a corrupt size field, so the walk aborts instead of looping.
const int _maxChunks = 512;

/// WAV chunks carrying metadata; dropped by [stripRiff].
const Set<String> _wavDroppedChunks = {'LIST', 'ID3 ', 'bext'};

/// AIFF chunks carrying metadata; dropped by [stripRiff].
const Set<String> _aiffDroppedChunks = {'NAME', 'AUTH', '(c) ', 'ANNO', 'ID3 '};

/// Strips metadata chunks from RIFF audio containers ([bytes]).
///
/// Supports WAV (`RIFF`/`WAVE`) and AIFF (`FORM`/`AIFF`) containers selected
/// by [extension] (`wav` for WAV; `aiff`, `aif` and `aifc` for AIFF).
///
/// **WAV path**: after validating the `RIFF` magic and the `WAVE` format,
/// chunks are walked from offset 12. Each chunk is a 4-byte ASCII id, a
/// 4-byte little-endian payload size and the payload itself, followed by a
/// pad byte when the payload size is odd. The `LIST` chunk (the INFO metadata
/// container), the `ID3 ` chunk and the `bext` broadcast-extension chunk are
/// dropped; every other chunk (`fmt `, `data`, `fact`, `cue `, `smpl`, ...)
/// is copied verbatim, including its original pad byte. `LIST` is dropped
/// wholesale: it almost always holds INFO metadata, but a rare `LIST` can
/// carry audio-related subchunks that would be removed along with it.
///
/// **AIFF path**: the same walk with big-endian sizes. `NAME`, `AUTH`,
/// `(c) `, `ANNO` and `ID3 ` chunks are dropped; `COMM`, `SSND`, `MARK`,
/// `INST`, ... are kept verbatim.
///
/// The output is rebuilt as the container magic, a new 4-byte container size
/// (`output length - 8`, same endianness as the input), the format id and the
/// retained chunks. A missing pad byte after a final odd-sized chunk is
/// tolerated — the walk simply ends at the payload; leftover trailing bytes
/// that cannot form a chunk header are rejected. Files without any droppable
/// chunk are returned unchanged (the same instance). Throws [FormatException]
/// for a missing magic or format, a truncated chunk header or payload, a
/// chunk walk longer than [_maxChunks] (the guard against corrupt size
/// fields), or an unsupported [extension].
Uint8List stripRiff(Uint8List bytes, {required String extension}) {
  switch (extension.toLowerCase()) {
    case 'wav':
      return _stripWav(bytes);
    case 'aiff':
    case 'aif':
    case 'aifc':
      return _stripAiff(bytes);
    default:
      throw FormatException('Unsupported extension: $extension');
  }
}

/// Removes WAV metadata chunks (`LIST`, `ID3 `, `bext`).
Uint8List _stripWav(Uint8List bytes) {
  if (!_asciiAt(bytes, 0, 'RIFF') || !_asciiAt(bytes, 8, 'WAVE')) {
    throw const FormatException('Not a valid WAV file');
  }
  return _stripChunks(
    bytes,
    endian: Endian.little,
    dropped: _wavDroppedChunks,
    name: 'WAV',
  );
}

/// Removes AIFF metadata chunks (`NAME`, `AUTH`, `(c) `, `ANNO`, `ID3 `).
Uint8List _stripAiff(Uint8List bytes) {
  if (!_asciiAt(bytes, 0, 'FORM') || !_asciiAt(bytes, 8, 'AIFF')) {
    throw const FormatException('Not a valid AIFF file');
  }
  return _stripChunks(
    bytes,
    endian: Endian.big,
    dropped: _aiffDroppedChunks,
    name: 'AIFF',
  );
}

/// Rebuilds [bytes] keeping every chunk not in [dropped] and rewriting the
/// container size field. [endian] selects the chunk-size byte order and
/// [name] appears in truncation error messages.
Uint8List _stripChunks(
  Uint8List bytes, {
  required Endian endian,
  required Set<String> dropped,
  required String name,
}) {
  final output = BytesBuilder(copy: false);
  output.add(bytes.sublist(0, _containerHeaderLength));
  var offset = _containerHeaderLength;
  var removedAny = false;

  for (var i = 0; i < _maxChunks; i++) {
    if (offset >= bytes.length) break;
    if (offset + _chunkHeaderLength > bytes.length) {
      throw FormatException('Truncated $name chunk header');
    }
    final id = _chunkId(bytes, offset);
    final size = ByteData.sublistView(
      bytes,
      offset + _chunkIdLength,
      offset + _chunkHeaderLength,
    ).getUint32(0, endian);
    final dataEnd = offset + _chunkHeaderLength + size;
    if (dataEnd > bytes.length) {
      throw FormatException('Truncated $name chunk data');
    }
    // Odd payload sizes carry a pad byte; a final chunk at EOF may omit it.
    final chunkEnd =
        size.isOdd && dataEnd < bytes.length ? dataEnd + 1 : dataEnd;

    if (dropped.contains(id)) {
      removedAny = true;
    } else {
      output.add(bytes.sublist(offset, chunkEnd));
    }
    offset = chunkEnd;
  }

  if (offset < bytes.length) {
    throw const FormatException('RIFF chunk walk limit exceeded');
  }
  if (!removedAny) return bytes;

  final result = output.takeBytes();
  ByteData.sublistView(result).setUint32(4, result.length - 8, endian);
  return result;
}

/// Whether [bytes] holds the ASCII [text] at [offset].
bool _asciiAt(Uint8List bytes, int offset, String text) {
  final codes = text.codeUnits;
  if (offset + codes.length > bytes.length) return false;
  for (var i = 0; i < codes.length; i++) {
    if (bytes[offset + i] != codes[i]) return false;
  }
  return true;
}

/// Reads the four-byte chunk identifier at [offset] as ASCII.
String _chunkId(Uint8List bytes, int offset) {
  return String.fromCharCodes(bytes.sublist(offset, offset + _chunkIdLength));
}
