import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';

void main() {
  group('MetadataRemoverDatasource edge cases', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('metastrip_edge_');
      addTearDown(() => root.delete(recursive: true));
    });

    test('rejects oversized file without creating output', () async {
      final dir = await Directory('${root.path}/out').create();
      final input = File('${root.path}/huge.jpg');
      await input.writeAsBytes(List<int>.filled(AppConstants.maxRemoverFileSizeBytes + 1, 0xFF));

      await expectLater(
        MetadataRemoverDatasource().stripJpegMetadata(
          input.path,
          outputDirectory: dir.path,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(dir.listSync().whereType<File>(), isEmpty);
      expect(await input.exists(), isTrue);
    });

    test('keeps original unchanged on corrupt input', () async {
      final dir = await Directory('${root.path}/out').create();
      final input = File('${root.path}/broken.jpg');
      final originalBytes = <int>[0x00, 0x01, 0x02];
      await input.writeAsBytes(originalBytes);

      await expectLater(
        MetadataRemoverDatasource().stripJpegMetadata(
          input.path,
          outputDirectory: dir.path,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(await input.readAsBytes(), originalBytes);
      expect(dir.listSync().whereType<File>(), isEmpty);
    });

    test('uses _clean_1 naming when output file already exists', () async {
      final dir = await Directory('${root.path}/out').create();
      final input = File('${root.path}/photo.jpg');
      await input.writeAsBytes([
        0xFF, 0xD8,
        0xFF, 0xDA, 0, 2, 1, 2,
        0xFF, 0xD9,
      ]);

      final first = await MetadataRemoverDatasource().stripJpegMetadata(
        input.path,
        outputDirectory: dir.path,
      );
      expect(first.path, contains('_clean'));

      final second = await MetadataRemoverDatasource().stripJpegMetadata(
        input.path,
        outputDirectory: dir.path,
      );
      expect(second.path, contains('_clean_1'));
      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
      expect(await input.exists(), isTrue);
    });
  });
}
