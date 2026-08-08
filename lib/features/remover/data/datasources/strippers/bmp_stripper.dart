import 'dart:typed_data';

const _fileHeaderSize = 14;
const _dibHeaderSize = 40;
const _pixelOffset = _fileHeaderSize + _dibHeaderSize;
const _maxDimension = 100000;

/// Canonicalizes a supported BMP while preserving its pixel payload.
///
/// This intentionally accepts only `BM` files with a 40-byte
/// BITMAPINFOHEADER, a byte-54 pixel offset, bottom-up positive dimensions,
/// BI_RGB compression, and 24-bit or 32-bit pixels.
Uint8List stripBmp(Uint8List bytes) {
  final parsed = _parseBmp(bytes);
  final output = Uint8List(parsed.outputLength)
    ..setRange(0, _pixelOffset, bytes)
    ..setRange(_pixelOffset, parsed.outputLength, bytes, _pixelOffset);
  final header = ByteData.sublistView(output);
  header
    ..setUint32(2, output.length, Endian.little)
    ..setUint16(6, 0, Endian.little)
    ..setUint16(8, 0, Endian.little)
    ..setUint32(34, parsed.pixelSpan, Endian.little);
  return output;
}

/// Requires [output] to be the exact canonical representation of [input].
void validateBmpOutput(Uint8List input, Uint8List output) {
  final source = _parseBmp(input);
  final persisted = _parseBmp(output);
  if (output.length != source.outputLength ||
      persisted.pixelSpan != source.pixelSpan) {
    throw const FormatException('BMP output has an invalid length');
  }
  final header = ByteData.sublistView(output);
  if (header.getUint32(2, Endian.little) != output.length ||
      header.getUint16(6, Endian.little) != 0 ||
      header.getUint16(8, Endian.little) != 0 ||
      header.getUint32(34, Endian.little) != source.pixelSpan) {
    throw const FormatException('BMP output header is not canonical');
  }

  const mutableHeaderBytes = <int>{
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    34,
    35,
    36,
    37,
  };
  for (var index = 0; index < _pixelOffset; index++) {
    if (!mutableHeaderBytes.contains(index) && output[index] != input[index]) {
      throw const FormatException('BMP output header changed unexpectedly');
    }
  }
  for (var index = 0; index < source.pixelSpan; index++) {
    if (output[_pixelOffset + index] != input[_pixelOffset + index]) {
      throw const FormatException('BMP output does not match canonical data');
    }
  }
}

_ParsedBmp _parseBmp(Uint8List bytes) {
  if (bytes.length < _pixelOffset || bytes[0] != 0x42 || bytes[1] != 0x4D) {
    throw const FormatException('Invalid BMP file header');
  }
  final header = ByteData.sublistView(bytes);
  if (header.getUint32(14, Endian.little) != _dibHeaderSize) {
    throw const FormatException('Unsupported BMP DIB header');
  }
  if (header.getUint32(10, Endian.little) != _pixelOffset) {
    throw const FormatException('Unsupported BMP pixel offset');
  }

  final width = header.getInt32(18, Endian.little);
  final height = header.getInt32(22, Endian.little);
  final planes = header.getUint16(26, Endian.little);
  final bitCount = header.getUint16(28, Endian.little);
  final compression = header.getUint32(30, Endian.little);
  final declaredFileSize = header.getUint32(2, Endian.little);
  final declaredImageSize = header.getUint32(34, Endian.little);
  if (width <= 0 ||
      width > _maxDimension ||
      height <= 0 ||
      height > _maxDimension ||
      planes != 1 ||
      compression != 0 ||
      (bitCount != 24 && bitCount != 32)) {
    throw const FormatException('Unsupported BMP format');
  }

  // Dimensions are bounded before multiplication. Dart integers do not
  // overflow, and the available-byte comparison prevents oversized output.
  final rowStride = ((width * bitCount + 31) ~/ 32) * 4;
  final pixelSpan = rowStride * height;
  if (pixelSpan > bytes.length - _pixelOffset) {
    throw const FormatException('Truncated BMP pixel payload');
  }
  final outputLength = _pixelOffset + pixelSpan;
  if (declaredFileSize != 0 && declaredFileSize != bytes.length) {
    throw const FormatException('Invalid BMP file size');
  }
  if (declaredImageSize != 0 && declaredImageSize != pixelSpan) {
    throw const FormatException('Invalid BMP image size');
  }
  return _ParsedBmp(
    pixelSpan: pixelSpan,
    outputLength: outputLength,
  );
}

class _ParsedBmp {
  const _ParsedBmp({required this.pixelSpan, required this.outputLength});

  final int pixelSpan;
  final int outputLength;
}
