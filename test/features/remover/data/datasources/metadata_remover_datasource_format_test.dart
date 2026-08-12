import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';

void main() {
  test('stripMetadata strips an ID3v2 tag from an mp3', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_mp3_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}audio.mp3');
    await input.writeAsBytes([
      ...'ID3'.codeUnits,
      0x03,
      0x00, // version 2.3.0
      0x00, // no footer
      ..._synchsafe(4),
      ...List<int>.filled(4, 0xAA), // tag payload
      ...'AUDI'.codeUnits,
    ]);

    final output = await MetadataRemoverDatasource().stripMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(output.path, contains('_clean'));
    expect(String.fromCharCodes(bytes), startsWith('AUDI'));
    expect(String.fromCharCodes(bytes), isNot(contains('ID3')));
  });

  test('stripMetadata repacks a docx without docProps metadata', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_docx_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}report.docx');
    await input.writeAsBytes(
      _officeZip({
        '[Content_Types].xml': _docxContentTypes,
        'docProps/core.xml': '<coreProperties/>',
        'word/document.xml': '<w:document/>',
      }),
    );

    final output = await MetadataRemoverDatasource().stripMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final archive = ZipDecoder().decodeBytes(
      await output.readAsBytes(),
      verify: false,
    );
    final names = archive.files.map((file) => file.name).toSet();

    expect(await output.exists(), isTrue);
    expect(names, contains('[Content_Types].xml'));
    expect(names, contains('word/document.xml'));
    expect(names, isNot(contains('docProps/core.xml')));
  });

  test('stripMetadata drops a GIF comment extension', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_gif_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.gif');
    await input.writeAsBytes(
      _gifFile([
        ...[0x21, 0xFE], // comment extension
        ..._gifSubBlock([...'Private note'.codeUnits]),
        0x00, // terminator
        ..._gifImage(),
      ]),
    );

    final output = await MetadataRemoverDatasource().stripMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(_indexOf(bytes, [0x21, 0xFE]), -1);
    expect(String.fromCharCodes(bytes), isNot(contains('Private note')));
    expect(String.fromCharCodes(bytes.sublist(0, 6)), 'GIF89a');
  });

  test('supportedCleanup removes WAV LIST, ID3, and bext metadata', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_wav_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}audio.wav');
    await input.writeAsBytes(
      _wavFile([
        ('fmt ', List<int>.filled(16, 0x10)),
        ('LIST', [...'INFO'.codeUnits, ...'INAM'.codeUnits]),
        (
          'ID3 ',
          [
            ...'ID3'.codeUnits,
            ...[1, 2, 3]
          ]
        ),
        (
          'bext',
          [
            ...'Broadcast'.codeUnits,
            ...[4, 5, 6]
          ]
        ),
        ('data', List<int>.filled(64, 0x7F)),
      ]),
    );

    final removal = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: dir.path,
      policy: const StripPolicy.supportedCleanup(),
    );
    final output = removal.file;
    final bytes = await output.readAsBytes();

    expect(String.fromCharCodes(bytes), isNot(contains('INFO')));
    expect(String.fromCharCodes(bytes), isNot(contains('ID3')));
    expect(String.fromCharCodes(bytes), isNot(contains('Broadcast')));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(
      _indexOf(bytes, [...'data'.codeUnits]),
      greaterThanOrEqualTo(8),
    );
  });

  test('stripMetadata removes a FLAC Vorbis comment block', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_flac_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}audio.flac');
    await input.writeAsBytes(
      _flacFile(
        blocks: [
          _flacStreamInfoBlock(),
          _flacCommentBlock(
            vendor: 'libFLAC',
            comments: const ['TITLE=Secret'],
          ),
        ],
        audio: List<int>.filled(100, 0xAB),
      ),
    );

    final output = await MetadataRemoverDatasource().stripMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'fLaC');
    expect(_flacBlockTypes(bytes), isNot(contains(4)));
    expect(String.fromCharCodes(bytes), isNot(contains('TITLE=Secret')));
    expect(bytes.sublist(bytes.length - 100), List<int>.filled(100, 0xAB));
  });

  test('stripMetadata keeps TIFF removal disabled and installs no output',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_tiff_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.tiff');
    await input.writeAsBytes([0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00]);

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(dir.listSync().map((entity) => entity.path), [input.path]);
  });

  test('stripMetadata cleans a valid zip and preserves the original', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_zip_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}archive.zip');
    final originalBytes = _officeZip({
      'readme.txt': 'archive contents',
      'nested/data.bin': 'preserved payload',
    });
    await input.writeAsBytes(originalBytes);

    final output = await MetadataRemoverDatasource().stripMetadata(
      input.path,
      outputDirectory: dir.path,
    );

    expect(await input.readAsBytes(), originalBytes,
        reason: 'ZIP cleanup must not mutate the original');
    expect(await output.exists(), isTrue);
    expect(output.path, endsWith('archive_clean.zip'));

    final outputBytes = await output.readAsBytes();
    expect(rewriteZipMetadata(outputBytes), outputBytes,
        reason: 'The clean ZIP should already have canonical metadata');

    final archive = ZipDecoder().decodeBytes(outputBytes, verify: true);
    expect(archive.files.map((file) => file.name), {
      'readme.txt',
      'nested/data.bin',
    });
    expect(
      String.fromCharCodes(
        archive.files.singleWhere((file) => file.name == 'readme.txt').content,
      ),
      'archive contents',
    );
  });

  test('ZIP cleanup canonicalizes reversed central order to local order', () {
    final source =
        _officeZip({'first.txt': 'payload one', 'second.txt': 'payload two'});
    final reversed = _reverseCentralDirectory(source);
    expect(_centralNames(reversed), ['second.txt', 'first.txt']);

    final output = rewriteZipMetadata(reversed);
    expect(_centralNames(output), ['first.txt', 'second.txt']);
    final archive = ZipDecoder().decodeBytes(output, verify: true);
    expect(
      archive.files
          .map((file) => '${file.name}:${String.fromCharCodes(file.content)}'),
      ['first.txt:payload one', 'second.txt:payload two'],
    );
  });

  test('ZIP substitution with matching size and mtime is not deleted',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_zip_sub_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}archive.zip');
    await input.writeAsBytes(_officeZip({'a.txt': 'one'}));
    final substitute = rewriteZipMetadata(_officeZip({'b.txt': 'two'}));
    final datasource = MetadataRemoverDatasource(
      persistedOutputReader: (output) async {
        final installed = await output.stat();
        await output.writeAsBytes(substitute, flush: true);
        await output.setLastModified(installed.modified);
        return substitute;
      },
    );

    await expectLater(
      datasource.stripMetadata(input.path, outputDirectory: dir.path),
      throwsA(isA<FormatException>()),
    );
    expect(
      await File('${dir.path}${Platform.pathSeparator}archive_clean.zip')
          .readAsBytes(),
      substitute,
    );
  });

  test('rejects a canonical persisted ZIP that differs from generated bytes',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_zip_read_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}archive.zip');
    await input.writeAsBytes(_officeZip({'a.txt': 'one'}));
    final canonicalSubstitute = rewriteZipMetadata(
      _officeZip({'b.txt': 'two'}),
    );
    final datasource = MetadataRemoverDatasource(
      persistedOutputReader: (_) async => canonicalSubstitute,
    );

    await expectLater(
      datasource.stripMetadata(input.path, outputDirectory: dir.path),
      throwsA(isA<FormatException>()),
    );
    expect(
      await File(
        '${dir.path}${Platform.pathSeparator}archive_clean.zip',
      ).exists(),
      isTrue,
    );
  });

  test('APK cleanup rewrites container metadata and warns about installability',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_apk_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}app.apk');
    await input.writeAsBytes(_officeZip({
      'AndroidManifest.xml': '<manifest/>',
      'classes.dex': 'dex',
    }));

    final removal = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: dir.path,
      policy: const StripPolicy.supportedCleanup(),
    );
    final output = removal.file;
    final bytes = await output.readAsBytes();

    expect(output.path, endsWith('app_clean.apk'));
    expect(rewriteZipMetadata(bytes), bytes);
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    expect(archive.files.map((file) => file.name), {
      'AndroidManifest.xml',
      'classes.dex',
    });
    expect(
      removal.report.warnings,
      contains(
        'APK signing is invalidated; output is not installable.',
      ),
    );
    expect(removal.report.verificationOutcome,
        StripVerificationOutcome.verified);
  });

  test('EPUB cleanup preserves the required mimetype entry', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_epub_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}book.epub');
    await input.writeAsBytes(
      _epubZip({
        'mimetype': 'application/epub+zip',
        'OEBPS/content.opf': '<package/>',
      }),
    );

    final removal = await MetadataRemoverDatasource().stripMetadataWithPolicy(
      input.path,
      outputDirectory: dir.path,
      policy: const StripPolicy.supportedCleanup(),
    );
    final output = removal.file;
    final bytes = await output.readAsBytes();

    expect(output.path, endsWith('book_clean.epub'));
    expect(rewriteZipMetadata(bytes), bytes);
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    expect(archive.files.map((file) => file.name), {
      'mimetype',
      'OEBPS/content.opf',
    });
    final mimetypeBytes = archive
        .files
        .singleWhere((file) => file.name == 'mimetype')
        .content as List<int>;
    expect(String.fromCharCodes(mimetypeBytes), 'application/epub+zip');
    expect(
      removal.report.warnings,
      contains('EPUB mimetype was preserved; container metadata was cleaned.'),
    );
    expect(removal.report.verificationOutcome,
        StripVerificationOutcome.verified);
  });

  test('EPUB cleanup rejects archives missing the required mimetype entry',
      () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_epub_no_mt_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}book.epub');
    await input.writeAsBytes(
      _epubZip({
        'OEBPS/content.opf': '<package/>',
      }),
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: dir.path,
        policy: const StripPolicy.supportedCleanup(),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('EPUB cleanup rejects archives with non-epub mimetype content', () async {
    final dir =
        await Directory.systemTemp.createTemp('metastrip_epub_bad_mt_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}book.epub');
    await input.writeAsBytes(
      _epubZip({
        'mimetype': 'application/zip',
        'OEBPS/content.opf': '<package/>',
      }),
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadataWithPolicy(
        input.path,
        outputDirectory: dir.path,
        policy: const StripPolicy.supportedCleanup(),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Uint8List _epubZip(Map<String, String> files) {
  final archive = Archive();
  final ordered = <String, String>{};
  if (files.containsKey('mimetype')) {
    ordered['mimetype'] = files['mimetype']!;
  }
  ordered.addAll(files);
  for (final entry in ordered.entries) {
    final file = ArchiveFile(
      entry.key,
      entry.value.length,
      entry.value.codeUnits,
    );
    if (entry.key == 'mimetype') {
      file.compress = false;
    }
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Uint8List _officeZip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    archive.addFile(ArchiveFile.string(name, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Uint8List _reverseCentralDirectory(Uint8List bytes) {
  final eocd = _findSignature(bytes, 0x06054b50);
  final directory = _u32(bytes, eocd + 16);
  final firstLength = _centralLength(bytes, directory);
  final second = directory + firstLength;
  final secondLength = _centralLength(bytes, second);
  final reordered = <int>[...bytes.sublist(0, directory)];
  reordered.addAll(bytes.sublist(second, second + secondLength));
  reordered.addAll(bytes.sublist(directory, directory + firstLength));
  reordered.addAll(bytes.sublist(directory + firstLength + secondLength));
  return Uint8List.fromList(reordered);
}

List<String> _centralNames(Uint8List bytes) {
  final eocd = _findSignature(bytes, 0x06054b50);
  var cursor = _u32(bytes, eocd + 16);
  final names = <String>[];
  while (_u32(bytes, cursor) == 0x02014b50) {
    final nameLength = _u16(bytes, cursor + 28);
    final extraLength = _u16(bytes, cursor + 30);
    final commentLength = _u16(bytes, cursor + 32);
    names.add(String.fromCharCodes(
        bytes.sublist(cursor + 46, cursor + 46 + nameLength)));
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  return names;
}

int _centralLength(Uint8List bytes, int offset) =>
    46 +
    _u16(bytes, offset + 28) +
    _u16(bytes, offset + 30) +
    _u16(bytes, offset + 32);

int _findSignature(Uint8List bytes, int signature) {
  for (var offset = bytes.length - 4; offset >= 0; offset--) {
    if (_u32(bytes, offset) == signature) return offset;
  }
  throw StateError('signature not found');
}

int _u16(Uint8List bytes, int offset) => bytes[offset] | bytes[offset + 1] << 8;

int _u32(Uint8List bytes, int offset) =>
    bytes[offset] |
    bytes[offset + 1] << 8 |
    bytes[offset + 2] << 16 |
    bytes[offset + 3] << 24;

const _docxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '</Types>';

Uint8List _flacFile({
  required List<List<int>> blocks,
  List<int> audio = const [],
}) {
  return Uint8List.fromList([
    ...'fLaC'.codeUnits,
    ...blocks.expand((block) => block),
    ...audio,
  ]);
}

List<int> _flacBlock({
  required int type,
  required bool isLast,
  required List<int> payload,
}) {
  return [
    (isLast ? 0x80 : 0) | (type & 0x7F),
    (payload.length >> 16) & 0xFF,
    (payload.length >> 8) & 0xFF,
    payload.length & 0xFF,
    ...payload,
  ];
}

List<int> _flacStreamInfoBlock() {
  return _flacBlock(
    type: 0,
    isLast: false,
    payload: List<int>.filled(34, 0x11),
  );
}

List<int> _flacCommentBlock({
  required String vendor,
  List<String> comments = const [],
  bool isLast = true,
}) {
  return _flacBlock(
    type: 4,
    isLast: isLast,
    payload: _vorbisCommentPayload(vendor: vendor, comments: comments),
  );
}

List<int> _vorbisCommentPayload({
  required String vendor,
  List<String> comments = const [],
}) {
  final vendorBytes = vendor.codeUnits;
  final payload = <int>[
    ..._le32(vendorBytes.length),
    ...vendorBytes,
    ..._le32(comments.length),
  ];
  for (final comment in comments) {
    final entry = comment.codeUnits;
    payload.addAll(_le32(entry.length));
    payload.addAll(entry);
  }
  return payload;
}

/// Returns the FLAC metadata block types present in [bytes].
List<int> _flacBlockTypes(Uint8List bytes) {
  final types = <int>[];
  var offset = 4;
  while (offset + 4 <= bytes.length) {
    final flags = bytes[offset];
    final size = (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    types.add(flags & 0x7F);
    if (flags & 0x80 != 0) break;
    offset += 4 + size;
  }
  return types;
}

/// Builds a minimal GIF89a: header + descriptor + [blocks] + trailer.
Uint8List _gifFile(List<int> blocks) {
  return Uint8List.fromList([
    ...'GIF89a'.codeUnits,
    0x01,
    0x00, // width 1
    0x01,
    0x00, // height 1
    0x00, // packed: no global color table
    0x00, // background index
    0x00, // aspect ratio
    ...blocks,
    0x3B,
  ]);
}

List<int> _gifSubBlock(List<int> data) => [data.length, ...data];

/// Builds a 1x1 image descriptor with a local LZW sub-block stream.
List<int> _gifImage() {
  return [
    0x2C, // image descriptor introducer
    0x00, 0x00, 0x00, 0x00, // left, top
    0x01, 0x00, 0x01, 0x00, // width, height
    0x00, // packed: no local color table
    0x02, // LZW minimum code size
    ..._gifSubBlock([0x01, 0x02, 0x03, 0x04]),
    0x00,
  ];
}

/// Builds a WAV file from [chunks]: 'RIFF' + little-endian size + 'WAVE' +
/// each chunk as id + little-endian size + payload + pad byte for odd sizes.
Uint8List _wavFile(List<(String, List<int>)> chunks) {
  final body = <int>[
    ...'WAVE'.codeUnits,
    ...chunks.expand((chunk) => _wavChunk(chunk)),
  ];
  return Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._le32(body.length),
    ...body,
  ]);
}

/// Serializes one WAV chunk: id + little-endian size + payload + odd pad.
List<int> _wavChunk((String, List<int>) chunk) {
  final (id, data) = chunk;
  return [
    ...id.codeUnits,
    ..._le32(data.length),
    ...data,
    if (data.length.isOdd) 0x00,
  ];
}

List<int> _synchsafe(int value) {
  return [
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ];
}

List<int> _le32(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

/// Returns the first index of [needle] inside [haystack], or -1.
int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}
