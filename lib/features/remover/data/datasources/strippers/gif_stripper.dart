import 'dart:typed_data';

/// Maximum number of GIF blocks walked before giving up.
///
/// Real GIFs hold at most a handful of image and extension blocks; a longer
/// walk indicates a corrupt size field, so the walk aborts instead of looping.
const int _maxGifBlocks = 10000;

/// ASCII magic marking an XMP application extension.
///
/// GIF stores XMP in an application extension (`0x21 0xFF`) whose first
/// sub-block starts with this text.
const String _xmpApplicationMagic = 'XMP DataXMP';

/// Strips metadata extensions from raw GIF [bytes].
///
/// Validates the `GIF87a`/`GIF89a` signature and copies the 6-byte header,
/// the 7-byte logical screen descriptor and the global color table (when
/// present) verbatim, then walks the remaining block stream:
///
/// - **Dropped**: comment extensions (`0x21 0xFE`) and XMP application
///   extensions (`0x21 0xFF` whose first sub-block starts with ASCII
///   `XMP DataXMP`).
/// - **Kept**: image descriptors (`0x2C` with their local color table and LZW
///   sub-block stream), graphic control (`0x21 0xF9`), plain text
///   (`0x21 0x01`), every other application extension and the trailer
///   (`0x3B`).
///
/// The output is rebuilt without the dropped blocks. Files without any
/// metadata extension are returned unchanged (the same instance). Throws
/// [FormatException] for a missing signature, a truncated descriptor, color
/// table, image or sub-block stream, an unknown block introducer, or a walk
/// longer than [_maxGifBlocks] (the guard against corrupt size fields).
Uint8List stripGif(Uint8List bytes) {
  if (!_isGif(bytes)) {
    throw const FormatException('Not a valid GIF file');
  }

  final output = BytesBuilder(copy: false);
  final descriptorEnd = _offsetAfterDescriptor(bytes);
  output.add(bytes.sublist(0, descriptorEnd));
  var offset = descriptorEnd;
  var removedAny = false;
  var endedAtTrailer = false;

  for (var block = 0; block < _maxGifBlocks; block++) {
    if (offset >= bytes.length) break;
    final introducer = bytes[offset];
    if (introducer == 0x3B) {
      output.addByte(0x3B);
      offset++;
      endedAtTrailer = true;
      break;
    }
    if (introducer == 0x21) {
      if (offset + 2 > bytes.length) {
        throw const FormatException('Truncated GIF extension header');
      }
      final label = bytes[offset + 1];
      final end = _skipSubBlocks(bytes, offset + 2);
      final isMetadata = label == 0xFE || _isXmpApplication(bytes, offset + 2);
      if (isMetadata) {
        removedAny = true;
      } else {
        output.add(bytes.sublist(offset, end));
      }
      offset = end;
    } else if (introducer == 0x2C) {
      final end = _imageEnd(bytes, offset);
      output.add(bytes.sublist(offset, end));
      offset = end;
    } else {
      throw FormatException(
        'Invalid GIF block introducer: 0x${introducer.toRadixString(16).padLeft(2, '0')}',
      );
    }
  }

  if (!endedAtTrailer && offset < bytes.length) {
    throw const FormatException('GIF block walk limit exceeded');
  }
  if (!removedAny) return bytes;
  return output.takeBytes();
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
/// global color table (when present) of [bytes]. Throws [FormatException] when
/// the descriptor or color table is truncated.
int _offsetAfterDescriptor(Uint8List bytes) {
  var offset = 13; // 6-byte header + 7-byte logical screen descriptor
  if (offset > bytes.length) {
    throw const FormatException('Truncated GIF descriptor');
  }
  final flags = bytes[10];
  if ((flags & 0x80) != 0) {
    offset += 3 * (1 << ((flags & 0x07) + 1));
  }
  if (offset > bytes.length) {
    throw const FormatException('Truncated GIF color table');
  }
  return offset;
}

/// Whether the application extension sub-block stream starting at [offset]
/// holds an XMP packet (first sub-block starts with [_xmpApplicationMagic]).
bool _isXmpApplication(Uint8List bytes, int offset) {
  if (offset >= bytes.length) return false;
  final length = bytes[offset];
  final magicLength = _xmpApplicationMagic.codeUnits.length;
  if (length < magicLength || offset + 1 + magicLength > bytes.length) {
    return false;
  }
  for (var i = 0; i < magicLength; i++) {
    if (bytes[offset + 1 + i] != _xmpApplicationMagic.codeUnits[i]) {
      return false;
    }
  }
  return true;
}

/// Returns the offset just past the image descriptor at [offset], its local
/// color table (when present), the LZW minimum code size byte and its
/// sub-block stream. Throws [FormatException] for truncation.
int _imageEnd(Uint8List bytes, int offset) {
  if (offset + 9 > bytes.length) {
    throw const FormatException('Truncated GIF image descriptor');
  }
  var cursor = offset + 9;
  final packed = bytes[offset + 8];
  if ((packed & 0x80) != 0) {
    cursor += 3 * (1 << ((packed & 0x07) + 1));
  }
  if (cursor >= bytes.length) {
    throw const FormatException('Truncated GIF image data');
  }
  cursor++; // LZW minimum code size byte
  return _skipSubBlocks(bytes, cursor);
}

/// Skips the sub-block stream starting at [offset] and returns the offset just
/// past its zero-length terminator. Throws [FormatException] for truncation.
int _skipSubBlocks(Uint8List bytes, int offset) {
  var cursor = offset;
  while (cursor < bytes.length && bytes[cursor] != 0) {
    final length = bytes[cursor];
    if (cursor + 1 + length > bytes.length) {
      throw const FormatException('Truncated GIF sub-block');
    }
    cursor += 1 + length;
  }
  if (cursor >= bytes.length) {
    throw const FormatException('Truncated GIF sub-block');
  }
  return cursor + 1; // past the zero-length terminator
}
