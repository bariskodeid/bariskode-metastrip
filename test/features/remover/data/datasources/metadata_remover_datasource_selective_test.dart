import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_value_parser.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';

void main() {
  test('WAV policy route validates local output and reports removals',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_wav_selective_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}audio.wav');
    await input.writeAsBytes(_wav([
      ('fmt ', List<int>.filled(16, 1)),
      (
        'LIST',
        [
          ...'INFO'.codeUnits,
          ..._riffChunk('IART', 'Alice'.codeUnits),
          ..._riffChunk('INAM', 'Keep title'.codeUnits),
        ]
      ),
      ('bext', 'keep broadcast'.codeUnits),
      ('data', List<int>.filled(8, 2)),
    ]));

    final removal = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: dir.path,
      policy: StripPolicy.selective(
        fieldIds: const {MetadataFieldId.wavInfoIart},
      ),
    );

    final text = String.fromCharCodes(await removal.file.readAsBytes());
    expect(text, isNot(contains('Alice')));
    expect(text, contains('Keep title'));
    expect(text, contains('keep broadcast'));
    expect(removal.report.removedFieldIds, {MetadataFieldId.wavInfoIart});
    expect(removal.report.outputValidated, isTrue);
    expect(
        removal.report.verificationOutcome, StripVerificationOutcome.verified);
  });

  test('WAV local persisted readback failure fails the operation', () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_wav_readback_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}audio.wav');
    await input.writeAsBytes(_wav([
      (
        'LIST',
        [...'INFO'.codeUnits, ..._riffChunk('INAM', 'Secret'.codeUnits)]
      ),
    ]));
    final datasource = MetadataRemoverDatasource(
      persistedOutputReader: (_) async => Uint8List.fromList('bad'.codeUnits),
    );

    await expectLater(
      datasource.stripMetadataWithPolicy(
        input.path,
        outputDirectory: dir.path,
        policy: StripPolicy.selective(
          fieldIds: const {MetadataFieldId.wavInfoInam},
        ),
      ),
      throwsFormatException,
    );
  });

  test('legacy WAV selectiveLabels route uses verified selective behavior',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_wav_legacy_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}audio.wav');
    await input.writeAsBytes(_wav([
      (
        'LIST',
        [...'INFO'.codeUnits, ..._riffChunk('INAM', 'Secret'.codeUnits)]
      ),
    ]));
    final datasource = MetadataRemoverDatasource(
      persistedOutputReader: (_) async => Uint8List.fromList('bad'.codeUnits),
    );

    await expectLater(
      datasource.stripMetadata(
        input.path,
        outputDirectory: dir.path,
        selectiveLabels: {MetadataFieldId.wavInfoInam.value},
      ),
      throwsFormatException,
    );
  });

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

  test('stripPdfMetadata fully blanks balanced nested literal values',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_nested_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    const value = r'Outer (Inner \(literal\) (Deep\\Path)) End';
    await input.writeAsString('%PDF-1.4\n/Title ($value)\n%%EOF');

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
    );

    expect(
      await output.readAsString(),
      '%PDF-1.4\n/Title (${List.filled(value.length, ' ').join()})\n%%EOF',
    );
  });

  test('stripPdfMetadata handles deeply nested literal values', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_deep_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    const depth = 10000;
    final value =
        '${List.filled(depth, '(').join()}Secret${List.filled(depth, ')').join()}';
    await input.writeAsString('%PDF-1.4\n/Author ($value)\n%%EOF');

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
    );

    expect(
      await output.readAsString(),
      '%PDF-1.4\n/Author (${List.filled(value.length, ' ').join()})\n%%EOF',
    );
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
      'stripPdfMetadata fails closed on an unterminated literal with many '
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
    await expectLater(
      MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsFormatException,
    );
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    expect(
      dir.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });

  test('stripPdfMetadata bounds repeated malformed literal markers', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_lit_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}hostile.pdf');
    await input.writeAsString(
      '%PDF-1.4\n${List.filled(25000, '/Title (').join()}',
    );

    final stopwatch = Stopwatch()..start();
    await expectLater(
      MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsFormatException,
    );
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });

  test('stripPdfMetadata bounds repeated malformed hex markers', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_hex_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}hostile.pdf');
    await input.writeAsString(
      '%PDF-1.4\n${List.filled(25000, '/Subject <').join()}',
    );

    final stopwatch = Stopwatch()..start();
    await expectLater(
      MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsFormatException,
    );
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });

  test('stripPdfMetadata rejects dense valid markers above the shared cap',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_dense_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}dense.pdf');
    await input.writeAsString(
      '%PDF-1.4\n'
      '${List.filled(maxPdfInfoValueOccurrences + 1, '/Title (x)').join()}'
      '\n%%EOF',
    );

    await expectLater(
      MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsFormatException,
    );
    expect(
      dir.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });

  test('stripPdfMetadata counts longer-name candidates against the cap',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_names_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}dense.pdf');
    await input.writeAsString(
      '%PDF-1.4\n'
      '${List.filled(maxPdfInfoValueOccurrences + 1, '/TitleFoo (x)').join()}'
      '\n%%EOF',
    );

    await expectLater(
      MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsFormatException,
    );
    expect(
      dir.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });

  test('stripPdfMetadata preserves longer names and blanks name tokens',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_pdf_bounds_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n/Title+Private (keep)/Title#46oo (also keep)'
      '/Title (remove)/Trapped /True\n%%EOF',
    );

    final output = await MetadataRemoverDatasource().stripPdfMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final text = await output.readAsString();

    expect(text, contains('/Title+Private (keep)'));
    expect(text, contains('/Title#46oo (also keep)'));
    expect(text, contains('/Title (      )'));
    expect(text, contains('/Trapped /X   '));
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

  test('stripMetadata rejects display labels for selective docx', () async {
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

  test('Office policy route writes output and reports removed and absent IDs',
      () async {
    final dir = await Directory.systemTemp.createTemp('office_policy_report_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}report.docx');
    await input.writeAsBytes(
      _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        'docProps/core.xml': _officeCoreXml,
        'word/document.xml': '<w:document/>',
      }),
    );

    final output = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: dir.path,
      policy: StripPolicy.selective(
        fieldIds: const {
          MetadataFieldId.openXmlAuthor,
          MetadataFieldId.openXmlCompany,
        },
      ),
    );

    expect(output.file.path, isNot(input.path));
    expect(output.report.requestedFieldIds, {
      MetadataFieldId.openXmlAuthor,
      MetadataFieldId.openXmlCompany,
    });
    expect(output.report.removedFieldIds, {MetadataFieldId.openXmlAuthor});
    expect(
      output.report.alreadyAbsentFieldIds,
      {MetadataFieldId.openXmlCompany},
    );
    expect(
        output.report.verificationOutcome, StripVerificationOutcome.verified);
    expect(output.report.outputValidated, isTrue);
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
      policy: StripPolicy.selective(
        fieldIds: {
          MetadataFieldId.pngText('Author'),
          MetadataFieldId.pngText('Title'),
        },
      ),
    );

    expect(datasource.capturedPolicy?.selectedFieldIds, {
      MetadataFieldId.pngText('Author'),
      MetadataFieldId.pngText('Title'),
    });
    expect(result.success, isTrue);
  });
}

Uint8List _wav(List<(String, List<int>)> chunks) {
  final body = <int>[...'WAVE'.codeUnits];
  for (final chunk in chunks) {
    body.addAll(_riffChunk(chunk.$1, chunk.$2));
  }
  return Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._le32(body.length),
    ...body,
  ]);
}

List<int> _riffChunk(String id, List<int> data) => [
      ...id.padRight(4).codeUnits,
      ..._le32(data.length),
      ...data,
      if (data.length.isOdd) 0,
    ];

List<int> _le32(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

class _CapturingDatasource extends MetadataRemoverDatasource {
  StripPolicy? capturedPolicy;

  @override
  Future<MetadataRemovalOutput> stripMetadataWithPolicy(
    String inputPath, {
    required String outputDirectory,
    required StripPolicy policy,
  }) async {
    capturedPolicy = policy;
    final output = File(
      '$outputDirectory${Platform.pathSeparator}copied.jpg',
    );
    await File(inputPath).copy(output.path);
    return MetadataRemovalOutput(
      file: output,
      report: StripReport(),
    );
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

const _officeCoreXml = '<cp:coreProperties '
    'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    '<dc:creator>Jane</dc:creator><dc:title>Keep me</dc:title>'
    '</cp:coreProperties>';

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
