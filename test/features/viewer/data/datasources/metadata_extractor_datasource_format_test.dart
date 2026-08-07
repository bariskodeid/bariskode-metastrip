import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/format_registry.dart';
import 'package:metastrip/features/viewer/data/datasources/metadata_extractor_datasource.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_entity.dart';

void main() {
  group('MetadataExtractorDatasource format routing', () {
    test('routes mp3 files to the ID3 extractor via the registry', () async {
      final file = await _tempFile(
        'sample.mp3',
        _id3v2File(
          version: 3,
          frames: [_frame23('TIT2', _textFrame(0, latin1.encode('My Song')))],
        ),
      );

      final metadata = await _extract(file, 'mp3');

      final title = metadata.fields.singleWhere(
        (field) => field.section == 'Audio ID3' && field.label == 'Title',
      );
      expect(title.value, 'My Song');
    });

    test('reads only a bounded prefix plus tail for large mp3 files',
        () async {
      final id3v1 = List<int>.filled(128, 0);
      id3v1.setRange(0, 3, 'TAG'.codeUnits);
      id3v1.setRange(3, 3 + 10, latin1.encode('Tail Title'));

      final tag = _id3v2File(
        version: 3,
        frames: [
          _frame23('TIT2', _textFrame(0, latin1.encode('Front Title'))),
        ],
      );
      // Filler pushes the file past the 1MB bounded read prefix; the ID3v1
      // tag only survives because the facade appends the trailing 128 bytes.
      final filler = Uint8List(AppConstants.maxAudioScanBytes - tag.length);
      final file = await _tempFile(
        'large.mp3',
        Uint8List.fromList([...tag, ...filler, ...id3v1]),
      );

      final metadata = await _extract(file, 'mp3');

      final titles = metadata.fields
          .where(
            (field) => field.section == 'Audio ID3' && field.label == 'Title',
          )
          .map((field) => field.value)
          .toList();
      expect(titles, contains('Front Title'));
      expect(titles, contains('Tail Title'));
    });

    test('routes pdf files to the PDF extractor via the registry', () async {
      final file = await _tempFile(
        'sample.pdf',
        _pdfBytes([
          '1 0 obj',
          '<< /Info 7 0 R >>',
          'endobj',
          '7 0 obj',
          '<< /Title (Hello World) /Author (Jane Doe) >>',
          'endobj',
        ]),
      );

      final metadata = await _extract(file, 'pdf');

      final title = metadata.fields.singleWhere(
        (field) => field.section == 'PDF Document' && field.label == 'Title',
      );
      expect(title.value, 'Hello World');
      final author = metadata.fields.singleWhere(
        (field) => field.section == 'PDF Document' && field.label == 'Author',
      );
      expect(author.value, 'Jane Doe');
      expect(author.isPrivacySensitive, isTrue);
    });

    test('routes docx files to the OpenXML extractor via the registry',
        () async {
      final file = await _tempFile(
        'sample.docx',
        _zipBytes([
          ArchiveFile.string(
            'docProps/core.xml',
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<cp:coreProperties '
            'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata'
            '/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">'
            '<dc:title>Quarterly Report</dc:title>'
            '<dc:creator>Ada Lovelace</dc:creator>'
            '</cp:coreProperties>',
          ),
        ]),
      );

      final metadata = await _extract(file, 'docx');

      final title = metadata.fields.singleWhere(
        (field) =>
            field.section == 'Office Document' && field.label == 'Title',
      );
      expect(title.value, 'Quarterly Report');
      final author = metadata.fields.singleWhere(
        (field) =>
            field.section == 'Office Document' && field.label == 'Author',
      );
      expect(author.value, 'Ada Lovelace');
      expect(author.isPrivacySensitive, isTrue);
    });

    test('routes zip archives to the zip extractor via the registry',
        () async {
      final file = await _tempFile(
        'sample.zip',
        _zipBytes([ArchiveFile.string('readme.txt', 'hello archive')]),
      );

      final metadata = await _extract(file, 'zip');

      final entries = metadata.fields.singleWhere(
        (field) => field.section == 'Archive' && field.label == 'Entries',
      );
      expect(entries.value, '1');
    });

    test('routes wav files to the RIFF extractor via the registry', () async {
      final file = await _tempFile(
        'sample.wav',
        _wavWithInfoList(title: 'Wave Title'),
      );

      final metadata = await _extract(file, 'wav');

      final title = metadata.fields.singleWhere(
        (field) => field.section == 'Audio RIFF' && field.label == 'Title',
      );
      expect(title.value, 'Wave Title');
    });

    test('routes flac files to the Vorbis extractor via the registry',
        () async {
      final file = await _tempFile('sample.flac', _flacWithComment());

      final metadata = await _extract(file, 'flac');

      final title = metadata.fields.singleWhere(
        (field) => field.section == 'Audio Vorbis' && field.label == 'Title',
      );
      expect(title.value, 'Flac Title');
    });

    test('leaves unsupported extensions filesystem-only', () async {
      final file = await _tempFile('video.mp4', Uint8List.fromList([1, 2, 3]));
      final metadata = await _extract(file, 'mp4');

      expect(
        metadata.fields.any(
          (field) => field.section.startsWith('Audio') ||
              field.section.contains('EXIF') ||
              field.section.contains('Document') ||
              field.section == 'Archive',
        ),
        isFalse,
      );
      expect(metadata.fields.first.section, 'File');
    });

    test('registry exposes supported extensions and stable specs', () {
      for (final extension in [
        'jpg', 'jpeg', 'tif', 'tiff', 'png', 'gif', 'webp', 'bmp',
        'mp3', 'flac', 'ogg', 'opus', 'wav', 'aiff', 'pdf',
        'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp', 'zip', 'apk', 'epub',
      ]) {
        expect(formatSpecFor(extension), isNotNull, reason: extension);
      }
      expect(formatSpecFor('MP3'), isNotNull);
      expect(formatSpecFor('txt'), isNull);
      expect(formatSpecFor('mp4'), isNull);
      expect(formatSpecFor('heic'), isNull);
      expect(formatSpecFor('rtf'), isNull);
      expect(supportedExtractionExtensions, contains('pdf'));
    });
  });
}

