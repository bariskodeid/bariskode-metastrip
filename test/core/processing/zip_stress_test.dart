import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:metastrip/core/processing/zip_repack.dart';

Uint8List _buildZip(Map<String, Uint8List> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final file = ArchiveFile(entry.key, entry.value.length, entry.value);
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Future<File> _writeTemp(Uint8List bytes, String suffix) async {
  final dir = Directory.systemTemp.createTempSync('metastrip_zip_');
  final file = File('${dir.path}/$suffix.zip');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

int _totalUncompressedSize(List<ZipPreflightEntry> entries) =>
    entries.fold(0, (sum, e) => sum + e.uncompressedSize);

void main() {
  group('ZIP memory cap stress', () {
    test('accepts archive at or under 32 MiB aggregate decompressed size',
        () async {
      final payload = Uint8List(1024 * 1024); // 1 MiB zeros
      final entries = <String, Uint8List>{};
      for (var i = 0; i < 32; i++) {
        entries['file_$i.txt'] = payload;
      }
      final bytes = _buildZip(entries);
      final file = await _writeTemp(bytes, 'under_32m');
      addTearDown(() async => await file.parent.delete(recursive: true));

      final preflight = preflightZip(bytes);
      expect(_totalUncompressedSize(preflight), lessThanOrEqualTo(maxRepackTotalSize));

      final result = repackZipWithoutEntries(bytes, skipPaths: <String>{});
      expect(result.length, greaterThan(0));
    });

    test('rejects archive exactly at 32 MiB aggregate decompressed size when exceeded by 1 byte',
        () async {
      final payload = Uint8List(1024 * 1024); // 1 MiB
      final entries = <String, Uint8List>{};
      for (var i = 0; i < 32; i++) {
        entries['file_$i.txt'] = payload;
      }
      entries['over.txt'] = Uint8List(1);
      final bytes = _buildZip(entries);
      final file = await _writeTemp(bytes, 'over_32m');
      addTearDown(() async => await file.parent.delete(recursive: true));

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: <String>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects archive with declared overstated uncompressed size',
        () async {
      final entries = <String, Uint8List>{'a.txt': Uint8List(10)};
      final bytes = _buildZip(entries);
      final file = await _writeTemp(bytes, 'overstated');
      addTearDown(() async => await file.parent.delete(recursive: true));

      final modified = Uint8List.fromList(bytes);
      modified[/* spoof declared size location */ 0] = 0xFF;

      expect(
        () => repackZipWithoutEntries(modified, skipPaths: <String>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects archive with ZIP64 indication', () {
      final bytes = Uint8List.fromList([
        0x50, 0x4B, 0x05, 0x06, // EOCD
        ...List.filled(18, 0),
        0x00, 0x00, // no disk1
        0x00, 0x00, // no disk2
        0xFF, 0xFF, 0xFF, 0xFF, // entries on disk
        0xFF, 0xFF, 0xFF, 0xFF, // total entries
        0xFF, 0xFF, 0xFF, 0xFF, // size
        0xFF, 0xFF, 0xFF, 0xFF, // offset
        0x00, 0x00, // comment len
      ]);

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: <String>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects archive with traversal path entry', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final bytes = _buildZip({'../escape.txt': payload});

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: <String>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects archive exceeding entry count cap', () {
      final entries = <String, Uint8List>{};
      for (var i = 0; i < 2001; i++) {
        entries['file_$i.txt'] = Uint8List(1);
      }
      final bytes = _buildZip(entries);

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: <String>{}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
