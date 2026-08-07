import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/bmp_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/gif_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/webp_extractor.dart';

void main() {
  group('extractGif', () {
    test('extracts a comment extension from a GIF89a file', () async {
      final bytes = _gifBytes([_gifComment('Sample GIF comment')]);

      final fields = await extractGif(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'GIF Text');
      expect(fields.single.label, 'Comment');
      expect(fields.single.value, 'Sample GIF comment');
    });

    test('flags GIF comments as privacy sensitive', () async {
      final bytes = _gifBytes([_gifComment('Shot on Pixel 8')]);

      final fields = await extractGif(bytes);

      expect(fields.single.isPrivacySensitive, isTrue);
    });

    test('returns a status field when a valid GIF has no comment', () async {
      final bytes = _gifBytes(const []);

      final fields = await extractGif(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'GIF Text');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No GIF metadata found');
    });

    test('returns a status field for non-GIF bytes', () async {
      final bytes = Uint8List.fromList(latin1.encode('NotAGIF at all...'));

      final fields = await extractGif(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Not a valid GIF');
    });
  });

  group('extractWebp', () {
    test('surfaces an EXIF chunk in a WebP file', () async {
      final bytes = _webpBytes([
        _webpChunk('VP8 ', Uint8List.fromList([0x9D, 0x01, 0x2A])),
        _webpChunk('EXIF', Uint8List.fromList(List.filled(12, 0xE1))),
      ]);

      final fields = await extractWebp(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'WebP Metadata');
      expect(fields.single.label, 'EXIF');
      expect(fields.single.value, 'EXIF data present (12 bytes)');
    });

    test('decodes an XMP chunk as XML text', () async {
      const xml = '<x:xmpmeta><rdf:Description><dc:creator>'
          'Jane Doe</dc:creator></rdf:Description></x:xmpmeta>';
      final bytes = _webpBytes([
        _webpChunk('VP8X', Uint8List(10)),
        _webpChunk('XMP ', Uint8List.fromList(latin1.encode(xml))),
      ]);

      final fields = await extractWebp(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'WebP Metadata');
      expect(fields.single.label, 'XMP');
      expect(fields.single.value, contains('dc:creator'));
      expect(fields.single.value, contains('Jane Doe'));
    });

    test('returns a status field when a WebP has no metadata chunks',
        () async {
      final bytes = _webpBytes([
        _webpChunk('VP8 ', Uint8List.fromList([0x9D, 0x01, 0x2A])),
      ]);

      final fields = await extractWebp(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'WebP Metadata');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No WebP metadata found');
    });

    test('returns a status field for an invalid WebP signature', () async {
      final bytes = Uint8List.fromList(
        latin1.encode('RIFF\x04\x00\x00\x00WAVEfm'),
      );

      final fields = await extractWebp(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Not a valid WebP file');
    });
  });

  group('extractBmp', () {
    test('reports that a valid BMP has no metadata container', () async {
      final builder = BytesBuilder(copy: false);
      builder.add(latin1.encode('BM'));
      builder.add(Uint8List(12 + 40)); // file header + BITMAPINFOHEADER

      final fields = await extractBmp(builder.takeBytes());

      expect(fields, hasLength(1));
      expect(fields.single.section, 'BMP');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'BMP has no metadata container');
    });

    test('returns a status field for non-BMP bytes', () async {
      final bytes = Uint8List.fromList(latin1.encode('PN'));

      final fields = await extractBmp(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Not a valid BMP file');
    });
  });
}

/// Builds a GIF with a `GIF89a` header, a 1x1 descriptor (no GCT) and
/// [blocks] (comment extensions / trailer as needed).
Uint8List _gifBytes(List<Uint8List> blocks) {
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('GIF89a'));
  builder.add(Uint8List.fromList([0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]));
  for (final block in blocks) {
    builder.add(block);
  }
  builder.addByte(0x3B); // trailer
  return builder.takeBytes();
}

/// Builds a GIF comment extension (`0x21 0xFE`) holding [comment].
Uint8List _gifComment(String comment) {
  final builder = BytesBuilder(copy: false);
  builder.addByte(0x21);
  builder.addByte(0xFE);
  final data = latin1.encode(comment);
  builder.addByte(data.length);
  builder.add(data);
  builder.addByte(0x00); // sub-block terminator
  return builder.takeBytes();
}

/// Builds a WebP container: `RIFF` + size + `WEBP` + [chunks].
Uint8List _webpBytes(List<Uint8List> chunks) {
  final content = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    content.add(chunk);
  }
  final data = content.takeBytes();
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('RIFF'));
  builder.add(_le32(4 + data.length));
  builder.add(latin1.encode('WEBP'));
  builder.add(data);
  return builder.takeBytes();
}

/// Builds a WebP chunk with [id], LE [size] and [data], padded when odd.
Uint8List _webpChunk(String id, Uint8List data) {
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode(id));
  builder.add(_le32(data.length));
  builder.add(data);
  if (data.length.isOdd) builder.addByte(0);
  return builder.takeBytes();
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
