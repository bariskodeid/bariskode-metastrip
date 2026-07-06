import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
      0xFF, 0xDA, 0xAA, 0xBB, 0xFF, 0xD9, // scan data
    ]);

    final output =
        await MetadataRemoverDatasource().stripJpegMetadata(input.path);
    final bytes = await output.readAsBytes();

    expect(output.path, contains('_clean'));
    expect(_containsSegment(bytes, 0xE1), isFalse);
    expect(_containsSegment(bytes, 0xE0), isTrue);
  });

  test('stripMetadata writes clean copy to configured output folder', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_out_test_');
    addTearDown(() => dir.delete(recursive: true));
    final outDir =
        await Directory('${dir.path}${Platform.pathSeparator}out').create();
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsBytes([0xFF, 0xD8, 0xFF, 0xDA, 1, 2, 0xFF, 0xD9]);

    final output = await MetadataRemoverDatasource()
        .stripMetadata(input.path, outputDirectory: outDir.path);

    expect(output.path, startsWith(outDir.path));
    expect(await input.exists(), isTrue);
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

    final output =
        await MetadataRemoverDatasource().stripPngMetadata(input.path);
    final bytes = await output.readAsBytes();

    expect(String.fromCharCodes(bytes), isNot(contains('tEXt')));
    expect(String.fromCharCodes(bytes), contains('IHDR'));
    expect(String.fromCharCodes(bytes), contains('IDAT'));
    expect(String.fromCharCodes(bytes), contains('IEND'));
  });

  test('stripPdfMetadata clears common document info entries', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Title (Secret)/Author (Alice)>>endobj\n%%EOF',
    );

    final output =
        await MetadataRemoverDatasource().stripPdfMetadata(input.path);
    final text = await output.readAsString();

    expect(text, contains('/Title (      )'));
    expect(text, contains('/Author (     )'));
    expect(text, isNot(contains('Secret')));
    expect(text, isNot(contains('Alice')));
  });

  test('stripJpegMetadata removes ICC color profile (APP2) marker', () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_icc_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}icc.jpg');
    await input.writeAsBytes([
      0xFF, 0xD8, // SOI
      0xFF, 0xE2, 0x00, 0x06, 1, 2, 3, 4, // APP2 ICC profile stripped
      0xFF, 0xE0, 0x00, 0x04, 9, 9, // APP0 kept
      0xFF, 0xDA, 0xAA, 0xBB, 0xFF, 0xD9, // scan data
    ]);

    final output =
        await MetadataRemoverDatasource().stripJpegMetadata(input.path);
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
      ..._pngChunk('tIME', [2024, 1, 15, 12, 30, 0]),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ]);

    final output =
        await MetadataRemoverDatasource().stripPngMetadata(input.path);
    final bytes = await output.readAsBytes();

    expect(String.fromCharCodes(bytes), isNot(contains('tIME')));
    expect(String.fromCharCodes(bytes), contains('IHDR'));
    expect(String.fromCharCodes(bytes), contains('IEND'));
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
  return [
    ...length.buffer.asUint8List(),
    ...type.codeUnits,
    ...data,
    0,
    0,
    0,
    0,
  ];
}
