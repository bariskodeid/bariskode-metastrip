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

  group('preflightZip', () {
    test('accepts oversized payload declarations for structural inspection',
        () {
      final large = ArchiveFile.string('large.bin', 'x')
        ..size = maxRepackEntrySize + 1;
      final archive = Archive()..addFile(large);
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      expect(preflightZip(bytes), hasLength(1));
    });

    test('rejects encrypted entries before archive decoding', () {
      final bytes = _zip({'a.txt': 'safe'});
      _patchUint16(bytes, _centralOffset(bytes) + 8, 1);

      expect(() => preflightZip(bytes), throwsFormatException);
    });

    test('rejects unsupported compression methods before decoding', () {
      final bytes = _zip({'a.txt': 'safe'});
      _patchUint16(bytes, _centralOffset(bytes) + 10, 12);

      expect(() => preflightZip(bytes), throwsFormatException);
    });

    test('rejects Unix symbolic links before decoding', () {
      final bytes = _zip({'link': 'target'});
      final central = _centralOffset(bytes);
      _patchUint16(bytes, central + 4, 3 << 8);
      _patchUint32(bytes, central + 38, 0xa000 << 16);

      expect(() => preflightZip(bytes), throwsFormatException);
    });

    test('bounded decoder aborts an understated deflate stream', () {
      final bytes = _zip({'bomb.txt': 'A' * 1024 * 1024});
      final central = _centralOffset(bytes);
      _patchUint32(bytes, 22, 1);
      _patchUint32(bytes, central + 24, 1);
      final archive = decodeGuardedZip(bytes);

      expect(
        () => decodeZipEntrySafely(
          archive.findFile('bomb.txt')!,
          maxBytes: 1024,
        ),
        throwsFormatException,
      );
    });

    test('rejects canonically duplicate entry names', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('a/b.txt', 'first'))
        ..addFile(ArchiveFile.string(r'a\b.txt', 'second'));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      expect(() => preflightZip(bytes), throwsFormatException);
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
        '[Content_Types].xml': _docxContentTypes,
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

    test('stripOpenXml removes a viewer-visible non-root docProps entry', () {
      final bytes = _zip({
        '[Content_Types].xml': _docxContentTypes,
        'a/docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);

      expect(zipArchiveContainsEntry(result, 'a/docProps/core.xml'), isFalse);
      expect(zipArchiveContainsEntry(result, 'word/document.xml'), isTrue);
    });

    test('rejects archives with path-traversal names', () {
      final bytes = _zip({
        '../evil.txt': 'pwned',
        'a/../escape.txt': 'pwned',
        'C:/win.txt': 'pwned',
        '/abs.txt': 'pwned',
        'safe.txt': 'ok',
      });

      expect(
        () => repackZipWithoutEntries(bytes, skipPaths: const {}),
        throwsFormatException,
      );
    });

    test('throws FormatException when the declared total size exceeds the cap',
        () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('a.txt', 'small'))
        ..addFile(
          ArchiveFile('big.bin', 0, Uint8List.fromList([1, 2, 3])),
        );
      // Declared uncompressed size above the 32MB cap; the actual content
      // stays tiny, so decoding the fixture itself is cheap.
      archive.files.last.size = maxRepackTotalSize + 1;
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

    test('rejects an entry whose declared size exceeds the per-entry cap', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('a.txt', 'small'))
        ..addFile(
          ArchiveFile('big.bin', 0, Uint8List.fromList([1, 2, 3])),
        );
      // Declared size above the repack entry cap. The real content stays tiny
      // so the fixture itself is cheap to encode/decode.
      archive.files.last.size = maxRepackEntrySize + 1;
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
      // A real payload larger than the 32MB repack cap. The declared size
      // is accurate, so both the declared pre-check and the decompressed
      // content check would reject it.
      final bigContent = Uint8List(maxRepackEntrySize + 1);
      final archive = Archive()..addFile(ArchiveFile('big.bin', 0, bigContent));
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

const _docxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '</Types>';

int _centralOffset(Uint8List bytes) {
  for (var i = 0; i <= bytes.length - 4; i++) {
    if (bytes[i] == 0x50 &&
        bytes[i + 1] == 0x4b &&
        bytes[i + 2] == 0x01 &&
        bytes[i + 3] == 0x02) {
      return i;
    }
  }
  throw StateError('Central directory not found');
}

void _patchUint16(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint16(offset, value, Endian.little);
}

void _patchUint32(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint32(offset, value, Endian.little);
}
