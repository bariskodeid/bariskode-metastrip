import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/errors/app_exceptions.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';

void main() {
  test('stripJpegMetadata removes APP1 EXIF segment and writes clean copy',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_remover_test_');
    addTearDown(() => dir.delete(recursive: true));

    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF, 0xD8, // SOI
      0xFF, 0xE1, 0x00, 0x06, 1, 2, 3, 4, // APP1 stripped
      0xFF, 0xE0, 0x00, 0x04, 9, 9, // APP0 kept
      0xFF, 0xDA, 0x00, 0x02, 0xAA, 0xBB, 0xFF, 0xD9, // scan data
    ]);

    final output = await MetadataRemoverDatasource().stripJpegMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(output.path, contains('_clean'));
    expect(_containsSegment(bytes, 0xE1), isFalse);
    expect(_containsSegment(bytes, 0xE0), isTrue);
  });

  test('stripJpegMetadata stops at true EOI and preserves entropy escapes',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_eoi_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF, 0xD8,
      0xFF, 0xDA, 0, 6, 1, 1, 0, 0, 0, 0,
      0x11, 0xFF, 0x00, 0x22, // stuffed FF is entropy data
      0xFF, 0xD0, // restart marker is entropy data
      0x33,
      0xFF, 0xD9,
      ...'PRIVATE TRAILING PAYLOAD'.codeUnits,
    ]);

    final output = await MetadataRemoverDatasource().stripJpegMetadata(
      input.path,
      outputDirectory: dir.path,
    );

    expect(await output.readAsBytes(), [
      0xFF,
      0xD8,
      0xFF,
      0xDA,
      0,
      6,
      1,
      1,
      0,
      0,
      0,
      0,
      0x11,
      0xFF,
      0x00,
      0x22,
      0xFF,
      0xD0,
      0x33,
      0xFF,
      0xD9,
    ]);
  });

  test('stripJpegMetadata filters metadata between multiple scans', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_multi_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    final firstScan = [
      0x10,
      0xFF,
      0x00,
      0x20,
      0xFF,
      0xD1,
      0x30,
    ];
    final secondScan = [0x40, 0xFF, 0x00, 0x50];
    await input.writeAsBytes([
      0xFF,
      0xD8,
      0xFF,
      0xDA,
      0,
      2,
      ...firstScan,
      0xFF,
      0xE1,
      0,
      6,
      1,
      2,
      3,
      4,
      0xFF,
      0xFE,
      0,
      5,
      5,
      6,
      7,
      0xFF,
      0xDB,
      0,
      4,
      8,
      9,
      0xFF,
      0xDA,
      0,
      2,
      ...secondScan,
      0xFF,
      0xD9,
      ...'PRIVATE TRAILING PAYLOAD'.codeUnits,
    ]);

    final output = await MetadataRemoverDatasource().stripJpegMetadata(
      input.path,
      outputDirectory: dir.path,
    );

    expect(await output.readAsBytes(), [
      0xFF,
      0xD8,
      0xFF,
      0xDA,
      0,
      2,
      ...firstScan,
      0xFF,
      0xDB,
      0,
      4,
      8,
      9,
      0xFF,
      0xDA,
      0,
      2,
      ...secondScan,
      0xFF,
      0xD9,
    ]);
  });

  test('stripJpegMetadata handles repeated marker fill before SOS', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_fill_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF,
      0xD8,
      0xFF,
      0xFF,
      0xE1,
      0,
      4,
      1,
      2,
      0xFF,
      0xFF,
      0xE0,
      0,
      4,
      3,
      4,
      0xFF,
      0xFF,
      0xDA,
      0,
      2,
      0x55,
      0xFF,
      0xD9,
    ]);

    final output = await MetadataRemoverDatasource().stripJpegMetadata(
      input.path,
      outputDirectory: dir.path,
    );

    expect(await output.readAsBytes(), [
      0xFF,
      0xD8,
      0xFF,
      0xFF,
      0xE0,
      0,
      4,
      3,
      4,
      0xFF,
      0xFF,
      0xDA,
      0,
      2,
      0x55,
      0xFF,
      0xD9,
    ]);
  });

  test('stripJpegMetadata rejects a scan without EOI', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_bad_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF,
      0xD8,
      0xFF,
      0xDA,
      0,
      2,
      1,
      0x11,
      0xFF,
      0x00,
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripJpegMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripJpegMetadata rejects a truncated scan marker', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_trunc_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF,
      0xD8,
      0xFF,
      0xDA,
      0,
      2,
      0x11,
      0xFF,
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripJpegMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripJpegMetadata rejects APP-only data without SOS or EOI', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_app_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF,
      0xD8,
      0xFF,
      0xE1,
      0,
      6,
      1,
      2,
      3,
      4,
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripJpegMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripJpegMetadata rejects EOI before any scan', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_no_sos_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0,
      4,
      9,
      9,
      0xFF,
      0xD9,
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripJpegMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripJpegMetadata rejects a non-scan segment ending the file',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_jpeg_dqt_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([
      0xFF,
      0xD8,
      0xFF,
      0xDB,
      0,
      4,
      1,
      2,
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripJpegMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripMetadata writes clean copy to configured output folder', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_out_test_');
    addTearDown(() => dir.delete(recursive: true));
    final outDir =
        await Directory('${dir.path}${Platform.pathSeparator}out').create();
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes(
      [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 1, 2, 0xFF, 0xD9],
    );

    final output = await MetadataRemoverDatasource()
        .stripMetadata(input.path, outputDirectory: outDir.path);

    expect(output.path, startsWith(outDir.path));
    expect(await input.exists(), isTrue);
    expect(
      outDir.listSync().where((entry) => entry.path.endsWith('.tmp')),
      isEmpty,
    );
    expect(
      outDir.listSync().where((entry) => entry.path.endsWith('.claim')),
      isEmpty,
    );
  });

  test('claim cleanup failure does not fail an installed output', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_claim_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes(
      [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 1, 2, 0xFF, 0xD9],
    );

    final output = await MetadataRemoverDatasource(
      claimCleanup: (_) async => throw const FileSystemException('locked'),
    ).stripJpegMetadata(input.path, outputDirectory: dir.path);

    expect(await output.exists(), isTrue);
  });

  test('stripPngMetadata removes text chunks and keeps image chunks', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_png_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('tEXt', 'Author\u0000Alice'.codeUnits),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ]);

    final output = await MetadataRemoverDatasource().stripPngMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(String.fromCharCodes(bytes), isNot(contains('tEXt')));
    expect(String.fromCharCodes(bytes), contains('IHDR'));
    expect(String.fromCharCodes(bytes), contains('IDAT'));
    expect(String.fromCharCodes(bytes), contains('IEND'));
  });

  test('stripPngMetadata rejects a signature without IEND', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_png_empty_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);

    await expectLater(
      MetadataRemoverDatasource().stripPngMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripPngMetadata rejects IHDR and IDAT without IEND', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_png_no_iend_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('IDAT', [1, 2, 3]),
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripPngMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripPngMetadata rejects 1-11 trailing bytes before IEND', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_png_trunc_');
    addTearDown(() => dir.delete(recursive: true));
    final baseBytes = [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('IDAT', [1, 2, 3]),
    ];

    for (var trailingLength = 1; trailingLength <= 11; trailingLength++) {
      final input = File(
        '${dir.path}${Platform.pathSeparator}image_$trailingLength.png',
      );
      await input.writeAsBytes([
        ...baseBytes,
        ...List<int>.filled(trailingLength, 0),
      ]);

      await expectLater(
        MetadataRemoverDatasource().stripPngMetadata(
          input.path,
          outputDirectory: dir.path,
        ),
        throwsA(isA<FormatException>()),
        reason: 'trailing length $trailingLength must be rejected',
      );
    }
  });

  test('stripPngMetadata requires a zero-length IEND', () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_png_bad_iend_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', [1]),
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripPngMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripPngMetadata rejects an invalid IEND CRC', () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_png_iend_crc_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    final invalidIend = _pngChunk('IEND', const []);
    invalidIend[invalidIend.length - 1] ^= 0x01;
    await input.writeAsBytes([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ...invalidIend,
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripPngMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('stripPngMetadata truncates payload after a valid IEND', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_png_tail_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    final expected = [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ];
    await input.writeAsBytes([
      ...expected,
      ...'PRIVATE TRAILING PAYLOAD'.codeUnits,
    ]);

    final output = await MetadataRemoverDatasource().stripPngMetadata(
      input.path,
      outputDirectory: dir.path,
    );

    expect(await output.readAsBytes(), expected);
  });

  test('stripPdfMetadata clears common document info entries', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Title (Secret)/Author (Alice)>>endobj\n%%EOF',
    );

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final text = await output.readAsString();

    expect(text, contains('/Title (      )'));
    expect(text, contains('/Author (     )'));
    expect(text, isNot(contains('Secret')));
    expect(text, isNot(contains('Alice')));
  });

  test('stripJpegMetadata removes ICC color profile (APP2) marker', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_icc_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}icc.jpg');
    await input.writeAsBytes([
      0xFF, 0xD8, // SOI
      0xFF, 0xE2, 0x00, 0x06, 1, 2, 3, 4, // APP2 ICC profile stripped
      0xFF, 0xE0, 0x00, 0x04, 9, 9, // APP0 kept
      0xFF, 0xDA, 0x00, 0x02, 0xAA, 0xBB, 0xFF, 0xD9, // scan data
    ]);

    final output = await MetadataRemoverDatasource().stripJpegMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(_containsSegment(bytes, 0xE2), isFalse);
    expect(_containsSegment(bytes, 0xE0), isTrue);
  });

  test('stripPngMetadata removes tIME chunk (edit timestamp)', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_time_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137, 80, 78, 71, 13, 10, 26, 10, // PNG signature
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('tIME', [0x07, 0xE8, 1, 15, 12, 30, 0]),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ]);

    final output = await MetadataRemoverDatasource().stripPngMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(String.fromCharCodes(bytes), isNot(contains('tIME')));
    expect(String.fromCharCodes(bytes), contains('IHDR'));
    expect(String.fromCharCodes(bytes), contains('IEND'));
  });

  test('missing output folder fails without writing beside input', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_no_out_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes(
      [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 1, 2, 0xFF, 0xD9],
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(input.path),
      throwsA(isA<OutputFolderException>()),
    );
    expect(
      File('${dir.path}${Platform.pathSeparator}photo_clean.jpg').existsSync(),
      isFalse,
    );
  });

  test('invalid output folder fails without falling back to input folder',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_bad_out_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes(
      [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 1, 2, 0xFF, 0xD9],
    );
    final missing = '${dir.path}${Platform.pathSeparator}missing';

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: missing,
      ),
      throwsA(isA<OutputFolderException>()),
    );
    expect(
      File('${dir.path}${Platform.pathSeparator}photo_clean.jpg').existsSync(),
      isFalse,
    );
  });

  test('output folder path must be a directory', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_file_out_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    final outputFile = File('${dir.path}${Platform.pathSeparator}not-a-dir');
    await input.writeAsBytes(
      [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 1, 0xFF, 0xD9],
    );
    await outputFile.writeAsString('keep');

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: outputFile.path,
      ),
      throwsA(isA<OutputFolderException>()),
    );
    expect(await outputFile.readAsString(), 'keep');
  });

  test('concurrent writes use unique auto-incremented destinations', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_race_out_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes(
      [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 1, 0xFF, 0xD9],
    );
    await File('${dir.path}${Platform.pathSeparator}photo_clean.jpg')
        .writeAsString('existing');

    final outputs = await Future.wait(
      List.generate(
        8,
        (_) => MetadataRemoverDatasource().stripMetadata(
          input.path,
          outputDirectory: dir.path,
        ),
      ),
    );

    expect(outputs.map((file) => file.path).toSet(), hasLength(8));
    expect(
      await File('${dir.path}${Platform.pathSeparator}photo_clean.jpg')
          .readAsString(),
      'existing',
    );
    expect(
      dir.listSync().where((entry) => entry.path.contains('write-probe')),
      isEmpty,
    );
    expect(
      dir.listSync().where((entry) => entry.path.endsWith('.tmp')),
      isEmpty,
    );
    expect(
      dir.listSync().where((entry) => entry.path.endsWith('.claim')),
      isEmpty,
    );
  });
}

bool _containsSegment(List<int> bytes, int marker) {
  for (var i = 0; i < bytes.length - 1; i++) {
    if (bytes[i] == 0xFF && bytes[i + 1] == marker) return true;
  }
  return false;
}

List<int> _pngChunk(String type, List<int> data) {
  final length = ByteData(4)..setUint32(0, data.length);
  final contents = [...type.codeUnits, ...data];
  final crc = ByteData(4)..setUint32(0, _crc32(contents));
  return [
    ...length.buffer.asUint8List(),
    ...contents,
    ...crc.buffer.asUint8List(),
  ];
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xEDB88320;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
