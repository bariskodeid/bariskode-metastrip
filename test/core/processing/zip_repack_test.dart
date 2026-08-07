import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/openxml_stripper.dart';

void main() {
  group('normalizeEntryPath', () {
    test('normalizes dot segments and repeated slashes', () {
      expect(
        normalizeEntryPath('a/./docProps//core.xml'),
        'a/docProps/core.xml',
      );
    });

    test('converts backslashes and drops a leading .\\ prefix', () {
      expect(normalizeEntryPath('.\\docProps\\core.xml'), 'docProps/core.xml');
    });

    test('collapses repeated ./ prefixes', () {
      expect(
        normalizeEntryPath('././docProps/core.xml'),
        'docProps/core.xml',
      );
    });

    test('leaves parent segments untouched', () {
      expect(normalizeEntryPath('a/../../evil.txt'), 'a/../../evil.txt');
    });
  });

  group('zipArchiveContainsEntry', () {
    test('matches non-canonical entry names', () {
      final bytes = _zip({
        './docProps//core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      expect(zipArchiveContainsEntry(bytes, 'docProps/core.xml'), isTrue);
    });

    test('matches a metadata entry stored at a non-root location', () {
      final bytes = _zip({
        'sub/docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      expect(zipArchiveContainsEntry(bytes, 'docProps/core.xml'), isTrue);
    });
  });

  group('repackZipWithoutEntries', () {
    test('removes skipped entries and keeps the rest verbatim', () {
      final bytes = _zip({
        'a.txt': 'hello',
        'docProps/core.xml': '<coreProperties/>',
        'b.txt': 'world',
      });

      final result = repackZipWithoutEntries(
        bytes,
        skipPaths: const {'docProps/core.xml'},
      );

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('a.txt'));
      expect(names, contains('b.txt'));
      expect(names, isNot(contains('docProps/core.xml')));
      expect(
        String.fromCharCodes(archive.findFile('a.txt')!.content as List<int>),
        'hello',
      );
      expect(
        String.fromCharCodes(archive.findFile('b.txt')!.content as List<int>),
        'world',
      );
    });

    test('removes a skipped entry stored at a non-root location', () {
      final bytes = _zip({
        'a/docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      final result = repackZipWithoutEntries(
        bytes,
        skipPaths: const {'docProps/core.xml'},
      );

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('word/document.xml'));
      expect(names, isNot(contains('a/docProps/core.xml')));
    });

    test('stripOpenXml removes a non-root docProps entry', () {
      final bytes = _zip({
        'a/docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);

      expect(zipArchiveContainsEntry(result, 'a/docProps/core.xml'), isFalse);
      expect(zipArchiveContainsEntry(result, 'word/document.xml'), isTrue);
    });

    test('drops entries with path-traversal names', () {
      final bytes = _zip({
        '../evil.txt': 'pwned',
        'a/../escape.txt': 'pwned',
        'C:/win.txt': 'pwned',
        '/abs.txt': 'pwned',
        'safe.txt': 'ok',
      });

      final result = repackZipWithoutEntries(bytes, skipPaths: const {});

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toList();
      expect(names, ['safe.txt']);
      expect(
        String.fromCharCodes(archive.findFile('safe.txt')!.content as List<int>),
        'ok',
      );
    });

    test('throws FormatException when the declared total size exceeds the cap',
        () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('a.txt', 'small'))
        ..addFile(
          ArchiveFile('big.bin', 0, Uint8List.fromList([1, 2, 3])),
        );
      // Declared uncompressed size above the 256MB cap; the actual content
      // stays tiny, so decoding the fixture itself is cheap.
      archive.files.last.size = 300 * 1024 * 1024;
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: const {}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    });

    test('throws FormatException when the entry count exceeds the cap', () {
      final archive = Archive();
      for (var i = 0; i < 2001; i++) {
        archive.addFile(ArchiveFile.string('f$i.txt', 'x'));
      }
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: const {}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    });

    test('rejects an entry whose declared size exceeds the per-entry cap',
        () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('a.txt', 'small'))
        ..addFile(
          ArchiveFile('big.bin', 0, Uint8List.fromList([1, 2, 3])),
        );
      // Declared size above the 64MB per-entry cap but below the 256MB total
      // cap, so only the per-entry guard can catch it. The real content stays
      // tiny so the fixture itself is cheap to encode/decode.
      archive.files.last.size = 70 * 1024 * 1024;
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: const {}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    });

    test('throws FormatException when an entry decompresses past the cap', () {
      // A real payload larger than the 64MB per-entry cap. The declared size
      // is accurate, so both the declared pre-check and the decompressed
      // content check would reject it.
      final bigContent = Uint8List(70 * 1024 * 1024);
      final archive = Archive()
        ..addFile(ArchiveFile('big.bin', 0, bigContent));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: const {}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    });

    test('throws FormatException when every entry is skipped', () {
      final bytes = _zip({'docProps/core.xml': '<coreProperties/>'});

      expect(
        () => repackZipWithoutEntries(
          bytes,
          skipPaths: const {'docProps/core.xml'},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('no entries'),
          ),
        ),
      );
    });

    test('throws FormatException for bytes that are not a zip', () {
      expect(
        () => repackZipWithoutEntries(
          Uint8List.fromList('not a zip at all'.codeUnits),
          skipPaths: const {},
        ),
        throwsFormatException,
      );
    });
  });
}

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    archive.addFile(ArchiveFile.string(name, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
