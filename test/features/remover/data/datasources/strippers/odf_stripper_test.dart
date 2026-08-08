import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/odf_stripper.dart';

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
}

Uint8List _odfZip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    final file = ArchiveFile.string(name, content);
    if (name == 'mimetype') file.compress = false;
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
