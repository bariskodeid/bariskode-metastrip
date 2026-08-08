import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';

void main() {
  group('BMP removal integration', () {
    late Directory directory;
    late File input;

    setUp(() async {
      directory =
          await Directory.systemTemp.createTemp('metastrip_bmp_phase2_');
      input = File('${directory.path}${Platform.pathSeparator}image.bmp');
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('routes a valid BMP and installs only the canonical clean copy',
        () async {
      final bytes = _bmpWithTrailingData();
      await input.writeAsBytes(bytes);

      final output = await MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: directory.path,
      );
      final installed = await output.readAsBytes();

      expect(output.path, endsWith('image_clean.bmp'));
      expect(installed.length, 58);
      expect(installed.sublist(54), bytes.sublist(54, 58));
      expect(ByteData.sublistView(installed).getUint32(2, Endian.little), 58);
      expect(ByteData.sublistView(installed).getUint32(34, Endian.little), 4);
      expect(
        directory.listSync().map((entity) => entity.path),
        containsAll([input.path, output.path]),
      );
      expect(
        directory.listSync().where(
              (entity) =>
                  entity.path.endsWith('.tmp') ||
                  entity.path.endsWith('.claim'),
            ),
        isEmpty,
      );
    });

    test('malformed BMP fails closed and installs no output', () async {
      await input.writeAsBytes(_bmpWithTrailingData().sublist(0, 56));

      await expectLater(
        MetadataRemoverDatasource().stripMetadata(
          input.path,
          outputDirectory: directory.path,
        ),
        throwsFormatException,
      );

      final remainingNames = directory
          .listSync()
          .map((entity) => entity.uri.pathSegments.last)
          .toList();
      expect(remainingNames, ['image.bmp']);
    });

    test('policy path reports verified local persisted output', () async {
      await input.writeAsBytes(_bmpWithTrailingData());

      final result = await MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: directory.path,
        policy: const StripPolicy.supportedCleanup(),
      );

      expect(
          result.report.verificationOutcome, StripVerificationOutcome.verified);
      expect(result.report.outputValidated, isTrue);
      expect(result.report.requestedFieldIds, isEmpty);
      expect(result.report.removedFieldIds, isEmpty);
      expect(result.report.warnings, isEmpty);
    });

    test('persisted corruption fails closed and rolls back clean output',
        () async {
      await input.writeAsBytes(_bmpWithTrailingData());
      final datasource = MetadataRemoverDatasource(
        persistedOutputReader: (_) async => Uint8List.fromList([0x42, 0x4D]),
      );

      await expectLater(
        datasource.stripMetadataWithPolicy(
          input.path,
          outputDirectory: directory.path,
          policy: const StripPolicy.supportedCleanup(),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        directory.listSync().where((entity) => entity.path.contains('_clean')),
        isEmpty,
      );
    });

    test('does not delete a persisted output replaced during validation',
        () async {
      await input.writeAsBytes(_bmpWithTrailingData());
      final datasource = MetadataRemoverDatasource(
        persistedOutputReader: (output) async {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          await output.writeAsBytes([0x42, 0x4D], flush: true);
          return Uint8List.fromList([0x42, 0x4D]);
        },
      );

      await expectLater(
        datasource.stripMetadataWithPolicy(
          input.path,
          outputDirectory: directory.path,
          policy: const StripPolicy.supportedCleanup(),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Output validation failed; unverified copy may remain',
          ),
        ),
      );
      expect(
        directory.listSync().where((entity) => entity.path.contains('_clean')),
        hasLength(1),
      );
    });

    test('oversized BMP is rejected before output installation', () async {
      final handle = await input.open(mode: FileMode.write);
      try {
        await handle.writeFrom(_bmpWithTrailingData());
        await handle.setPosition(AppConstants.maxRemoverFileSizeBytes);
        await handle.writeByte(0x00);
      } finally {
        await handle.close();
      }

      await expectLater(
        MetadataRemoverDatasource().stripMetadata(
          input.path,
          outputDirectory: directory.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        directory.listSync().where((entity) =>
            entity.path.contains('_clean') ||
            entity.path.endsWith('.tmp') ||
            entity.path.endsWith('.claim')),
        isEmpty,
      );
    });
  });
}

Uint8List _bmpWithTrailingData() {
  final bytes = Uint8List(62);
  final header = ByteData.sublistView(bytes);
  bytes.setAll(0, 'BM'.codeUnits);
  header
    ..setUint32(2, 62, Endian.little)
    ..setUint16(6, 0x1111, Endian.little)
    ..setUint16(8, 0x2222, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, 1, Endian.little)
    ..setInt32(22, 1, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(30, 0, Endian.little)
    ..setUint32(34, 4, Endian.little);
  bytes.setAll(54, [0x10, 0x20, 0x30, 0x00, ...'XMP!'.codeUnits]);
  return bytes;
}
