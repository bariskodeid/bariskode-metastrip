import 'dart:io';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/isolate_runner.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';

class MetadataRemoverDatasource {
  MetadataRemoverDatasource({
    Future<void> Function(File claim)? claimCleanup,
  }) : _claimCleanup = claimCleanup ?? _deleteClaim;

  final Future<void> Function(File claim) _claimCleanup;

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
    final directory = await validateOutputFolder(outputDirectory ?? '');
    if (Platform.isAndroid && directory.startsWith('content://')) {
      return _writeCleanCopyViaSaf(inputPath, bytes, directory);
    }

    final basename = p.basenameWithoutExtension(inputPath);
    final ext = p.extension(inputPath);

    for (var index = 0; index <= 999; index++) {
      final suffix = index == 0 ? '' : '_$index';
      final output = File(p.join(directory, '${basename}_clean$suffix$ext'));
      final claim = File('${output.path}.claim');
      final temporary = File(
        '${output.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      var claimed = false;
      try {
        if (await output.exists()) continue;
        await claim.create(exclusive: true);
        claimed = true;
        await temporary.create(exclusive: true);
        // The complete bytes are flushed to a uniquely named temporary file.
        // A crash can leave only auxiliary files, never a partial file under
        // the final clean filename.
        await temporary.writeAsBytes(bytes, flush: true);
        if (await output.exists()) {
          await _runBestEffort(() => temporary.delete());
          await _runBestEffort(() => claim.delete());
          continue;
        }
        // Dart has no cross-platform atomic, no-overwrite rename primitive.
        // The claim/check above protects normal concurrent jobs; an
        // external writer racing this final rename remains a platform limit.
        final installed = await temporary.rename(output.path);
        await _runBestEffort(() => _claimCleanup(claim));
        return installed;
      } on FileSystemException {
        if (claimed && await temporary.exists()) {
          await _runBestEffort(() => temporary.delete());
        }
        if (claimed && await claim.exists()) {
          await _runBestEffort(() => claim.delete());
        }
        if (await output.exists() || (!claimed && await claim.exists())) {
          continue;
        }
        rethrow;
      } catch (_) {
        if (await temporary.exists()) {
          await _runBestEffort(() => temporary.delete());
        }
        if (claimed && await claim.exists()) {
          await _runBestEffort(() => claim.delete());
        }
        rethrow;
      }
    }
    throw const FileSystemException('Too many output filename collisions');
  }

  /// Writes the clean copy into an Android Storage Access Framework grant.
  ///
  /// `writeFileBytes` never overwrites: on a name collision the provider
  /// auto-renames the new file. The returned [File] is only a path token
  /// whose path is the created document's `content://` URI; the repository
  /// resolves size through SAF for these paths.
  Future<File> _writeCleanCopyViaSaf(
    String inputPath,
    Uint8List bytes,
    String directoryUri,
  ) async {
    final name = '${p.basenameWithoutExtension(inputPath)}_clean'
        '${p.extension(inputPath)}';
    final mime = lookupMimeType(name) ?? 'application/octet-stream';
    try {
      final document = await Saf().writeFileBytes(
        directoryUri,
        name,
        mime,
        bytes,
      );
      return File(document.uri);
    } catch (_) {
      throw const FileSystemException('SAF output write failed');
    }
  }
}

Future<void> _deleteClaim(File claim) => claim.delete();

Future<void> _runBestEffort(Future<void> Function() cleanup) async {
  try {
    await cleanup();
  } catch (_) {
    // Auxiliary cleanup must not hide the operation's primary outcome.
  }
}

Uint8List _stripJpegBytes(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    throw const FormatException('Not a valid JPEG file');
  }

  final output = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
  var offset = 2;
  var inScan = false;
  var hasScan = false;
  while (true) {
    if (offset >= bytes.length) {
      throw const FormatException('JPEG is missing an EOI marker');
    }

    var markerStart = offset;
    if (inScan) {
      final entropyStart = offset;
      while (bytes[offset] != 0xFF) {
        offset++;
        if (offset >= bytes.length) {
          throw const FormatException('JPEG is missing an EOI marker');
        }
      }
      markerStart = offset;
      output.add(bytes.sublist(entropyStart, markerStart));
    } else if (bytes[offset] != 0xFF) {
      throw const FormatException('Invalid JPEG marker stream');
    }

    while (offset < bytes.length && bytes[offset] == 0xFF) {
      offset++;
    }
    if (offset >= bytes.length) {
      throw const FormatException('Truncated JPEG scan marker');
    }

    final marker = bytes[offset++];
    if (inScan && (marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7))) {
      output.add(bytes.sublist(markerStart, offset));
      continue;
    }
    if (marker == 0xD9) {
      if (!hasScan) {
        throw const FormatException('JPEG is missing an SOS marker');
      }
      output.add(bytes.sublist(markerStart, offset));
      return output.toBytes();
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      output.add(bytes.sublist(markerStart, offset));
      continue;
    }
    if (marker == 0x00 || marker == 0xD8) {
      throw const FormatException('Invalid JPEG marker stream');
    }
    if (offset + 2 > bytes.length) {
      throw const FormatException('Truncated JPEG segment length');
    }
    final length = ByteData.sublistView(
      bytes,
      offset,
      offset + 2,
    ).getUint16(0);
    if (length < 2 || offset + length > bytes.length) {
      throw const FormatException('Invalid JPEG segment length');
    }
    final segmentEnd = offset + length;
    const strippedMarkers = {0xE1, 0xE2, 0xEC, 0xED, 0xEE, 0xFE};
    if (!strippedMarkers.contains(marker)) {
      output.add(bytes.sublist(markerStart, segmentEnd));
    }
    offset = segmentEnd;

    if (marker == 0xDA) {
      hasScan = true;
      inScan = true;
    } else {
      // DNL may occur inside entropy-coded data and resumes the same scan.
      inScan = inScan && marker == 0xDC;
    }
  }
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
  while (true) {
    if (offset == bytes.length) {
      throw const FormatException('PNG is missing an IEND chunk');
    }
    if (bytes.length - offset < 12) {
      throw const FormatException('Truncated PNG chunk');
    }
    final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (length > bytes.length - offset - 12) {
      throw const FormatException('Invalid PNG chunk length');
    }
    final chunkEnd = offset + 12 + length;
    final storedCrc = ByteData.sublistView(
      bytes,
      chunkEnd - 4,
      chunkEnd,
    ).getUint32(0);
    final calculatedCrc = _pngCrc32(bytes, offset + 4, chunkEnd - 4);
    if (storedCrc != calculatedCrc) {
      throw const FormatException('Invalid PNG chunk CRC');
    }
    if (type == 'IEND' && length != 0) {
      throw const FormatException('Invalid PNG IEND chunk');
    }
    // Drop text chunks, EXIF, and last-modified timestamp (tIME leaks
    // edit history; pHYs/pHYs carry physical pixel dimensions).
    if (!{'tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME'}.contains(type)) {
      output.add(bytes.sublist(offset, chunkEnd));
    }
    offset = chunkEnd;
    if (type == 'IEND') return output.toBytes();
  }
}

int _pngCrc32(Uint8List bytes, int start, int end) {
  var crc = 0xFFFFFFFF;
  for (var index = start; index < end; index++) {
    crc ^= bytes[index];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xEDB88320;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
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
