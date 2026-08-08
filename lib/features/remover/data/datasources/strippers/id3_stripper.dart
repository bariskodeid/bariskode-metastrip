import 'dart:typed_data';

const List<int> _id3v2Signature = [0x49, 0x44, 0x33]; // 'ID3'
const List<int> _id3v1Signature = [0x54, 0x41, 0x47]; // 'TAG'
const List<int> _apev2Signature = [
  0x41,
  0x50,
  0x45,
  0x54,
  0x41,
  0x47,
  0x45,
  0x58,
]; // 'APETAGEX'

const int _id3v2HeaderLength = 10;
const int _id3v2FooterLength = 10;
const int _id3v1Length = 128;
const int _apev2ScanLength = 512;

/// Strips ID3v2 and ID3v1 metadata tags from audio bytes.
///
/// ID3v2 tags are removed from the front: the synchsafe-encoded tag size at
/// bytes 6..9 gives the payload length, so the whole tag is `10 + size`, plus
/// a 10-byte footer when flag byte 5 has the `0x10` footer bit set. ID3v1 tags
/// are removed from the tail: the final 128 bytes that start with 'TAG'.
/// APEv2 tags are handled with a simple heuristic: the last 512 bytes are
/// scanned for the `APETAGEX` signature and everything from the earliest
/// match is dropped. A tag whose item block is larger than the scan window
/// is cut at its footer instead of its header, leaving the header and items
/// behind; this is an MVP limitation of the simple scan, not a correctness
/// regression for the common `APEv2 + ID3v1` layout.
///
/// Bytes without any of these tags are returned unchanged (the same
/// instance). Throws [FormatException] when stripping leaves no audio data.
Uint8List stripId3(Uint8List bytes) {
  var stripped = bytes;
  if (_startsWith(stripped, _id3v2Signature)) {
    stripped = stripped.sublist(_id3v2TagEnd(stripped));
  }
  if (stripped.length >= _id3v1Length &&
      _startsWith(stripped, _id3v1Signature, start: stripped.length - 128)) {
    stripped = stripped.sublist(0, stripped.length - _id3v1Length);
  }
  final apev2Start = _findApev2Start(stripped);
  if (apev2Start != -1) {
    stripped = stripped.sublist(0, apev2Start);
  }
  if (stripped.isEmpty) {
    throw const FormatException('Output is empty');
  }
  return stripped;
}

/// Returns the index just past the ID3v2 tag beginning at the front of
/// [bytes], honoring the optional tag footer flag.
int _id3v2TagEnd(Uint8List bytes) {
  if (bytes.length < _id3v2HeaderLength) {
    throw const FormatException('Truncated ID3v2 header');
  }
  final size = _synchsafe(bytes, 6);
  var tagEnd = _id3v2HeaderLength + size;
  if ((bytes[5] & 0x10) != 0) {
    tagEnd += _id3v2FooterLength;
  }
  if (tagEnd > bytes.length) {
    throw const FormatException('Invalid ID3v2 tag size');
  }
  return tagEnd;
}

/// Returns the offset of the `APETAGEX` signature within the last 512 bytes
/// of [bytes], or -1 when absent.
int _findApev2Start(Uint8List bytes) {
  if (bytes.length < _apev2Signature.length) return -1;
  final scanStart =
      bytes.length > _apev2ScanLength ? bytes.length - _apev2ScanLength : 0;
  final lastMatchStart = bytes.length - _apev2Signature.length;
  for (var offset = scanStart; offset <= lastMatchStart; offset++) {
    if (_startsWith(bytes, _apev2Signature, start: offset)) {
      return offset;
    }
  }
  return -1;
}

bool _startsWith(Uint8List bytes, List<int> signature, {int start = 0}) {
  if (start + signature.length > bytes.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[start + i] != signature[i]) return false;
  }
  return true;
}

/// Decodes the 4-byte ID3v2 synchsafe integer (7 significant bits per byte).
///
/// Each byte is masked with `0x7F` so a corrupt header with high bits set in
/// the size bytes cannot inflate the tag size, mirroring the extractor.
int _synchsafe(Uint8List bytes, int offset) {
  return ((bytes[offset] & 0x7F) << 21) |
      ((bytes[offset + 1] & 0x7F) << 14) |
      ((bytes[offset + 2] & 0x7F) << 7) |
      (bytes[offset + 3] & 0x7F);
}
