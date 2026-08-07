import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/zip_extractor.dart';

void main() {
  group('extractZip', () {
    test('reports entry count and summed sizes for files and dirs', () async {
      final bytes = _zipBytes([
        ArchiveFile.noCompress(
          'hello.txt',
          11,
          utf8.encode('hello world'),
        ),
        ArchiveFile.noCompress('folder/', 0, Uint8List(0)),
      ]);

      final fields = await extractZip(bytes, extension: 'zip');
      final byLabel = {for (final field in fields) field.label: field};

      final entries = byLabel['Entries'];
      expect(entries, isNotNull);
      expect(entries!.section, 'Archive');
      expect(entries.value, '2');

      expect(byLabel['Compressed Size']?.value, '11 B');
      expect(byLabel['Uncompressed Size']?.value, '11 B');
      expect(byLabel.containsKey('Entries Truncated'), isFalse);
    });

    test('extracts package attributes from an APK manifest', () async {
      final bytes = _zipBytes([
        ArchiveFile.string(
          'AndroidManifest.xml',
          '<manifest xmlns="http://schemas.android.com/apk/res/android" '
              'package="com.example.app" '
              'versionCode="2" versionName="1.0.0"></manifest>',
        ),
      ]);

      final fields = await extractZip(bytes, extension: 'apk');
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Entries']?.value, '1');
      expect(byLabel['Package Name']?.value, 'com.example.app');
      expect(byLabel['Package Name']?.section, 'APK Manifest');
      expect(byLabel['Version Code']?.value, '2');
      expect(byLabel['Version Name']?.value, '1.0.0');
    });

    test('returns a status field for bytes that are not a zip', () async {
      final bytes = Uint8List.fromList(utf8.encode('not a zip file'));

      final fields = await extractZip(bytes, extension: 'epub');

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Archive');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Invalid archive');
    });

    test('reports an oversized declared APK manifest without decompressing it',
        () async {
      final manifest = ArchiveFile.string(
        'AndroidManifest.xml',
        '<manifest package="com.example.app"></manifest>',
      )..size = 70 * 1024 * 1024; // declared above the 64MB per-entry cap
      final bytes = _zipBytes([manifest]);

      final fields = await extractZip(bytes, extension: 'apk');
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Entries']?.value, '1');
      expect(byLabel.containsKey('Package Name'), isFalse);
      expect(byLabel['Status']?.value, 'Manifest is too large to read safely');
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
