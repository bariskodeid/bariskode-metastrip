import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/openxml_stripper.dart';

void main() {
  group('stripOpenXml', () {
    test('removes docProps entries and keeps document content', () {
      final bytes = _officeZip({
        '[Content_Types].xml': '<Types/>',
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
        './docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<document/>',
      });

      final result = stripOpenXml(bytes);

      final archive = ZipDecoder().decodeBytes(result, verify: false);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('word/document.xml'));
      expect(names, isNot(contains('./docProps/core.xml')));
    });

    test('removes core.xml stored at a non-root location', () {
      final bytes = _officeZip({
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

    test('returns the original bytes when there is no docProps/core.xml', () {
      final bytes = _officeZip({
        'xl/workbook.xml': '<workbook/>',
        'xl/worksheets/sheet1.xml': '<sheet/>',
      });

      final result = stripOpenXml(bytes);

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException for bytes that are not a zip', () {
      final bytes = Uint8List.fromList('definitely not a docx'.codeUnits);

      expect(() => stripOpenXml(bytes), throwsFormatException);
    });
  });
}

Uint8List _officeZip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    archive.addFile(ArchiveFile.string(name, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
