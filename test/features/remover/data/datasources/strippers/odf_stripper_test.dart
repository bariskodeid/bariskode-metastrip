import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/odf_stripper.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

void main() {
  group('stripOdf', () {
    test('removes meta.xml and keeps content.xml', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': '<office:meta/>',
        'content.xml': '<office:document-content/>',
      });

      final result = stripOdf(bytes);

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('content.xml'));
      expect(names, contains('mimetype'));
      expect(names, isNot(contains('meta.xml')));
      final entries = preflightZip(result);
      expect(entries.first.name, 'mimetype');
      expect(entries.first.compressionMethod, 0);
      expect(
        String.fromCharCodes(
          archive.findFile('content.xml')!.content as List<int>,
        ),
        '<office:document-content/>',
      );
    });

    test('full cleanup removes nested meta.xml suffix entries', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'nested/meta.xml': '<office:meta>remove</office:meta>',
        'content.xml':
            '<office:document-content>keep</office:document-content>',
      });

      final archive = ZipDecoder().decodeBytes(stripOdf(bytes), verify: false);

      expect(archive.findFile('nested/meta.xml'), isNull);
      expect(
        String.fromCharCodes(
          archive.findFile('content.xml')!.content as List<int>,
        ),
        '<office:document-content>keep</office:document-content>',
      );
    });

    test('returns the original bytes when there is no meta.xml', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'content.xml': '<office:document-content/>',
        'styles.xml': '<office:styles/>',
      });

      final result = stripOdf(bytes);

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('rejects a package for the wrong ODF extension', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'content.xml': '<office:document-content/>',
      });

      expect(
        () => stripOdf(bytes, extension: 'ods'),
        throwsFormatException,
      );
    });

    test('rejects a mimetype entry that is not first', () {
      final bytes = _odfZip({
        'content.xml': '<office:document-content/>',
        'mimetype': 'application/vnd.oasis.opendocument.text',
      });

      expect(() => stripOdf(bytes), throwsFormatException);
    });

    test('rejects a mimetype value with trailing whitespace', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text\n',
        'content.xml': '<office:document-content/>',
      });

      expect(() => stripOdf(bytes), throwsFormatException);
    });
  });

  group('stripOdfSelective', () {
    test('removes selected canonical property and preserves all else', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': _metaXml,
        'content.xml': '<keep>payload</keep>',
        'Pictures/image.bin': 'unchanged',
      });

      final result = stripOdfSelective(
        bytes,
        extension: 'odt',
        selectedIds: const {MetadataFieldId.odfAuthor},
      );
      final archive = ZipDecoder().decodeBytes(result.bytes, verify: false);
      final meta = String.fromCharCodes(
        archive.findFile('meta.xml')!.content as List<int>,
      );

      expect(result.removedIds, {MetadataFieldId.odfAuthor});
      expect(result.absentIds, isEmpty);
      expect(meta, isNot(contains('Jane Doe')));
      expect(meta, contains('Keep title'));
      expect(meta, contains('custom-value'));
      expect(
        String.fromCharCodes(
          archive.findFile('Pictures/image.bin')!.content as List<int>,
        ),
        'unchanged',
      );
    });

    test('reports absent selected property without changing bytes', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'content.xml': '<keep/>',
      });
      final result = stripOdfSelective(
        bytes,
        extension: 'odt',
        selectedIds: const {MetadataFieldId.odfAuthor},
      );

      expect(identical(result.bytes, bytes), isTrue);
      expect(result.removedIds, isEmpty);
      expect(result.absentIds, {MetadataFieldId.odfAuthor});
    });

    test('fails closed on duplicate selected properties', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': _metaXml.replaceFirst(
          '</office:meta>',
          '<dc:title>Duplicate</dc:title></office:meta>',
        ),
        'content.xml': '<keep/>',
      });

      expect(
        () => stripOdfSelective(
          bytes,
          extension: 'odt',
          selectedIds: const {MetadataFieldId.odfTitle},
        ),
        throwsFormatException,
      );
    });

    test('removes every repeated keyword selected by one field policy', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': _metaXml.replaceFirst(
          '</office:meta>',
          '<meta:keyword>second</meta:keyword></office:meta>',
        ),
        'content.xml': '<keep/>',
      });

      final result = stripOdfSelective(
        bytes,
        extension: 'odt',
        selectedIds: const {MetadataFieldId.odfKeywords},
      );
      final meta = String.fromCharCodes(
        ZipDecoder()
            .decodeBytes(result.bytes, verify: false)
            .findFile('meta.xml')!
            .content as List<int>,
      );
      expect(meta, isNot(contains('custom-value')));
      expect(meta, isNot(contains('second')));
      expect(result.removedIds, {MetadataFieldId.odfKeywords});
    });

    test('rejects malformed metadata and leaves nested meta.xml untouched', () {
      final malformed = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': '<office:document-meta>',
        'content.xml': '<keep/>',
      });
      final nested = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': _metaXml,
        'nested/meta.xml': _metaXml,
        'content.xml': '<keep/>',
      });

      expect(
        () => stripOdfSelective(
          malformed,
          extension: 'odt',
          selectedIds: const {MetadataFieldId.odfTitle},
        ),
        throwsFormatException,
      );
      final result = stripOdfSelective(
        nested,
        extension: 'odt',
        selectedIds: const {MetadataFieldId.odfTitle},
      );
      expect(result.removedIds, {MetadataFieldId.odfTitle});
      final output = ZipDecoder().decodeBytes(result.bytes, verify: false);
      expect(
        String.fromCharCodes(
          output.findFile('nested/meta.xml')!.content as List<int>,
        ),
        _metaXml,
      );
    });

    test('nested-only meta.xml remains outside selective scope', () {
      final bytes = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'nested/meta.xml': _metaXml,
        'content.xml': '<keep/>',
      });

      final result = stripOdfSelective(
        bytes,
        extension: 'odt',
        selectedIds: const {MetadataFieldId.odfTitle},
      );

      expect(identical(result.bytes, bytes), isTrue);
      expect(result.removedIds, isEmpty);
      expect(result.absentIds, {MetadataFieldId.odfTitle});
    });

    test('fails closed for DOCTYPE entities and excessive XML depth', () {
      final entity = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': '<!DOCTYPE office:document-meta [<!ENTITY x "secret">]>'
            '<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0">'
            '<office:meta><dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">&x;</dc:title>'
            '</office:meta></office:document-meta>',
        'content.xml': '<keep/>',
      });
      var deep = '<office:meta>';
      for (var i = 0; i < 70; i++) {
        deep += '<x xmlns:x="urn:custom">';
      }
      deep += 'value';
      for (var i = 0; i < 70; i++) {
        deep += '</x>';
      }
      final deepPackage = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': '<office:document-meta '
            'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0">'
            '$deep</office:document-meta>',
        'content.xml': '<keep/>',
      });

      for (final bytes in [entity, deepPackage]) {
        expect(
          () => stripOdfSelective(
            bytes,
            extension: 'odt',
            selectedIds: const {MetadataFieldId.odfTitle},
          ),
          throwsFormatException,
        );
      }
    });

    test('accepts all ODF MIME/package variants in the bounded scope', () {
      for (final (extension, mime) in const [
        ('odt', 'application/vnd.oasis.opendocument.text'),
        ('ods', 'application/vnd.oasis.opendocument.spreadsheet'),
        ('odp', 'application/vnd.oasis.opendocument.presentation'),
      ]) {
        final result = stripOdfSelective(
          _odfZip({
            'mimetype': mime,
            'meta.xml': _metaXml,
            'content.xml': '<keep/>',
          }),
          extension: extension,
          selectedIds: const {MetadataFieldId.odfAuthor},
        );
        expect(result.removedIds, contains(MetadataFieldId.odfAuthor));
      }
    });

    test('preserves exact entry order, type, and non-meta content for ODS/ODP',
        () {
      for (final (extension, mime) in const [
        ('ods', 'application/vnd.oasis.opendocument.spreadsheet'),
        ('odp', 'application/vnd.oasis.opendocument.presentation'),
      ]) {
        final directory = ArchiveFile('Pictures/', 0, null)..isFile = false;
        final source = Archive()
          ..addFile(ArchiveFile.string('mimetype', mime)..compress = false)
          ..addFile(directory)
          ..addFile(ArchiveFile.string('content.xml', 'decompressed payload'))
          ..addFile(ArchiveFile.string('meta.xml', _metaXml))
          ..addFile(ArchiveFile.string('Pictures/image.bin', 'binary payload'));
        final input = Uint8List.fromList(ZipEncoder().encode(source)!);

        final result = stripOdfSelective(
          input,
          extension: extension,
          selectedIds: const {MetadataFieldId.odfAuthor},
        );
        final before = ZipDecoder().decodeBytes(input, verify: false);
        final after = ZipDecoder().decodeBytes(result.bytes, verify: false);
        final preflight = preflightZip(result.bytes);

        expect(after.files.map((entry) => entry.name),
            before.files.map((entry) => entry.name));
        expect(after.files.map((entry) => entry.isFile),
            before.files.map((entry) => entry.isFile));
        expect(preflight.first.name, 'mimetype');
        expect(preflight.first.compressionMethod, 0);
        for (final path in ['content.xml', 'Pictures/image.bin']) {
          expect(
            after.findFile(path)!.content as List<int>,
            before.findFile(path)!.content as List<int>,
          );
        }
      }
    });

    test('matches preserved entries by name when central order is reordered',
        () {
      final localOrder = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'content.xml': '<keep/>',
        'meta.xml': _metaXml,
        'Pictures/image.bin': 'binary payload',
      });
      final input = _swapCentralDirectoryRecords(localOrder, 0, 2);

      final result = stripOdfSelective(
        input,
        extension: 'odt',
        selectedIds: const {MetadataFieldId.odfAuthor},
      );

      expect(result.removedIds, {MetadataFieldId.odfAuthor});
      expect(
        ZipDecoder()
            .decodeBytes(result.bytes, verify: false)
            .findFile('Pictures/image.bin')!
            .content,
        'binary payload'.codeUnits,
      );
    });

    test('semantic exclusion applies only under canonical office:meta', () {
      final input = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': _metaXml,
        'content.xml': '<keep/>',
      });
      final tamperedMeta = _metaXml
          .replaceFirst('<dc:title>Keep title</dc:title>', '')
          .replaceFirst(
            '</office:document-meta>',
            '<x:meta xmlns:x="urn:custom">'
                '<dc:title>Injected</dc:title>'
                '</x:meta></office:document-meta>',
          );
      final output = _odfZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'meta.xml': tamperedMeta,
        'content.xml': '<keep/>',
      });

      expect(
        () => validateOdfSelective(
          input,
          output,
          extension: 'odt',
          selectedIds: const {MetadataFieldId.odfTitle},
          expectedRemovedIds: const {MetadataFieldId.odfTitle},
        ),
        throwsFormatException,
      );
    });

    test('rejects declared per-entry and cumulative inventory excesses', () {
      final oversizedEntry = ArchiveFile.string('large.bin', 'x')
        ..size = maxRepackEntrySize + 1;
      final cumulativeA = ArchiveFile.string('a.bin', 'a')
        ..size = maxRepackTotalSize ~/ 2 + 1;
      final cumulativeB = ArchiveFile.string('b.bin', 'b')
        ..size = maxRepackTotalSize ~/ 2 + 1;

      for (final extras in [
        [oversizedEntry],
        [cumulativeA, cumulativeB],
      ]) {
        final archive = Archive()
          ..addFile(
            ArchiveFile.string(
              'mimetype',
              'application/vnd.oasis.opendocument.text',
            )..compress = false,
          )
          ..addFile(ArchiveFile.string('meta.xml', _metaXml))
          ..addFile(ArchiveFile.string('content.xml', '<keep/>'));
        for (final entry in extras) {
          archive.addFile(entry);
        }
        final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

        expect(
          () => stripOdfSelective(
            bytes,
            extension: 'odt',
            selectedIds: const {MetadataFieldId.odfAuthor},
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects a dangerous unrelated compressed entry before decoding it',
        () {
      final dangerous = ArchiveFile.string('unrelated.bin', 'x')
        ..size = maxRepackTotalSize + 1;
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'mimetype',
            'application/vnd.oasis.opendocument.text',
          )..compress = false,
        )
        ..addFile(ArchiveFile.string('meta.xml', _metaXml))
        ..addFile(ArchiveFile.string('content.xml', '<keep/>'))
        ..addFile(dangerous);

      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      expect(
        () => stripOdfSelective(
          bytes,
          extension: 'odt',
          selectedIds: const {MetadataFieldId.odfAuthor},
        ),
        throwsFormatException,
      );
    });
  });
}