Future<MetadataEntity> _extract(File file, String extension) async {
  return MetadataExtractorDatasource().extractBasic(
    FileItemEntity(
      path: file.path,
      name: file.uri.pathSegments.last,
      extension: extension,
      sizeBytes: await file.length(),
      addedAt: DateTime.now(),
    ),
  );
}

Future<File> _tempFile(String name, Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('metastrip_fmt_');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes);
  return file;
}

/// Builds a minimal ID3v2 file with [frames] and a synchsafe header size.
Uint8List _id3v2File({
  required int version,
  required List<Uint8List> frames,
}) {
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('ID3'));
  builder.addByte(version);
  builder.addByte(0); // revision
  builder.addByte(0); // flags
  final total = frames.fold<int>(0, (sum, frame) => sum + frame.length);
  builder.add(_synchsafe(total));
  for (final frame in frames) {
    builder.add(frame);
  }
  return builder.takeBytes();
}

/// Builds an ID3v2.3 frame: id (4), size (4 BE), flags (2), data.
Uint8List _frame23(String id, Uint8List data) {
  return Uint8List.fromList([
    ...latin1.encode(id),
    ..._be32(data.length),
    0x00,
    0x00,
    ...data,
  ]);
}

/// Builds a text frame payload: encoding byte followed by [text].
Uint8List _textFrame(int encoding, List<int> text) {
  return Uint8List.fromList([encoding, ...text]);
}

/// Encodes [value] as a four-byte big-endian integer.
Uint8List _be32(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

/// Encodes [value] as a four-byte synchsafe integer (7 bits per byte).
Uint8List _synchsafe(int value) {
  return Uint8List.fromList([
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ]);
}

/// Builds a minimal, valid-looking PDF byte buffer from [objects].
Uint8List _pdfBytes(List<String> objects) {
  final content = StringBuffer()..writeln('%PDF-1.4');
  for (final object in objects) {
    content.writeln(object);
  }
  content.writeln('trailer');
  content.writeln('<< /Root 1 0 R /Size ${objects.length + 1} >>');
  content.writeln('%%EOF');
  return Uint8List.fromList(latin1.encode(content.toString()));
}

/// Builds a zip byte buffer from [files] using the archive package.
Uint8List _zipBytes(List<ArchiveFile> files) {
  final archive = Archive();
  for (final file in files) {
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Builds a WAV byte buffer with a `LIST INFO` title chunk.
Uint8List _wavWithInfoList({required String title}) {
  final infoBody = <int>[
    ...'INFO'.codeUnits,
    ...'INAM'.codeUnits,
    ..._le32(title.length),
    ...latin1.encode(title),
  ];
  if (infoBody.length.isOdd) infoBody.add(0);
  final riffSize = 12 + infoBody.length;
  return Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._le32(riffSize),
    ...'WAVE'.codeUnits,
    ...'LIST'.codeUnits,
    ..._le32(infoBody.length),
    ...infoBody,
  ]);
}

/// Encodes [value] as a four-byte little-endian integer.
Uint8List _le32(int value) {
  return Uint8List.fromList([
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}

/// Builds a FLAC byte buffer with a VORBIS_COMMENT block.
Uint8List _flacWithComment() {
  final comment = _vorbisCommentBlock(['TITLE=Flac Title', 'ARTIST=Flac Band']);
  final body = <int>[
    0x84, // last metadata block, type 4 (VORBIS_COMMENT)
    (comment.length >> 16) & 0xFF,
    (comment.length >> 8) & 0xFF,
    comment.length & 0xFF,
    ...comment,
  ];
  return Uint8List.fromList([...'fLaC'.codeUnits, ...body]);
}

/// Builds a VORBIS_COMMENT block body from [entries] (`KEY=VALUE`).
Uint8List _vorbisCommentBlock(List<String> entries) {
  final builder = BytesBuilder(copy: false);
  builder.add(_le32(0)); // vendor length
  builder.add(_le32(entries.length));
  for (final entry in entries) {
    final encoded = utf8.encode(entry);
    builder.add(_le32(encoded.length));
    builder.add(encoded);
  }
  return builder.takeBytes();
}
