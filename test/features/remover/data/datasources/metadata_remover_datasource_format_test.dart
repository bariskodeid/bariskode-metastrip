import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';

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
        '[Content_Types].xml': '<Types/>',
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

  test('stripMetadata removes a WAV LIST INFO chunk', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_wav_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}audio.wav');
    await input.writeAsBytes(
      _wavFile([
        ('fmt ', List<int>.filled(16, 0x10)),
        ('LIST', [...'INFO'.codeUnits, ...'INAM'.codeUnits]),
        ('data', List<int>.filled(64, 0x7F)),
      ]),
    );

    final output = await MetadataRemoverDatasource().stripMetadata(
      input.path,
      outputDirectory: dir.path,
    );
    final bytes = await output.readAsBytes();

    expect(String.fromCharCodes(bytes), isNot(contains('INFO')));
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

  test('stripMetadata rejects an unsupported bmp extension', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_bmp_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}image.bmp');
    await input.writeAsBytes([0x42, 0x4D, 0x00, 0x00]);

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('stripMetadata rejects an unsupported zip extension', () async {
    final dir = await Directory.systemTemp.createTemp('metastrip_zip_test_');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}${Platform.pathSeparator}archive.zip');
    await input.writeAsBytes(
      _officeZip({'readme.txt': 'not a strippable archive'}),
    );

    await expectLater(
      MetadataRemoverDatasource().stripMetadata(
        input.path,
        outputDirectory: dir.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}

Uint8List _officeZip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    archive.addFile(ArchiveFile.string(name, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

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