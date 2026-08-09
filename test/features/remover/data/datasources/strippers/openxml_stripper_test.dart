import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/openxml_stripper.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

void main() {
  group('stripOpenXml', () {
    test('removes docProps entries and keeps document content', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        'docProps/core.xml': '<coreProperties/>',
        'docProps/app.xml': '<Properties/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('word/document.xml'));
      expect(names, isNot(contains('docProps/core.xml')));
      expect(names, isNot(contains('docProps/app.xml')));
      expect(
        String.fromCharCodes(
          archive.findFile('word/document.xml')!.content as List<int>,
        ),
        '<document/>',
      );
    });

    test('removes a docProps/core.xml entry with a ./ prefix', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        './docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('word/document.xml'));
      expect(names, isNot(contains('./docProps/core.xml')));
    });

    test('removes viewer-visible core.xml stored at a non-root location', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        'sub/docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('word/document.xml'));
      expect(names, isNot(contains('sub/docProps/core.xml')));
      expect(
        String.fromCharCodes(
          archive.findFile('word/document.xml')!.content as List<int>,
        ),
        '<document/>',
      );
    });

    test('removes app and custom properties without core properties', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _xlsxContentTypes,
        'docProps/app.xml': '<Properties/>',
        'docProps/custom.xml': '<Properties/>',
        'xl/workbook.xml': '<workbook/>',
      });

      final result = stripOpenXml(bytes, extension: 'xlsx');

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((file) => file.name).toSet();
      expect(names, contains('xl/workbook.xml'));
      expect(names, isNot(contains('docProps/app.xml')));
      expect(names, isNot(contains('docProps/custom.xml')));
    });

    test('removes a conventional override without root relationships', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypesWithCoreProperties,
        'docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);
      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final manifest = String.fromCharCodes(
        archive.findFile('[Content_Types].xml')!.content as List<int>,
      );
      expect(archive.findFile('docProps/core.xml'), isNull);
      expect(manifest, isNot(contains('/docProps/core.xml')));
    });

    test('returns the original bytes when there are no docProps entries', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _xlsxContentTypes,
        'xl/workbook.xml': '<workbook/>',
        'xl/worksheets/sheet1.xml': '<sheet/>',
      });

      final result = stripOpenXml(bytes, extension: 'xlsx');

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException for bytes that are not a zip', () {
      final bytes = Uint8List.fromList('definitely not a docx'.codeUnits);

      expect(() => stripOpenXml(bytes), throwsFormatException);
    });

    test('rejects a package for the wrong Office extension', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        'word/document.xml': '<document/>',
      });

      expect(
        () => stripOpenXml(bytes, extension: 'xlsx'),
        throwsFormatException,
      );
    });
    test('rejects a manifest without a matching main-part override', () {
      final bytes = _officeZip({
        '[Content_Types].xml':
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
        'word/document.xml': '<document/>',
      });

      expect(() => stripOpenXml(bytes), throwsFormatException);
    });

    test('rejects a manifest whose content type is for another format', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _xlsxContentTypes,
        'word/document.xml': '<document/>',
      });

      expect(() => stripOpenXml(bytes), throwsFormatException);
    });

    test('accepts a Strict OOXML DOCX content type', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _strictDocxContentTypes,
        'docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      expect(() => stripOpenXml(bytes), returnsNormally);
    });

    test('removes relationship-designated property parts and declarations', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypesWithPrivateProperties,
        '_rels/.rels': _privatePropertyRelationships,
        'properties/private.xml': '<coreProperties/>',
        'docProps/core.xml': '<decoy/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);
      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((entry) => entry.name).toSet();
      expect(names, isNot(contains('properties/private.xml')));
      expect(names, isNot(contains('docProps/core.xml')));
      final relationships = String.fromCharCodes(
        archive.findFile('_rels/.rels')!.content as List<int>,
      );
      final manifest = String.fromCharCodes(
        archive.findFile('[Content_Types].xml')!.content as List<int>,
      );
      expect(relationships, isNot(contains('private.xml')));
      expect(manifest, isNot(contains('private.xml')));
    });

    test('rejects an external property relationship', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        '_rels/.rels': _privatePropertyRelationships.replaceFirst(
          'Target="properties/private.xml"',
          'Target="https://example.test/private.xml" TargetMode="External"',
        ),
        'word/document.xml': '<document/>',
      });

      expect(() => stripOpenXml(bytes), throwsFormatException);
    });

    test('rejects duplicate property relationship types', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypesWithPrivateProperties,
        '_rels/.rels': _privatePropertyRelationships.replaceFirst(
          '</Relationships>',
          '<Relationship Id="rId2" Type="$_coreRelationshipType" '
              'Target="properties/other.xml"/></Relationships>',
        ),
        'properties/private.xml': '<coreProperties/>',
        'properties/other.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      expect(() => stripOpenXml(bytes), throwsFormatException);
    });

    test('selectively removes one core property and preserves content', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypesWithCoreProperties,
        'docProps/core.xml': _coreXml,
        'word/document.xml': '<document>payload</document>',
      });
      final result = stripOpenXmlSelective(
        bytes,
        extension: 'docx',
        selectedIds: const {MetadataFieldId.openXmlAuthor},
      );
      final archive = ZipDecoder().decodeBytes(result.bytes, verify: false);
      final core = String.fromCharCodes(
        archive.findFile('docProps/core.xml')!.content as List<int>,
      );
      expect(core, isNot(contains('Jane')));
      expect(core, contains('Keep me'));
      expect(result.removedIds, {MetadataFieldId.openXmlAuthor});
      expect(result.absentIds, isEmpty);
      expect(
        String.fromCharCodes(
          archive.findFile('word/document.xml')!.content as List<int>,
        ),
        '<document>payload</document>',
      );
    });

    test('rejects a prefix-only Open XML ID', () {
      expect(
        () => MetadataFieldId.parse('openxml.core.notAllowlisted'),
        throwsFormatException,
      );
    });

    test('reports an absent allowlisted property without full cleanup', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypesWithCoreProperties,
        'docProps/core.xml': _coreXml,
        'word/document.xml': '<document/>',
      });
      final result = stripOpenXmlSelective(
        bytes,
        extension: 'docx',
        selectedIds: const {MetadataFieldId.openXmlApplication},
      );
      expect(result.removedIds, isEmpty);
      expect(result.absentIds, {MetadataFieldId.openXmlApplication});
    });

    test('uses the same non-root suffix path as full cleanup', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypesWithPrivateProperties,
        '_rels/.rels': _privatePropertyRelationships,
        'properties/private.xml': _coreXml,
        'word/document.xml': '<document/>',
      });
      final result = stripOpenXmlSelective(
        bytes,
        extension: 'docx',
        selectedIds: const {MetadataFieldId.openXmlAuthor},
      );
      expect(result.removedIds, {MetadataFieldId.openXmlAuthor});
      final archive = ZipDecoder().decodeBytes(result.bytes, verify: false);
      expect(
          String.fromCharCodes(
            archive.findFile('properties/private.xml')!.content as List<int>,
          ),
          isNot(contains('Jane')));
    });

    for (final format in const {
      'docx': ('word/document.xml', _docxContentTypes),
      'xlsx': ('xl/workbook.xml', _xlsxContentTypes),
      'pptx': ('ppt/presentation.xml', _pptxContentTypes),
    }.entries) {
      test('${format.key} removes allowlisted core and app properties', () {
        final bytes = _officeZip({
          '[Content_Types].xml': format.value.$2,
          'docProps/core.xml': _coreXml,
          'docProps/app.xml': _appXml,
          format.value.$1: '<main>payload</main>',
        });
        final result = stripOpenXmlSelective(
          bytes,
          extension: format.key,
          selectedIds: const {
            MetadataFieldId.openXmlAuthor,
            MetadataFieldId.openXmlCompany,
          },
        );
        final archive = ZipDecoder().decodeBytes(result.bytes, verify: false);
        expect(result.removedIds, {
          MetadataFieldId.openXmlAuthor,
          MetadataFieldId.openXmlCompany,
        });
        expect(
          String.fromCharCodes(
            archive.findFile('docProps/core.xml')!.content as List<int>,
          ),
          allOf(isNot(contains('Jane')), contains('Keep me')),
        );
        expect(
          String.fromCharCodes(
            archive.findFile('docProps/app.xml')!.content as List<int>,
          ),
          allOf(isNot(contains('Acme')), contains('MetaStrip Tests')),
        );
      });
    }

    test('rejects ambiguous conventional suffix property parts', () {
      final bytes = _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        'one/docProps/core.xml': _coreXml,
        'two/docProps/core.xml': _coreXml,
        'word/document.xml': '<document/>',
      });
      expect(
        () => stripOpenXmlSelective(
          bytes,
          extension: 'docx',
          selectedIds: const {MetadataFieldId.openXmlAuthor},
        ),
        throwsFormatException,
      );
    });
  });
}

const _coreXml = '<cp:coreProperties '
    'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    '<dc:creator>Jane</dc:creator><dc:title>Keep me</dc:title>'
    '</cp:coreProperties>';

const _appXml = '<Properties '
    'xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
    '<Company>Acme</Company><Application>MetaStrip Tests</Application>'
    '</Properties>';

const _docxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '</Types>';

const _xlsxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/xl/workbook.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '</Types>';

const _pptxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/ppt/presentation.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
    '</Types>';

const _strictDocxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.ms-word.document.main+xml"/>'
    '</Types>';

const _coreRelationshipType =
    'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties';

const _privatePropertyRelationships =
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="$_coreRelationshipType" '
    'Target="properties/private.xml"/>'
    '</Relationships>';

const _docxContentTypesWithPrivateProperties =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/properties/private.xml" '
    'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '</Types>';

const _docxContentTypesWithCoreProperties =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/docProps/core.xml" '
    'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '</Types>';

Uint8List _officeZip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    archive.addFile(ArchiveFile.string(name, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
