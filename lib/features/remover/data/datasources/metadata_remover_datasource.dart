import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/isolate_runner.dart';
import 'package:path/path.dart' as p;

class MetadataRemoverDatasource {
  Future<File> stripMetadata(
    String inputPath, {
    String? outputDirectory,
  }) async {
    final ext = p.extension(inputPath).toLowerCase().replaceFirst('.', '');
    return switch (ext) {
      'jpg' || 'jpeg' => stripJpegMetadata(
          inputPath,
          outputDirectory: outputDirectory,
        ),
      'png' => stripPngMetadata(inputPath, outputDirectory: outputDirectory),
      'pdf' => stripPdfMetadata(inputPath, outputDirectory: outputDirectory),
      _ => throw FileSystemException('Unsupported remover format: $ext'),
    };
  }

  Future<File> stripJpegMetadata(
    String inputPath, {
    String? outputDirectory,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxJpegRemovalSizeBytes) {
      throw const FileSystemException('JPEG too large for remover MVP');
    }

    final bytes = await input.readAsBytes();
    final outputBytes = await runOnWorker(() => _stripJpegBytes(bytes));
    return _writeCleanCopy(inputPath, outputBytes, outputDirectory);
  }

  Future<File> stripPngMetadata(
    String inputPath, {
    String? outputDirectory,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxJpegRemovalSizeBytes) {
      throw const FileSystemException('PNG too large for remover MVP');
    }

    final bytes = await input.readAsBytes();
    final outputBytes = await runOnWorker(() => _stripPngBytes(bytes));
    return _writeCleanCopy(inputPath, outputBytes, outputDirectory);
  }

  Future<File> stripPdfMetadata(
    String inputPath, {
    String? outputDirectory,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxJpegRemovalSizeBytes) {
      throw const FileSystemException('PDF too large for remover MVP');
    }

    final bytes = await input.readAsBytes();
    final outputBytes = await runOnWorker(() => _stripPdfInfoBytes(bytes));
    return _writeCleanCopy(inputPath, outputBytes, outputDirectory);
  }

  Future<File> _writeCleanCopy(
    String inputPath,
    Uint8List bytes,
    String? outputDirectory,
  ) async {
    final outputPath = _cleanOutputPath(inputPath, outputDirectory);
    final tempFile = File(_tempOutputPath(outputPath));
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      if (File(outputPath).existsSync()) {
        throw const FileSystemException('Output file already exists');
      }
      return tempFile.rename(outputPath);
    } catch (_) {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  String _cleanOutputPath(String inputPath, String? outputDirectory) {
    var dir = p.dirname(inputPath);
    if (outputDirectory != null && Directory(outputDirectory).existsSync()) {
      dir = outputDirectory;
    }
    final basename = p.basenameWithoutExtension(inputPath);
    final ext = p.extension(inputPath);
    var candidate = p.join(dir, '${basename}_clean$ext');
    var index = 1;
    while (File(candidate).existsSync()) {
      if (index > 999) {
        throw const FileSystemException('Too many output filename collisions');
      }
      candidate = p.join(dir, '${basename}_clean_$index$ext');
      index++;
    }
    return candidate;
  }

  String _tempOutputPath(String outputPath) {
    final random = Random.secure().nextInt(1 << 32);
    return '$outputPath.${DateTime.now().microsecondsSinceEpoch}.$random.tmp';
  }
}

Uint8List _stripJpegBytes(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    throw const FormatException('Not a valid JPEG file');
  }

  final output = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
  var offset = 2;
  while (offset < bytes.length) {
    if (bytes[offset] != 0xFF || offset + 1 >= bytes.length) {
      throw const FormatException('Invalid JPEG marker stream');
    }
    final marker = bytes[offset + 1];
    offset += 2;
    if (marker == 0xDA) {
      output
        ..add([0xFF, marker])
        ..add(bytes.sublist(offset));
      break;
    }
    if (marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) {
      output.add([0xFF, marker]);
      continue;
    }
    if (offset + 2 > bytes.length) {
      throw const FormatException('Truncated JPEG segment length');
    }
    final length = ByteData.sublistView(bytes, offset, offset + 2).getUint16(0);
    if (length < 2 || offset + length > bytes.length) {
      throw const FormatException('Invalid JPEG segment length');
    }
    final segment = bytes.sublist(offset, offset + length);
    offset += length;
    // Skip metadata-bearing markers:
    // APP1 (E1): EXIF / XMP
    // APP2 (E2): ICC color profile (device fingerprint vector)
    // APP12 (EC): Picture Info
    // APP13 (ED): IPTC / Photoshop
    // APP14 (EE): Adobe markers
    // COM (FE): Comment
    final skipMarkers = {0xE1, 0xE2, 0xEC, 0xED, 0xEE, 0xFE};
    if (skipMarkers.contains(marker)) {
      continue;
    }
    output
      ..add([0xFF, marker])
      ..add(segment);
  }
  return output.toBytes();
}

Uint8List _stripPngBytes(Uint8List bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) {
    throw const FormatException('Not a valid PNG file');
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      throw const FormatException('Not a valid PNG file');
    }
  }
  final output = BytesBuilder(copy: false)..add(signature);
  var offset = 8;
  while (offset + 12 <= bytes.length) {
    final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    final chunkEnd = offset + 12 + length;
    if (length > bytes.length - offset - 12) {
      throw const FormatException('Invalid PNG chunk length');
    }
    // Drop text chunks, EXIF, and last-modified timestamp (tIME leaks
    // edit history; pHYs/pHYs carry physical pixel dimensions).
    if (!{'tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME'}.contains(type)) {
      output.add(bytes.sublist(offset, chunkEnd));
    }
    offset = chunkEnd;
    if (type == 'IEND') break;
  }
  return output.toBytes();
}

Uint8List _stripPdfInfoBytes(Uint8List bytes) {
  if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
    throw const FormatException('Not a valid PDF file');
  }
  var text = String.fromCharCodes(bytes);
  for (final key in [
    'Title',
    'Author',
    'Subject',
    'Keywords',
    'Creator',
    'Producer',
    'CreationDate',
    'ModDate',
  ]) {
    text = text.replaceAllMapped(
      RegExp('/$key(\\s*)\\(((?:\\\\.|[^\\)])*)\\)'),
      (match) => '/$key${match[1]}(${''.padRight(match[2]!.length)})',
    );
    text = text.replaceAllMapped(
      RegExp('/$key(\\s*)<([^>]*)>'),
      (match) => '/$key${match[1]}<${''.padRight(match[2]!.length)}>',
    );
  }
  return Uint8List.fromList(text.codeUnits);
}
