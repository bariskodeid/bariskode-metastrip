import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/odf_extractor.dart';

void main() {
  group('extractOdf', () {
    test('extracts ODF meta.xml fields', () async {
      final bytes = _zipBytes([
        ArchiveFile.string(
          'meta.xml',
          '<?xml version="1.0" encoding="UTF-8"?>'
              '<office:document-meta '
              'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
              'xmlns:dc="http://purl.org/dc/elements/1.1/" '
              'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">'
              '<office:meta>'
              '<dc:title>Budget 2026</dc:title>'
              '<dc:creator>Jane Doe</dc:creator>'
              '<meta:initial-creator>Jane Doe</meta:initial-creator>'
              '<meta:generator>LibreOffice/7.6</meta:generator>'
              '<meta:keyword>finance</meta:keyword>'
              '<meta:creation-date>2026-01-05T10:00:00</meta:creation-date>'
              '</office:meta>'
              '</office:document-meta>',
        ),
      ]);

      final fields = await extractOdf(bytes);
      final byLabel = {for (final field in fields) field.label: field};

      final title = byLabel['Title'];
      expect(title, isNotNull);
      expect(title!.section, 'ODF Document');
      expect(title.value, 'Budget 2026');

      expect(byLabel['Author']?.value, 'Jane Doe');
      expect(byLabel['Author']?.isPrivacySensitive, isTrue);
      expect(byLabel['Initial Creator']?.value, 'Jane Doe');
      expect(byLabel['Initial Creator']?.isPrivacySensitive, isTrue);
      expect(byLabel['Generator']?.value, 'LibreOffice/7.6');
      expect(byLabel['Keywords']?.value, 'finance');
      expect(byLabel['Created']?.value, '2026-01-05T10:00:00');
    });

    test('returns a status field when meta.xml is missing', () async {
      final bytes = _zipBytes([
        ArchiveFile.string('content.xml', '<office:document/>'),
      ]);

      final fields = await extractOdf(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'ODF Document');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No ODF metadata found');
    });

    test('returns a status field for bytes that are not a zip', () async {
      final bytes = Uint8List.fromList(utf8.encode('not a zip file'));

      final fields = await extractOdf(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'ODF Document');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Invalid ODF document');
    });
  });
}

/// Builds a zip byte buffer from [files] using the archive package.
Uint8List _zipBytes(List<ArchiveFile> files) {
  final archive = Archive();
  for (final file in files) {
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
