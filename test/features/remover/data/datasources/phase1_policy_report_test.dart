import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/png_text_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/vorbis_extractor.dart';

void main() {
  test('FLAC selective policy reports stable IDs and verifies local output',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase1_flac_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}audio.flac');
    await input.writeAsBytes(_flacSelectiveFixture());

    final title = MetadataFieldId.vorbisComment('title');
    final result = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: directory.path,
      policy: StripPolicy.selective(fieldIds: {title}),
    );

    expect(result.report.requestedFieldIds, {title});
    expect(result.report.removedFieldIds, {title});
    expect(result.report.alreadyAbsentFieldIds, isEmpty);
    expect(
        result.report.verificationOutcome, StripVerificationOutcome.verified);
    expect(result.report.outputValidated, isTrue);
    final fields =
        await extractVorbis(await result.file.readAsBytes(), extension: 'flac');
    expect(fields.map((field) => field.label), ['Artist']);
  });

  test('FLAC malformed selective input fails before creating output', () async {
    final directory = await Directory.systemTemp.createTemp('phase1_flac_bad_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}audio.flac');
    await input.writeAsBytes([0x66, 0x4C, 0x61, 0x43, 0x80, 0, 0, 20]);

    await expectLater(
      MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: {MetadataFieldId.vorbisComment('TITLE')},
        ),
      ),
      throwsFormatException,
    );
    expect(
        directory.listSync().where((entity) => entity.path.contains('_clean')),
        isEmpty);
  });

  test('FLAC selective validation rejects non-identical persisted bytes',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('phase1_flac_persisted_bad_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}audio.flac');
    await input.writeAsBytes(_flacSelectiveFixture());
    final datasource = MetadataRemoverDatasource(
      persistedOutputReader: (output) async {
        final persisted = await output.readAsBytes();
        final marker = 'ARTIST'.codeUnits;
        final start = _indexOfBytes(persisted, marker);
        expect(start, isNonNegative);
        persisted.setRange(start, start + marker.length, 'artist'.codeUnits);
        return persisted;
      },
    );

    await expectLater(
      datasource.stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: {MetadataFieldId.vorbisComment('TITLE')},
        ),
      ),
      throwsFormatException,
    );
  });

  test('legacy FLAC selective labels use canonical validation and verification',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('phase1_flac_legacy_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}audio.flac');
    await input.writeAsBytes(_flacSelectiveFixture());

    final output = await MetadataRemoverDatasource().stripMetadata(
      input.path,
      outputDirectory: directory.path,
      selectiveLabels: {' title '},
    );
    final fields = await extractVorbis(
      await output.readAsBytes(),
      extension: 'flac',
    );
    expect(fields.map((field) => field.label), ['Artist']);

    expect(
      () => MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: directory.path,
        selectiveLabels: {'BAD=KEY'},
      ),
      throwsFormatException,
    );
  });

  test('PNG policy reports actual matched IDs and output re-extracts clean',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase1_png_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('tEXt', 'Author\u0000Ada'.codeUnits),
      ..._pngChunk('tEXt', 'Title\u0000Notes'.codeUnits),
      ..._pngChunk('IEND', const []),
    ]);
    final authorId = MetadataFieldId.pngText('Author');

    final result = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: directory.path,
      policy: StripPolicy.selective(fieldIds: {authorId}),
    );

    expect(result.report.requestedFieldIds, {authorId});
    expect(result.report.removedFieldIds, {authorId});
    expect(
      result.report.verificationOutcome,
      StripVerificationOutcome.verified,
    );
    expect(result.report.outputValidated, isTrue);
    final outputFields = await extractPngText(await result.file.readAsBytes());
    expect(outputFields.map((field) => field.label), ['Title']);
    expect(await input.readAsBytes(), containsAllInOrder('Author'.codeUnits));
  });

  test('PNG persisted readback corruption fails and leaves unverified output',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase1_png_bad_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('tEXt', 'Author\u0000Ada'.codeUnits),
      ..._pngChunk('IEND', const []),
    ]);
    final datasource = MetadataRemoverDatasource(
      persistedOutputReader: (_) async => Uint8List.fromList([137, 80]),
    );

    await expectLater(
      datasource.stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: {MetadataFieldId.pngText('Author')},
        ),
      ),
      throwsFormatException,
    );

    expect(
      directory.listSync().where((entity) => entity.path.contains('_clean')),
      hasLength(1),
    );
  });

  test('PNG absent selective ID fails before creating output', () async {
    final directory = await Directory.systemTemp.createTemp('phase1_absent_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}image.png');
    await input.writeAsBytes([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('IEND', const []),
    ]);

    await expectLater(
      MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: {MetadataFieldId.pngText('Missing')},
        ),
      ),
      throwsFormatException,
    );
    expect(
      directory.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });

  test('oversized selective PNG is rejected without creating output', () async {
    final directory = await Directory.systemTemp.createTemp('phase1_png_big_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}large.png');
    final handle = await input.open(mode: FileMode.write);
    try {
      await handle.writeFrom([137, 80, 78, 71, 13, 10, 26, 10]);
      await handle.setPosition(AppConstants.maxRemoverFileSizeBytes);
      await handle.writeByte(0);
    } finally {
      await handle.close();
    }
    expect(
      await input.length(),
      greaterThan(AppConstants.maxRemoverFileSizeBytes),
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: {MetadataFieldId.pngText('Author')},
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      directory.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });

  test('PDF repository keeps local field claims unverified', () async {
    final directory = await Directory.systemTemp.createTemp('phase1_pdf_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString('%PDF-1.4\n/Author (Ada)\n%%EOF');
    final repository = RemoverRepositoryImpl();

    final result = await repository.stripFile(
      input.path,
      outputDirectory: directory.path,
      policy: StripPolicy.selective(
        fieldIds: const {
          MetadataFieldId.pdfInfoAuthor,
          MetadataFieldId.pdfInfoTitle,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.report?.requestedFieldIds, {
      MetadataFieldId.pdfInfoAuthor,
      MetadataFieldId.pdfInfoTitle,
    });
    expect(result.report?.removedFieldIds, isEmpty);
    expect(result.report?.alreadyAbsentFieldIds, isEmpty);
    expect(result.report?.outputValidated, isFalse);
    expect(
      result.report?.verificationOutcome,
      StripVerificationOutcome.attemptedUnverified,
    );
    expect(result.report?.warnings.single, contains('persisted artifact'));
    expect(await input.readAsString(), contains('Ada'));
    expect(
        await File(result.outputPath!).readAsString(), isNot(contains('Ada')));
  });

  test('full PDF policy does not claim removed or absent Info fields',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase1_pdf_full_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString('%PDF-1.4\n/Author (Ada)\n%%EOF');

    final result = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: directory.path,
      policy: const StripPolicy.supportedCleanup(),
    );

    expect(result.report.outputValidated, isFalse);
    expect(
      result.report.verificationOutcome,
      StripVerificationOutcome.attemptedUnverified,
    );
    expect(result.report.removedFieldIds, isEmpty);
    expect(result.report.alreadyAbsentFieldIds, isEmpty);
  });

  test('PDF stream-like key cannot produce field-level claims', () async {
    final directory = await Directory.systemTemp.createTemp('phase1_pdf_ctx_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString(
      '%PDF-1.4\n1 0 obj<</Length 13>>stream\n/Author (Ada)\n'
      'endstream\nendobj\n%%EOF',
    );

    final result = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: directory.path,
      policy: StripPolicy.selective(
        fieldIds: const {MetadataFieldId.pdfInfoAuthor},
      ),
    );

    expect(result.report.outputValidated, isFalse);
    expect(
      result.report.verificationOutcome,
      StripVerificationOutcome.attemptedUnverified,
    );
    expect(result.report.removedFieldIds, isEmpty);
    expect(result.report.alreadyAbsentFieldIds, isEmpty);
  });

  test('all policy PDF entry points fail closed on malformed Info values',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase1_pdf_bad_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString('%PDF-1.4\n/Author (unterminated');
    final datasource = MetadataRemoverDatasource();

    await expectLater(
      datasource.stripPdfMetadata(
        input.path,
        outputDirectory: directory.path,
      ),
      throwsFormatException,
    );
    await expectLater(
      datasource.stripMetadata(
        input.path,
        outputDirectory: directory.path,
      ),
      throwsFormatException,
    );
    await expectLater(
      datasource.stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: const StripPolicy.supportedCleanup(),
      ),
      throwsFormatException,
    );
    await expectLater(
      datasource.stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: const {MetadataFieldId.pdfInfoAuthor},
        ),
      ),
      throwsFormatException,
    );

    expect(
      directory.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });

  test('oversized selective PDF is rejected without creating output', () async {
    final directory = await Directory.systemTemp.createTemp('phase1_pdf_big_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}large.pdf');
    final handle = await input.open(mode: FileMode.write);
    try {
      await handle.writeString('%PDF-1.4\n');
      await handle.setPosition(AppConstants.maxRemoverFileSizeBytes);
      await handle.writeByte(0);
    } finally {
      await handle.close();
    }
    expect(
      await input.length(),
      greaterThan(AppConstants.maxRemoverFileSizeBytes),
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: const {MetadataFieldId.pdfInfoAuthor},
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      directory.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });

  test('cross-format IDs are rejected before output', () async {
    final directory = await Directory.systemTemp.createTemp('phase1_cross_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}doc.pdf');
    await input.writeAsString('%PDF-1.4\n%%EOF');

    await expectLater(
      MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: StripPolicy.selective(
          fieldIds: {MetadataFieldId.pngText('Author')},
        ),
      ),
      throwsFormatException,
    );
    expect(
      directory.listSync().where((entity) => entity.path.contains('_clean')),
      isEmpty,
    );
  });
}

List<int> _flacSelectiveFixture() {
  final vendor = 'vendor'.codeUnits;
  final entries = ['TITLE=Secret', 'ARTIST=Visible'];
  final payload = <int>[
    ..._le32(vendor.length),
    ...vendor,
    ..._le32(entries.length)
  ];
  for (final entry in entries) {
    final bytes = entry.codeUnits;
    payload.addAll([..._le32(bytes.length), ...bytes]);
  }
  return [
    ...'fLaC'.codeUnits,
    0,
    0,
    0,
    34,
    ...List<int>.filled(34, 0),
    0x84,
    (payload.length >> 16) & 0xFF,
    (payload.length >> 8) & 0xFF,
    payload.length & 0xFF,
    ...payload,
  ];
}

List<int> _le32(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

int _indexOfBytes(List<int> bytes, List<int> pattern) {
  for (var start = 0; start + pattern.length <= bytes.length; start++) {
    var matches = true;
    for (var i = 0; i < pattern.length; i++) {
      if (bytes[start + i] != pattern[i]) {
        matches = false;
        break;
      }
    }
    if (matches) return start;
  }
  return -1;
}

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