const _metaXml = '<office:document-meta '
    'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">'
    '<office:meta><dc:title>Keep title</dc:title>'
    '<dc:creator>Jane Doe</dc:creator><meta:keyword>custom-value</meta:keyword>'
    '<x:creator xmlns:x="urn:custom">do-not-remove</x:creator>'
    '</office:meta></office:document-meta>';

Uint8List _odfZip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    final file = ArchiveFile.string(name, content);
    if (name == 'mimetype') file.compress = false;
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Uint8List _swapCentralDirectoryRecords(
  Uint8List bytes,
  int firstIndex,
  int secondIndex,
) {
  int u16(int offset) => bytes[offset] | bytes[offset + 1] << 8;
  int u32(int offset) =>
      bytes[offset] |
      bytes[offset + 1] << 8 |
      bytes[offset + 2] << 16 |
      bytes[offset + 3] << 24;
  final eocd = bytes.length - 22;
  final directoryOffset = u32(eocd + 16);
  final count = u16(eocd + 8);
  final records = <Uint8List>[];
  var cursor = directoryOffset;
  for (var i = 0; i < count; i++) {
    final length = 46 + u16(cursor + 28) + u16(cursor + 30) + u16(cursor + 32);
    records.add(Uint8List.fromList(bytes.sublist(cursor, cursor + length)));
    cursor += length;
  }
  final temporary = records[firstIndex];
  records[firstIndex] = records[secondIndex];
  records[secondIndex] = temporary;
  final output = Uint8List.fromList(bytes);
  cursor = directoryOffset;
  for (final record in records) {
    output.setRange(cursor, cursor + record.length, record);
    cursor += record.length;
  }
  return output;
}
