import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';

void main() {
  test('stripPngMetadata selective removes only the matching author chunk',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_png_selective_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137, 80, 78, 71, 13, 10, 26, 10, // PNG signature
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('tEXt', 'Author\u0000Alice'.codeUnits),
      ..._pngChunk('tEXt', 'Title\u0000Secret Report'.codeUnits),
      ..._pngChunk('eXIf', [1, 2, 3]),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ]);

    final output = await MetadataRemoverDatasource().stripPngMetadata(
      input.path,
      outputDirectory: dir.path,
      selectiveLabels: {'Author'},
    );
    final text = String.fromCharCodes(await output.readAsBytes());

    expect(text, isNot(contains('Author')));
    expect(text, isNot(contains('Alice')));
    expect(text, contains('Title'));
    expect(text, contains('Secret Report'));
    expect(text, contains('tEXt'));
    expect(text, contains('eXIf'));
    expect(text, contains('IHDR'));
    expect(text, contains('IDAT'));
    expect(text, contains('IEND'));
  });

  test('stripPngMetadata keeps unselected text metadata in selective mode',
      () async {
    final dir = await Directory.systemTemp.createTemp('remap_png_keep_text_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137, 80, 78, 71, 13, 10, 26, 10, // PNG signature
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('zTXt',
          [0x43, 0x6F, 0x6D, 0x6D, 0x65, 0x6E, 0x74, 0x00]), // 'Comment\0'
      ..._pngChunk('tEXt', 'Author\u0000Alice'.codeUnits),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ]);

    final output = await MetadataRemoverDatasource().stripPngMetadata(
      input.path,
      outputDirectory: dir.path,
      selectiveLabels: {'Author'},
    );
    final text = String.fromCharCodes(await output.readAsBytes());

    expect(text, contains('Comment'));
    expect(text, contains('zTXt'));
  });

  test('stripMetadata rejects an empty selective field set', () async {
    final dir = await Directory.systemTemp.createTemp('remap_png_full_sel_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137, 80, 78, 71, 13, 10, 26, 10, // PNG signature
      ..._pngChunk('IHDR', List<int>.filled(13, 0)),
      ..._pngChunk('tEXt', 'Author\u0000Alice'.codeUnits),
      ..._pngChunk('tEXt', 'Title\u0000Secret Report'.codeUnits),
      ..._pngChunk('eXIf', [1, 2, 3]),
      ..._pngChunk('tIME', [0x07, 0xE8, 1, 15, 12, 30, 0]),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: dir.path,
        selectiveLabels: const <String>{},
      ),
      throwsFormatException,
    );
  });

  test('stripPngMetadata rejects a selective label not present in the file',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_png_missing_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}input.png');
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
      ..._pngChunk('tEXt', 'Title\u0000Example'.codeUnits),
      ..._pngChunk('IDAT', [1, 2, 3]),
      ..._pngChunk('IEND', const []),
    ]);

    expect(
      () => MetadataRemoverDatasource().stripPngMetadata(
        input.path,
        outputDirectory: dir.path,
        selectiveLabels: {'Author'},
      ),
      throwsFormatException,
    );
  });

  test('stripPdfMetadata selective labels blank only the selected Info key',
      () async {
    final dir = await Directory.systemTemp.createTemp('remap_pdf_selective_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Title (Secret Report)/Author (Jane Doe)>>'
      'endobj\n%%EOF',
    );

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
      selectiveLabels: {'Title'},
    );
    final text = await output.readAsString();

    expect(text, contains('/Title (             )'));
    expect(text, isNot(contains('Secret Report')));
    expect(text, contains('Author (Jane Doe)'));
  });

  test('stripMetadata rejects empty selective labels for PDF', () async {
    final dir = await Directory.systemTemp.createTemp('remap_pdf_full_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Title (Secret Report)/Author (Jane Doe)>>'
      'endobj\n%%EOF',
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: dir.path,
        selectiveLabels: const <String>{},
      ),
      throwsFormatException,
    );
  });

  test(
      'stripPdfMetadata survives an unterminated literal with many '
      'backslashes (ReDoS regression)', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_redos_');
    addTearDown(() => dir.delete(recursive: true));
    // `/Title (` followed by hundreds of backslashes and no closing paren.
    // The old nested-alternation regex backtracked exponentially here; the
    // linear scanner must finish in linear time.
    final backslashes = String.fromCharCodes(List.filled(250, 0x5C));
    final input = File('${dir.path}${Platform.pathSeparator}hostile.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Title ($backslashes>>endobj\n%%EOF',
    );

    final stopwatch = Stopwatch()..start();
    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    expect(await output.readAsString(), contains('/Title ('));
  });

  test('stripPdfMetadata selective Trapped blanks a name-token value',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_trapped_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Title (Secret Report)/Trapped /True>>endobj\n'
      '%%EOF',
    );

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
      selectiveLabels: {'Trapped'},
    );
    final text = await output.readAsString();

    expect(text, contains('/Trapped'));
    expect(text, isNot(contains('/True')));
    expect(text, contains('/Title (Secret Report)'));
    expect(text, contains('Secret Report'));
  });

  test('stripPdfMetadata selective Trapped blanks a bare boolean token',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_bare_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Author (Jane Doe)/Trapped true>>endobj\n%%EOF',
    );

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
      selectiveLabels: {'Trapped'},
    );
    final text = await output.readAsString();

    expect(text, contains('/Trapped'));
    expect(text, isNot(contains('true')));
    expect(text, contains('/Author (Jane Doe)'));
  });

  test('stripPdfMetadata honors escaped parens and hex string values',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_esc_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    // `\)` inside the literal is an escaped paren, not the terminator; the
    // hex value `<68656C6C6F>` must also be blanked between its delimiters.
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Title (A \\) B)/Subject <68656C6C6F>>>endobj\n'
      '%%EOF',
    );

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final text = await output.readAsString();

    expect(text, contains('/Title ('));
    expect(text, isNot(contains('A \\')));
    expect(text, isNot(contains('B)')));
    expect(text, contains('/Subject <'));
    expect(text, isNot(contains('68656C6C6F')));
  });

  test('stripMetadata rejects selective labels for unsupported docx', () async {
    final dir = await Directory.systemTemp.createTemp('remap_docx_selective_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}report.docx');
    await input.writeAsBytes(
      _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        'docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<w:document/>',
      }),
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: dir.path,
        selectiveLabels: {'Author'},
      ),
      throwsFormatException,
    );
  });

  test('stripMetadata rejects unsupported selective PDF labels', () async {
    final dir = await Directory.systemTemp.createTemp('pdf_unknown_field_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}report.pdf');
    await input.writeAsString('%PDF-1.4\n/Title (Keep)\n%%EOF');

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: dir.path,
        selectiveLabels: {'GPS'},
      ),
      throwsFormatException,
    );
  });

  test('remover_repository_impl passes selective labels through', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_repo_sel_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}photo.jpg');
    await input.writeAsString('payload');
    final outDir =
        await Directory('${dir.path}${Platform.pathSeparator}out').create();
    final datasource = _CapturingDatasource();

    final repository = RemoverRepositoryImpl(datasource);
    final result = await repository.stripFile(
      input.path,
      outputDirectory: outDir.path,
      selectiveLabels: {'Author', 'Title'},
    );

    expect(datasource.capturedSelectiveLabels, {'Author', 'Title'});
    expect(result.success, isTrue);
  });
}

class _CapturingDatasource extends MetadataRemoverDatasource {
  Set<String>? capturedSelectiveLabels;

  @override
  Future<File> stripMetadata(
    String inputPath, {
    String? outputDirectory,
    Set<String>? selectiveLabels,
  }) async {
    capturedSelectiveLabels = selectiveLabels;
    final output = File(
      '${outputDirectory!}${Platform.pathSeparator}copied.jpg',
    );
    await File(inputPath).copy(output.path);
    return output;
  }
}

Uint8List _officeZip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    archive.addFile(ArchiveFile.string(name, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

const _docxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '</Types>';

List<int> _pngChunk(String type, List<int> data) {
  final length = ByteData(4)..setUint32(0, data.length);
  final contents = <int>[...type.codeUnits, ...data];
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
