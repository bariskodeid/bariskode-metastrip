import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/vorbis_extractor.dart';

void main() {
  group('extractVorbis', () {
    test('extracts VORBIS_COMMENT fields from a FLAC file', () async {
      final bytes = _flacWithComment([
        'TITLE=Midnight Walk',
        'ARTIST=Neon Harbor',
        'GENRE=Synthwave',
        'CUSTOM=hello',
      ]);

      final fields = await extractVorbis(bytes, extension: 'flac');
      final byLabel = {for (final field in fields) field.label: field};

      expect(fields, hasLength(4));
      expect(byLabel['Title']?.section, 'Audio Vorbis');
      expect(byLabel['Title']?.value, 'Midnight Walk');
      expect(byLabel['Artist']?.value, 'Neon Harbor');
      expect(byLabel['Genre']?.value, 'Synthwave');
      expect(byLabel['CUSTOM']?.value, 'hello');
    });

    test('extracts comments from a minimal Ogg Vorbis page', () async {
      final payload = _commentPayload([
        'TITLE=Open Road',
        'ARTIST=Far North',
      ]);
      final ident = Uint8List.fromList([0x01, ...latin1.encode('vorbis')]);
      final comment = Uint8List.fromList([0x03, ...latin1.encode('vorbis')]);
      final bytes = _oggVorbisPage(ident, _concat(comment, payload));

      final fields = await extractVorbis(bytes, extension: 'ogg');
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Title']?.value, 'Open Road');
      expect(byLabel['Artist']?.value, 'Far North');
    });

    test('returns a status field when a valid container has no comments',
        () async {
      final bytes = _flacWithoutComment();

      final fields = await extractVorbis(bytes, extension: 'flac');

      expect(fields, hasLength(1));
      expect(fields.single.section, 'Audio Vorbis');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No Vorbis comments found');
    });

    test('returns a status field for corrupt bytes', () async {
      final bytes = Uint8List.fromList(
        utf8.encode('this is definitely not an audio container'),
      );

      final fields = await extractVorbis(bytes, extension: 'opus');

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Unable to parse Vorbis comments');
    });
  });
}

/// Builds a FLAC stream with a STREAMINFO block and a VORBIS_COMMENT block.
Uint8List _flacWithComment(List<String> entries) {
  final payload = _commentPayload(entries);
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('fLaC'));
  // STREAMINFO block: type 0, not last.
  builder.addByte(0x00);
  builder.add(_be3(34));
  builder.add(Uint8List(34));
  // VORBIS_COMMENT block: type 4, last.
  builder.addByte(0x84);
  builder.add(_be3(payload.length));
  builder.add(payload);
  return builder.takeBytes();
}

/// Builds a FLAC stream whose only block is last-marked STREAMINFO.
Uint8List _flacWithoutComment() {
  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('fLaC'));
  builder.addByte(0x80); // type 0 STREAMINFO, last block
  builder.add(_be3(34));
  builder.add(Uint8List(34));
  return builder.takeBytes();
}

/// Builds a single-page Ogg stream with [packet1] and [packet2].
Uint8List _oggVorbisPage(Uint8List packet1, Uint8List packet2) {
  final segments = <int>[];
  final data = BytesBuilder(copy: false);
  for (final packet in [packet1, packet2]) {
    var remaining = packet.length;
    while (remaining >= 255) {
      segments.add(255);
      remaining -= 255;
    }
    segments.add(remaining);
    data.add(packet);
  }

  final builder = BytesBuilder(copy: false);
  builder.add(latin1.encode('OggS'));
  builder.addByte(0); // version
  builder.addByte(0); // header type
  builder.add(Uint8List(8)); // granule position
  builder.add(_le32(0x1234)); // serial number
  builder.add(_le32(0)); // page sequence
  builder.add(_le32(0)); // checksum
  builder.addByte(segments.length);
  builder.add(Uint8List.fromList(segments));
  builder.add(data.takeBytes());
  return builder.takeBytes();
}

/// Builds a Vorbis comment block body containing [entries] as KEY=VALUE.
Uint8List _commentPayload(List<String> entries) {
  final builder = BytesBuilder(copy: false);
  final vendor = latin1.encode('metastrip-test');
  builder.add(_le32(vendor.length));
  builder.add(vendor);
  builder.add(_le32(entries.length));
  for (final entry in entries) {
    final body = utf8.encode(entry);
    builder.add(_le32(body.length));
    builder.add(body);
  }
  return builder.takeBytes();
}

/// Concatenates [first] and [rest] into a new byte buffer.
Uint8List _concat(Uint8List first, Uint8List rest) {
  return Uint8List.fromList([...first, ...rest]);
}

/// Encodes [value] as a three-byte big-endian integer (FLAC block length).
Uint8List _be3(int value) {
  return Uint8List.fromList([
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
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