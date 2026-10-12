import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/openxml_stripper.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

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

  group('integrity hardening', () {
    test('decodeZipEntrySafely can decode the same entry twice', () {
      final payload = Uint8List.fromList(List.generate(4096, (i) => i % 7));
      final bytes = Uint8List.fromList(
        ZipEncoder().encode(
          Archive()..addFile(ArchiveFile('a.bin', payload.length, payload)),
        )!,
      );
      final entry = decodeGuardedZip(bytes).files.single;
      expect(decodeZipEntrySafely(entry, maxBytes: 1 << 20), payload);
      expect(decodeZipEntrySafely(entry, maxBytes: 1 << 20), payload);
      expect(decodeZipEntrySafely(entry, maxBytes: 10), isNull);
    });

    test('archive whose comment contains an EOCD signature is rejected', () {
      final bytes = _zip({'a.txt': 'one', 'b.txt': 'two'});
      final eocd = bytes.length - 22;
      // A trailing byte keeps the embedded record from reaching end of file,
      // so the preflight skips it while the decoder's backwards scan hits it.
      final comment = <int>[
        0x50, 0x4b, 0x05, 0x06, ...List.filled(18, 0), 0x58, //
      ];
      final hostile = Uint8List.fromList([...bytes, ...comment]);
      _patchUint16(hostile, eocd + 20, comment.length);
      expect(() => decodeGuardedZip(hostile), throwsFormatException);
      expect(
        () => repackZipWithoutEntries(hostile, skipPaths: const {}),
        throwsFormatException,
      );
    });

    test('non-flagged UTF-8 non-ASCII name decodes and repacks', () {
      final bytes = _zip({'caf\u00e9.txt': 'one', 'b.txt': 'two'});
      _clearUtf8Flag(bytes);
      expect(() => decodeGuardedZip(bytes), returnsNormally);
      final out = repackZipWithoutEntries(bytes, skipPaths: const {'b.txt'});
      expect(
        ZipDecoder().decodeBytes(out).files.map((f) => f.name),
        ['caf\u00e9.txt'],
      );
    });

    test('backslash-separated entry name decodes and repacks', () {
      final bytes = _zip({'dir/a.txt': 'one', 'b.txt': 'two'});
      _replaceNameByte(bytes, 'dir/a.txt', 3, 0x5c);
      expect(() => decodeGuardedZip(bytes), returnsNormally);
      final out = repackZipWithoutEntries(bytes, skipPaths: const {'b.txt'});
      expect(
        ZipDecoder().decodeBytes(out).files.map((f) => f.name),
        ['dir/a.txt'],
      );
    });

    test('forged second directory with equal names but other size is '
        'rejected', () {
      final bytes = _zip({'a.txt': 'one', 'b.txt': 'two'});
      final eocd = bytes.length - 22;
      final cdOffset = ByteData.sublistView(bytes)
          .getUint32(eocd + 16, Endian.little);
      final cdSize = ByteData.sublistView(bytes)
          .getUint32(eocd + 12, Endian.little);
      final forged = Uint8List.fromList(bytes.sublist(cdOffset, eocd));
      // Forge the first record's uncompressed size (offset 24).
      _patchUint32(forged, 24, 2);
      final forgedOffset = bytes.length;
      final fakeEocd = Uint8List(22);
      ByteData.sublistView(fakeEocd)
        ..setUint32(0, 0x06054b50, Endian.little)
        ..setUint16(8, 2, Endian.little)
        ..setUint16(10, 2, Endian.little)
        ..setUint32(12, cdSize, Endian.little)
        ..setUint32(16, forgedOffset, Endian.little);
      final tail = [...forged, ...fakeEocd, 0x58];
      final hostile = Uint8List.fromList([...bytes, ...tail]);
      _patchUint16(hostile, eocd + 20, tail.length);
      expect(() => decodeGuardedZip(hostile), throwsFormatException);
    });

    test('repacked entries carry the normalized DOS timestamp', () {
      final bytes = _zip({
        '[Content_Types].xml': _docxContentTypes,
        'docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
        'word/media/': '',
      });
      final out = repackZipWithoutEntries(
        bytes,
        skipPaths: const {'docProps/core.xml'},
        replacements: {
          '[Content_Types].xml': Uint8List.fromList(
            _docxContentTypes.codeUnits,
          ),
        },
        exactSkipPaths: true,
      );
      final stamps = _dosStamps(out);
      expect(stamps.length, greaterThanOrEqualTo(6));
      expect(stamps.toSet().length, 1);
      expect(stamps.first.$1 >> 9, 0);
    });

    test('replaced docProps entry does not carry wall-clock time', () {
      final bytes = _zip({
        '[Content_Types].xml': _docxContentTypesWithCore,
        'docProps/core.xml': _core,
        'word/document.xml': '<document/>',
      });
      final result = stripOpenXmlSelective(
        bytes,
        extension: 'docx',
        selectedIds: const {MetadataFieldId.openXmlAuthor},
      );
      final stamps = _dosStamps(result.bytes);
      expect(stamps.toSet().length, 1);
      expect(stamps.first.$1 >> 9, 0);
    });

    test('selective OpenXML validation compares real _rels/.rels bytes', () {
      final input = _zip({
        '[Content_Types].xml': _docxContentTypesWithCore,
        '_rels/.rels': _coreRels('AAAA'),
        'docProps/core.xml': _core,
        'word/document.xml': '<document/>',
      });
      final output = stripOpenXmlSelective(
        input,
        extension: 'docx',
        selectedIds: const {MetadataFieldId.openXmlAuthor},
      ).bytes;
      final decoded = ZipDecoder().decodeBytes(output, verify: false);
      final tampered = Archive();
      for (final f in decoded.files) {
        final content = f.content as List<int>;
        tampered.addFile(
          ArchiveFile(
            f.name,
            content.length,
            f.name == '_rels/.rels' ? _coreRels('BBBB').codeUnits : content,
          ),
        );
      }
      final bad = Uint8List.fromList(ZipEncoder().encode(tampered)!);
      expect(
        () => validateOpenXmlSelective(
          input,
          bad,
          extension: 'docx',
          selectedIds: const {MetadataFieldId.openXmlAuthor},
          expectedRemovedIds: const {MetadataFieldId.openXmlAuthor},
        ),
        throwsFormatException,
      );
    });

    test(
      '_entryContents enforces the per-entry cap on the no-replacement path',
      () {
        final big = Uint8List(maxRepackEntrySize + 1024);
        final archive = Archive()
          ..addFile(ArchiveFile.string(
              '[Content_Types].xml', _docxContentTypesWithCore))
          ..addFile(ArchiveFile.string('word/document.xml', '<document/>'))
          ..addFile(ArchiveFile('word/big.bin', big.length, big));
        final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
        // Forge both size fields of big.bin to a small declared value.
        _forgeUncompressedSize(bytes, 'word/big.bin', 100);
        final small = _zip({
          '[Content_Types].xml': _docxContentTypesWithCore,
          'word/document.xml': '<document/>',
          'word/big.bin': 'x',
        });
        expect(
          () => validateOpenXmlSelective(
            small,
            bytes,
            extension: 'docx',
            selectedIds: const {MetadataFieldId.openXmlAuthor},
            expectedRemovedIds: const {},
          ),
          throwsFormatException,
        );
      },
    );
  });
}

