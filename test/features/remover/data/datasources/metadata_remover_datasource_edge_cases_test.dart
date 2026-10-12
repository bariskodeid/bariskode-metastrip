import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';

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

    test('post-install readback mismatch deletes the unverified copy',
        () async {
      final dir = await Directory('${root.path}/out').create();
      final input = File('${root.path}/image.bmp');
      await input.writeAsBytes(_bmpWithTrailingData());
      final datasource = MetadataRemoverDatasource(
        persistedOutputReader: (_) async => Uint8List.fromList([0x42, 0x4D]),
      );

      await expectLater(
        datasource.stripMetadataWithPolicy(
          input.path,
          outputDirectory: dir.path,
          policy: const StripPolicy.supportedCleanup(),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Output validation failed',
          ),
        ),
      );

      expect(
        dir.listSync().where((e) => e.path.contains('_clean')),
        isEmpty,
      );
    });

    test('stripMetadata rejects selectiveLabels for ODF', () async {
      final dir = await Directory('${root.path}/out').create();
      final input = File('${root.path}/doc.odt');
      await input.writeAsBytes(_minimalOdt());

      await expectLater(
        MetadataRemoverDatasource().stripMetadata(
          input.path,
          outputDirectory: dir.path,
          selectiveLabels: {'meta:initial-creator'},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(dir.listSync().whereType<File>(), isEmpty);
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

Uint8List _minimalOdt() {
  final archive = Archive();
  void add(String name, String text, {bool store = false}) {
    final file = ArchiveFile(name, text.length, text.codeUnits);
    if (store) file.compress = false;
    archive.addFile(file);
  }

  add('mimetype', 'application/vnd.oasis.opendocument.text', store: true);
  add('meta.xml', '<office:document-meta/>');
  add('content.xml', '<office:document-content/>');
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
