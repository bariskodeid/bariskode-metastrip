import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/vorbis_extractor.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

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
      expect(byLabel['Title']?.id, MetadataFieldId.vorbisComment('title'));
      expect(byLabel['CUSTOM']?.id, MetadataFieldId.vorbisComment('custom'));
    });

    test('normalizes parsed Vorbis IDs with ASCII whitespace and case rules',
        () async {
      final bytes = _flacWithComment([' \tTiTLe\r =Secret']);
      final fields = await extractVorbis(bytes, extension: 'flac');

      expect(fields.single.id, MetadataFieldId.vorbisComment('title'));
      expect(fields.single.label, 'Title');
    });

    test('malformed UTF-8 comment does not hide others', () async {
      final bytes = _flacWithRawComments([
        utf8.encode('TITLE=Fine'),
        [0x41, 0x52, 0x54, 0x49, 0x53, 0x54, 0x3D, 0xFF, 0xFE],
        utf8.encode('ALBUM=Also Fine'),
      ]);
      final fields = await extractVorbis(bytes, extension: 'flac');
      final byLabel = {for (final field in fields) field.label: field};

      expect(fields, hasLength(3));
      expect(byLabel['Title']?.value, 'Fine');
      expect(byLabel['Album']?.value, 'Also Fine');
      expect(byLabel['Artist']?.value, startsWith('�'));
    });

    test('key with ~ is shown without a removable id', () async {
      final bytes = _flacWithComment(['TITLE=Fine', 'A~B=value']);
      final fields = await extractVorbis(bytes, extension: 'flac');
      final byLabel = {for (final field in fields) field.label: field};

      expect(fields, hasLength(2));
      expect(byLabel['Title']?.id, MetadataFieldId.vorbisComment('title'));
      expect(byLabel['A~B']?.value, 'value');
      expect(byLabel['A~B']?.id, isNull);
    });

    test('whitespace-only key is shown without a removable id', () async {
      final bytes = _flacWithComment(['TITLE=Fine', '  =blank-key']);
      final fields = await extractVorbis(bytes, extension: 'flac');

      expect(fields, hasLength(2));
      expect(fields.last.value, 'blank-key');
      expect(fields.last.id, isNull);
      expect(fields.first.id, MetadataFieldId.vorbisComment('title'));
    });

    test('comment packet spanning three pages is reassembled', () async {
      final cover = 'C' * 600;
      final payload = _commentPayload([
        'TITLE=Spanning',
        'COVER=$cover',
        'ARTIST=Tail Artist',
      ]);
      final bytes = _oggSpanning(
        Uint8List.fromList([0x01, ...latin1.encode('vorbis')]),
        _concat(
            Uint8List.fromList([0x03, ...latin1.encode('vorbis')]), payload),
      );

      final fields = await extractVorbis(bytes, extension: 'ogg');
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Title']?.value, 'Spanning');
      expect(byLabel['COVER']?.value, startsWith('CCCC'));
      expect(byLabel['Artist']?.value, 'Tail Artist');
    });

    test('Opus tags packet spanning pages is reassembled', () async {
      final payload = _commentPayload(['TITLE=Opus Span', 'X=${'y' * 600}']);
      final bytes = _oggSpanning(
        Uint8List.fromList(latin1.encode('OpusHead') + List.filled(11, 0)),
        _concat(Uint8List.fromList(latin1.encode('OpusTags')), payload),
      );

      final fields = await extractVorbis(bytes, extension: 'opus');

      expect(fields.first.value, 'Opus Span');
      expect(fields, hasLength(2));
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
  return _flacWithPayload(_commentPayload(entries));
}

Uint8List _flacWithRawComments(List<List<int>> entries) {
  final builder = BytesBuilder(copy: false)
    ..add(_le32('metastrip-test'.length))
    ..add(latin1.encode('metastrip-test'))
    ..add(_le32(entries.length));
  for (final entry in entries) {
    builder
      ..add(_le32(entry.length))
      ..add(entry);
  }
  return _flacWithPayload(builder.takeBytes());
}

/// Builds an Ogg stream where [comment] is split over three pages (the
/// identification packet sits alone on the first page).
Uint8List _oggSpanning(Uint8List ident, Uint8List comment) {
  final third = (comment.length / 3).ceil();
  // Split on 255-byte lacing boundaries so continuation pages are legal.
  final chunk = ((third + 254) ~/ 255) * 255;
  final parts = <Uint8List>[];
  for (var at = 0; at < comment.length; at += chunk) {
    final end = at + chunk < comment.length ? at + chunk : comment.length;
    parts.add(Uint8List.sublistView(comment, at, end));
  }
  expect(parts.length, greaterThanOrEqualTo(3));
  final out = BytesBuilder(copy: false)
    ..add(_oggPage([ident.length], ident, 0x02));
  for (var i = 0; i < parts.length; i++) {
    final last = i == parts.length - 1;
    final lacing = <int>[];
    var remaining = parts[i].length;
    while (remaining >= 255) {
      lacing.add(255);
      remaining -= 255;
    }
    if (last) lacing.add(remaining);
    out.add(_oggPage(lacing, parts[i], i == 0 ? 0 : 0x01));
  }
  return out.takeBytes();
}

Uint8List _oggPage(List<int> lacing, List<int> data, int headerType) {
  final builder = BytesBuilder(copy: false)
    ..add(latin1.encode('OggS'))
    ..addByte(0)
    ..addByte(headerType)
    ..add(Uint8List(8))
    ..add(_le32(0x1234))
    ..add(_le32(0))
    ..add(_le32(0))
    ..addByte(lacing.length)
    ..add(lacing)
    ..add(data);
  return builder.takeBytes();
}

Uint8List _flacWithPayload(Uint8List payload) {
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