const _docxContentTypesWithCore =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/docProps/core.xml" '
    'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '</Types>';

const _core = '<cp:coreProperties '
    'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    '<dc:creator>Jane</dc:creator><dc:title>Keep me</dc:title>'
    '</cp:coreProperties>';

String _coreRels(String id) =>
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="$id" '
    'Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" '
    'Target="docProps/core.xml"/>'
    '</Relationships>';

/// Returns (dosDate, dosTime) for every local and central header.
List<(int, int)> _dosStamps(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final eocd = bytes.length - 22;
  final count = data.getUint16(eocd + 10, Endian.little);
  var central = data.getUint32(eocd + 16, Endian.little);
  final result = <(int, int)>[];
  for (var i = 0; i < count; i++) {
    expect(data.getUint32(central, Endian.little), 0x02014b50);
    result.add((
      data.getUint16(central + 14, Endian.little),
      data.getUint16(central + 12, Endian.little),
    ));
    final local = data.getUint32(central + 42, Endian.little);
    expect(data.getUint32(local, Endian.little), 0x04034b50);
    result.add((
      data.getUint16(local + 12, Endian.little),
      data.getUint16(local + 10, Endian.little),
    ));
    central += 46 +
        data.getUint16(central + 28, Endian.little) +
        data.getUint16(central + 30, Endian.little) +
        data.getUint16(central + 32, Endian.little);
  }
  return result;
}

void _forgeUncompressedSize(Uint8List bytes, String name, int size) {
  final data = ByteData.sublistView(bytes);
  final eocd = bytes.length - 22;
  final count = data.getUint16(eocd + 10, Endian.little);
  var central = data.getUint32(eocd + 16, Endian.little);
  for (var i = 0; i < count; i++) {
    final nameLen = data.getUint16(central + 28, Endian.little);
    final entryName = String.fromCharCodes(
      bytes.sublist(central + 46, central + 46 + nameLen),
    );
    if (entryName == name) {
      data.setUint32(central + 24, size, Endian.little);
      final local = data.getUint32(central + 42, Endian.little);
      data.setUint32(local + 22, size, Endian.little);
      return;
    }
    central += 46 +
        nameLen +
        data.getUint16(central + 30, Endian.little) +
        data.getUint16(central + 32, Endian.little);
  }
  throw StateError('entry not found');
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

/// Clears general-purpose flag 0x800 in every local and central header.
void _clearUtf8Flag(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i <= bytes.length - 10; i++) {
    final sig = data.getUint32(i, Endian.little);
    final flagOffset = sig == 0x04034b50
        ? i + 6
        : sig == 0x02014b50
            ? i + 8
            : -1;
    if (flagOffset < 0) continue;
    data.setUint16(
      flagOffset,
      data.getUint16(flagOffset, Endian.little) & ~0x800,
      Endian.little,
    );
  }
}

/// Overwrites one byte of [name] in every local and central header.
void _replaceNameByte(Uint8List bytes, String name, int index, int value) {
  final needle = name.codeUnits;
  for (var i = 0; i <= bytes.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length && match; j++) {
      match = bytes[i + j] == needle[j];
    }
    if (match) bytes[i + index] = value;
  }
}

void _patchUint16(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint16(offset, value, Endian.little);
}

void _patchUint32(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint32(offset, value, Endian.little);
}
