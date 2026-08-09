import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/openxml_extractor.dart';

void main() {
  group('extractOpenXml', () {
    test('extracts core.xml properties with entity decoding', () async {
      final bytes = _zipBytes([
        ArchiveFile.string(
          'docProps/core.xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<cp:coreProperties '
              'xmlns:cp="http://schemas.openxmlformats.org/package/2006/'
              'metadata/core-properties" '
              'xmlns:dc="http://purl.org/dc/elements/1.1/" '
              'xmlns:dcterms="http://purl.org/dc/terms/" '
              'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
              '<dc:title>Quarterly &amp; Q2 Report</dc:title>'
              '<dc:creator>Jane Doe</dc:creator>'
              '<dcterms:created xsi:type="dcterms:W3CDTF">'
              '2024-01-01T09:30:00Z</dcterms:created>'
              '<dcterms:modified xsi:type="dcterms:W3CDTF">'
              '2024-02-01T15:45:00Z</dcterms:modified>'
              '<cp:lastModifiedBy>John Smith</cp:lastModifiedBy>'
              '<cp:revision>2</cp:revision>'
              '</cp:coreProperties>',
        ),
        ArchiveFile.string('[Content_Types].xml', ''),
      ]);

      final fields = await extractOpenXml(bytes, extension: 'docx');
      final byLabel = {for (final field in fields) field.label: field};

      final title = byLabel['Title'];
      expect(title, isNotNull);
      expect(title!.section, 'Office Document');
      expect(title.id, MetadataFieldId.openXmlTitle);
      expect(title.value, 'Quarterly & Q2 Report');
      expect(title.isPrivacySensitive, isFalse);

      final author = byLabel['Author'];
      expect(author?.value, 'Jane Doe');
      expect(author?.isPrivacySensitive, isTrue);

      expect(byLabel['Created']?.value, '2024-01-01T09:30:00Z');
      expect(byLabel['Modified']?.value, '2024-02-01T15:45:00Z');
      expect(byLabel['Last Modified By']?.value, 'John Smith');
      expect(byLabel['Last Modified By']?.isPrivacySensitive, isTrue);
      expect(byLabel['Revision']?.value, '2');
    });

    test('extracts app.xml properties and pptx totals', () async {
      final bytes = _zipBytes([
        ArchiveFile.string(
          'docProps/app.xml',
          '<?xml version="1.0"?>'
              '<Properties '
              'xmlns="http://schemas.openxmlformats.org/officeDocument/2006/'
              'extended-properties">'
              '<Application>Microsoft Office PowerPoint</Application>'
              '<Company>Acme Corp</Company>'
              '<AppVersion>16.0000</AppVersion>'
              '<TotalTime>45</TotalTime>'
              '<Slides>12</Slides>'
              '</Properties>',
        ),
      ]);

      final fields = await extractOpenXml(bytes, extension: 'pptx');
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Application']?.value, 'Microsoft Office PowerPoint');
      expect(byLabel['Company']?.value, 'Acme Corp');
      expect(byLabel['Company']?.isPrivacySensitive, isTrue);
      expect(byLabel['Company']?.id, MetadataFieldId.openXmlCompany);
      expect(byLabel['App Version']?.value, '16.0000');
      expect(byLabel['Total Time']?.value, '45');
      expect(byLabel['Slides']?.value, '12');
    });

    test('does not assign a removable ID to wrong-namespace core tags',
        () async {
      final bytes = _zipBytes([
        ArchiveFile.string(
          'docProps/core.xml',
          '<cp:coreProperties '
              'xmlns:cp="http://schemas.openxmlformats.org/package/2006/'
              'metadata/core-properties" '
              'xmlns:wrong="urn:not-dublin-core">'
              '<wrong:creator>Impostor Author</wrong:creator>'
              '</cp:coreProperties>',
        ),
      ]);

      final fields = await extractOpenXml(bytes, extension: 'docx');
      final author = fields.singleWhere((field) => field.label == 'Author');

      expect(author.value, 'Impostor Author');
      expect(author.id, isNull);
    });

    test('does not assign a removable ID to wrong-namespace app tags',
        () async {
      final bytes = _zipBytes([
        ArchiveFile.string(
          'docProps/app.xml',
          '<Properties '
              'xmlns="http://schemas.openxmlformats.org/officeDocument/2006/'
              'extended-properties" xmlns:wrong="urn:not-extended-props">'
              '<wrong:Application>Impostor Office</wrong:Application>'
              '</Properties>',
        ),
      ]);

      final fields = await extractOpenXml(bytes, extension: 'docx');
      final application =
          fields.singleWhere((field) => field.label == 'Application');

      expect(application.value, 'Impostor Office');
      expect(application.id, isNull);
    });

    test('extracts core.xml properties from a non-root location', () async {
      final bytes = _zipBytes([
        ArchiveFile.string(
          'sub/docProps/core.xml',
          '<?xml version="1.0" encoding="UTF-8"?>'
              '<cp:coreProperties '
              'xmlns:cp="http://schemas.openxmlformats.org/package/2006/'
              'metadata/core-properties" '
              'xmlns:dc="http://purl.org/dc/elements/1.1/">'
              '<dc:creator>Jane Doe</dc:creator>'
              '</cp:coreProperties>',
        ),
        ArchiveFile.string('word/document.xml', '<document/>'),
      ]);

      final fields = await extractOpenXml(bytes, extension: 'docx');
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Author']?.value, 'Jane Doe');
    });

    test('returns a status field when no docProps entries exist', () async {
      final bytes = _zipBytes([
        ArchiveFile.string('hello.txt', 'world'),
      ]);

      final fields = await extractOpenXml(bytes, extension: 'xlsx');

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Office Document');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No office document metadata found');
    });

    test('returns a status field for bytes that are not a zip', () async {
      final bytes = Uint8List.fromList(utf8.encode('not a zip file'));

      final fields = await extractOpenXml(bytes, extension: 'docx');

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Office Document');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Invalid office document');
    });

    test(
        'returns a status field when a docProps entry declares an oversized size',
        () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string('docProps/core.xml', '<coreProperties/>'),
        )
        ..addFile(
          ArchiveFile.string('docProps/app.xml', '<Properties/>'),
        );
      // Declared sizes above the 64MB per-entry cap; the actual content stays
      // tiny so decoding the fixture itself is cheap and never decompresses.
      archive.files[0].size = 70 * 1024 * 1024;
      archive.files[1].size = 70 * 1024 * 1024;
      final bytes = _zipBytes(archive.files);

      final fields = await extractOpenXml(bytes, extension: 'docx');

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Office Document');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Invalid office document');
    });

    test('reads small properties despite an unrelated oversized entry',
        () async {
      final large = ArchiveFile.string('word/media/large.bin', 'x')
        ..size = 70 * 1024 * 1024;
      final bytes = _zipBytes([
        ArchiveFile.string(
          'docProps/core.xml',
          '<cp:coreProperties xmlns:cp="core" xmlns:dc="dc">'
              '<dc:creator>Jane Doe</dc:creator>'
              '</cp:coreProperties>',
        ),
        large,
      ]);

      final fields = await extractOpenXml(bytes, extension: 'docx');
      final byLabel = {for (final field in fields) field.label: field};
      expect(byLabel['Author']?.value, 'Jane Doe');
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
