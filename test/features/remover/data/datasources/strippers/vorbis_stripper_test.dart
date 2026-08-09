import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/ogg_vorbis_selective_poc.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/vorbis_stripper.dart';

void main() {
  group('stripVorbisComments - FLAC', () {
    test('selectively removes every case-insensitive occurrence by key', () {
      final audio = List<int>.filled(100, 0xAB);
      final bytes = _flacFile(
        blocks: [
          _flacStreamInfoBlock(),
          _flacCommentBlock(
            vendor: 'keep-vendor',
            comments: const [
              'title=Secret one',
              'TITLE=Secret two',
              'ARTIST=Keep artist',
              'CUSTOM=Keep custom',
            ],
          ),
          _flacPaddingBlock(size: 3),
        ],
        audio: audio,
      );
      final result = stripFlacVorbisCommentsSelective(
        bytes,
        selectedKeys: {'TiTlE'},
      );
      expect(result.matchedKeys, {'TITLE'});
      final resultText = String.fromCharCodes(result.bytes);
      expect(resultText, isNot(contains('Secret one')));
      expect(resultText, contains('Keep artist'));
      expect(resultText, contains('keep-vendor'));
      expect(result.bytes.sublist(result.bytes.length - audio.length), audio);
    });

    test('normalizes ASCII whitespace and case in parsed keys', () {
      final bytes = _flacFile(
        blocks: [
          _flacStreamInfoBlock(),
          _flacCommentBlock(
            vendor: 'vendor',
            comments: const [' \tTiTLe\r =Secret', 'ARTIST=Keep'],
          ),
        ],
      );
      final result = stripFlacVorbisCommentsSelective(
        bytes,
        selectedKeys: {' title '},
      );
      expect(result.matchedKeys, {'TITLE'});
      expect(String.fromCharCodes(result.bytes), isNot(contains('Secret')));
      expect(String.fromCharCodes(result.bytes), contains('ARTIST=Keep'));
    });

    test('accepts and preserves an empty Vorbis vendor string', () {
      final bytes = _flacFile(
        blocks: [
          _flacStreamInfoBlock(),
          _flacCommentBlock(
            vendor: '',
            comments: const ['TITLE=Remove', 'ARTIST=Keep'],
          ),
        ],
      );

      final result = stripFlacVorbisCommentsSelective(
        bytes,
        selectedKeys: {'TITLE'},
      );

      expect(result.matchedKeys, {'TITLE'});
      expect(String.fromCharCodes(result.bytes), isNot(contains('Remove')));
      expect(String.fromCharCodes(result.bytes), contains('ARTIST=Keep'));
    });

    test('rejects malformed UTF-8 in a comment entry', () {
      final bytes = _flacFile(
        blocks: [_flacStreamInfoBlock(), _flacCommentBlock(vendor: 'x')],
      );
      bytes[bytes.length - 1] = 0xFF;
      expect(
        () => stripFlacVorbisCommentsSelective(bytes, selectedKeys: {'TITLE'}),
        throwsFormatException,
      );
    });

    test('strips a comment block and patches the last flag', () {
      final bytes = _flacFile(
        blocks: [
          _flacStreamInfoBlock(),
          _flacCommentBlock(
            vendor: 'libFLAC',
            comments: const ['TITLE=Secret', 'ARTIST=Anonymous'],
          ),
        ],
        audio: List<int>.filled(100, 0xAB),
      );

      final result = stripVorbisComments(bytes, extension: 'flac');

      expect(String.fromCharCodes(result.sublist(0, 4)), 'fLaC');
      final blocks = _flacBlocks(result);
      expect(blocks.map((b) => b.type), isNot(contains(4)));
      expect(blocks, hasLength(1));
      expect(blocks.single.type, 0);
      expect(blocks.single.isLast, isTrue);
      expect(String.fromCharCodes(result), isNot(contains('TITLE=Secret')));
      expect(result.sublist(4 + 4 + 34), List<int>.filled(100, 0xAB));
    });

    test('returns the original bytes when no comment block exists', () {
      final bytes = _flacFile(
        blocks: [_flacStreamInfoBlock(isLast: true)],
        audio: List<int>.filled(50, 0x01),
      );

      final result = stripVorbisComments(bytes, extension: 'flac');

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException when the file is not FLAC', () {
      final bytes = Uint8List.fromList('Not a FLAC file'.codeUnits);

      expect(
        () => stripVorbisComments(bytes, extension: 'flac'),
        throwsFormatException,
      );
    });

    test(
        'rejects a missing final metadata flag even when audio mimics a header',
        () {
      final bytes = Uint8List.fromList([
        ...'fLaC'.codeUnits,
        ..._flacStreamInfoBlock(isLast: false),
        // Audio bytes deliberately look like a 34-byte STREAMINFO block.
        0x00, 0x00, 0x00, 0x22,
        ...List<int>.filled(34, 0xA5),
      ]);

      expect(
        () => stripFlacVorbisCommentsSelective(
          bytes,
          selectedKeys: {'TITLE'},
        ),
        throwsFormatException,
      );
    });

    test('rejects every reserved FLAC metadata block type from 7 through 127',
        () {
      for (var type = 7; type <= 127; type++) {
        final bytes = Uint8List.fromList([
          ...'fLaC'.codeUnits,
          ..._flacStreamInfoBlock(),
          0x80 | type,
          0x00,
          0x00,
          0x00,
        ]);

        expect(
          () => stripFlacVorbisCommentsSelective(
            bytes,
            selectedKeys: {'TITLE'},
          ),
          throwsFormatException,
          reason: 'metadata block type $type must be rejected',
        );
      }
    });

    test('rejects a duplicate STREAMINFO block', () {
      final bytes = _flacFile(
        blocks: [
          _flacStreamInfoBlock(),
          _flacStreamInfoBlock(isLast: true),
        ],
      );

      expect(
        () => stripFlacVorbisCommentsSelective(bytes, selectedKeys: {'TITLE'}),
        throwsFormatException,
      );
    });

    test('drops a non-last comment block and keeps following blocks', () {
      final bytes = _flacFile(
        blocks: [
          _flacStreamInfoBlock(),
          _flacCommentBlock(
            vendor: 'xiph',
            comments: const ['ARTIST=Ghost'],
            isLast: false,
          ),
          _flacPaddingBlock(size: 12),
        ],
        audio: List<int>.filled(100, 0xCD),
      );

      final result = stripVorbisComments(bytes, extension: 'flac');

      final blocks = _flacBlocks(result);
      expect(blocks.map((b) => b.type), [0, 6]);
      expect(blocks[0].isLast, isFalse);
      expect(blocks[1].isLast, isTrue);
      expect(blocks[1].payload, List<int>.filled(12, 0));
      expect(result, hasLength(4 + (4 + 34) + (4 + 12) + 100));
      expect(result.sublist(58), List<int>.filled(100, 0xCD));
    });

    test('throws when the comment block is the only metadata block', () {
      final bytes = _flacFile(
        blocks: [
          _flacCommentBlock(vendor: 'xiph', comments: const ['TITLE=Alone']),
        ],
        audio: List<int>.filled(100, 0xEE),
      );

      expect(
        () => stripVorbisComments(bytes, extension: 'flac'),
        throwsFormatException,
      );
    });
  });

  group('stripVorbisComments - OGG', () {
    test('zeroes the comment count and recomputes the page CRC', () {
      final identPacket = <int>[
        0x01,
        ...'vorbis'.codeUnits,
        ...List<int>.filled(20, 0x01),
      ];
      final commentPacket = <int>[
        0x03,
        ...'vorbis'.codeUnits,
        ..._vorbisCommentPayload(
          vendor: 'Xiph.Org',
          comments: const ['TITLE=Hello', 'ARTIST=World'],
        ),
      ];
      final setupPacket = <int>[
        0x05,
        ...'vorbis'.codeUnits,
        ...List<int>.filled(10, 0x02),
      ];
      final page1 = _oggPage(packets: [identPacket], headerType: 0x02);
      final page2 = _oggPage(packets: [commentPacket], sequence: 1);
      final page3 = _oggPage(packets: [setupPacket], sequence: 2);
      final bytes = Uint8List.fromList([...page1, ...page2, ...page3]);

      final result = stripVorbisComments(bytes, extension: 'ogg');

      expect(result, hasLength(bytes.length));
      expect(result.sublist(0, page1.length), page1);
      final page2Start = page1.length;
      expect(result.sublist(page2Start + page2.length), page3);

      final packets = _oggPackets(result, page2Start);
      expect(packets, hasLength(1));
      final packet = packets.single;
      final vendorLength = ByteData.sublistView(packet).getUint32(
        7,
        Endian.little,
      );
      expect(vendorLength, 'Xiph.Org'.codeUnits.length);
      expect(
        String.fromCharCodes(packet.sublist(11, 11 + vendorLength)),
        'Xiph.Org',
      );
      final countOffset = 7 + 4 + vendorLength;
      expect(
        ByteData.sublistView(packet).getUint32(countOffset, Endian.little),
        0,
      );
      // Trailing bytes of the preserved-length packet are zero padding.
      expect(packet.sublist(countOffset + 4), everyElement(0));

      final strippedPage = result.sublist(
        page2Start,
        page2Start + page2.length,
      );
      final storedCrc = ByteData.sublistView(strippedPage).getUint32(
        22,
        Endian.little,
      );
      expect(storedCrc, _crc(strippedPage));
    });

    test('returns the original bytes when no comment packet is found', () {
      final identPacket = <int>[
        0x01,
        ...'vorbis'.codeUnits,
        ...List<int>.filled(20, 0x01),
      ];
      final setupPacket = <int>[
        0x05,
        ...'vorbis'.codeUnits,
        ...List<int>.filled(10, 0x02),
      ];
      final bytes = Uint8List.fromList([
        ..._oggPage(packets: [identPacket], headerType: 0x02),
        ..._oggPage(packets: [setupPacket], sequence: 1),
      ]);

      final result = stripVorbisComments(bytes, extension: 'ogg');

      expect(identical(result, bytes), isTrue);
      expect(result, bytes);
    });

    test('throws FormatException when the file is not Ogg', () {
      final bytes = Uint8List.fromList('Definitely not Ogg'.codeUnits);

      expect(
        () => stripVorbisComments(bytes, extension: 'ogg'),
        throwsFormatException,
      );
    });
  });

  group('disabled Ogg Vorbis selective POC', () {
    test('uses the Xiph non-reflected CRC known vector', () {
      expect(_independentOggCrc('123456789'.codeUnits), 0x89A1897F);
    });

    test('requires BOS on the first page and rejects later BOS', () {
      final packet = <int>[0x01, ...'vorbis'.codeUnits, 1];
      final noBos = Uint8List.fromList(_oggPage(packets: [packet]));
      final laterBos = Uint8List.fromList([
        ..._oggPage(packets: [packet], headerType: 2),
        ..._oggPage(packets: [packet], headerType: 2, sequence: 1),
      ]);
      for (final input in [noBos, laterBos]) {
        expect(
          () => stripOggVorbisCommentsSelectivePoc(
            input,
            selectedKeys: {'TITLE'},
          ),
          throwsFormatException,
        );
      }
    });

    test('handles the exact 255-byte packet boundary with a terminating zero',
        () {
      final identification = <int>[0x01, ...'vorbis'.codeUnits, 1];
      final value = List<String>.filled(229, 'x').join();
      final comment = <int>[
        0x03,
        ...'vorbis'.codeUnits,
        ..._vorbisCommentPayload(vendor: 'x', comments: ['TITLE=$value']),
      ];
      expect(comment.length, 255);
      final input = Uint8List.fromList([
        ..._oggPage(packets: [identification], headerType: 2),
        ..._oggPage(packets: [comment], sequence: 1),
      ]);
      expect(
        () =>
            stripOggVorbisCommentsSelectivePoc(input, selectedKeys: {'TITLE'}),
        returnsNormally,
      );
    });

    test('removes all normalized key occurrences and preserves other data', () {
      final identification = <int>[0x01, ...'vorbis'.codeUnits, 1, 2, 3];
      final comment = <int>[
        0x03,
        ...'vorbis'.codeUnits,
        ..._vorbisCommentPayload(
          vendor: 'keep-vendor',
          comments: const [
            'title=remove one',
            'ARTIST=keep artist',
            ' TITLE =remove two',
            'CUSTOM=keep custom',
          ],
        ),
      ];
      final setup = <int>[0x05, ...'vorbis'.codeUnits, 9, 8, 7];
      final first = _oggPage(packets: [identification], headerType: 2);
      final middle = _oggPage(
        packets: [comment, setup],
        sequence: 1,
      );
      final last = _oggPage(
        packets: const [
          <int>[10, 11, 12]
        ],
        headerType: 4,
        sequence: 2,
      );
      final input = Uint8List.fromList([...first, ...middle, ...last]);

      final result = stripOggVorbisCommentsSelectivePoc(
        input,
        selectedKeys: {'\tTiTlE '},
      );

      expect(result.matchedKeys, {'TITLE'});
      expect(result.bytes.sublist(0, first.length), first);
      expect(result.bytes.sublist(result.bytes.length - last.length), last);
      final rewrittenPackets = _oggPackets(result.bytes, first.length);
      expect(_commentStrings(rewrittenPackets.first), [
        'ARTIST=keep artist',
        'CUSTOM=keep custom',
      ]);
      expect(rewrittenPackets[1], setup);
      final rewrittenPage = result.bytes.sublist(
        first.length,
        result.bytes.length - last.length,
      );
      expect(
        ByteData.sublistView(rewrittenPage).getUint32(22, Endian.little),
        _xiphCrc(rewrittenPage),
      );
    });

    test('fails closed for a continued page or cross-page packet', () {
      final identification = <int>[0x01, ...'vorbis'.codeUnits, 1];
      final continued = _oggPage(
        packets: const [
          <int>[1, 2]
        ],
        headerType: 1,
        sequence: 1,
      );
      final input = Uint8List.fromList([
        ..._oggPage(packets: [identification], headerType: 2),
        ...continued,
      ]);

      expect(
        () => stripOggVorbisCommentsSelectivePoc(
          input,
          selectedKeys: {'TITLE'},
        ),
        throwsFormatException,
      );

      final crossPage = Uint8List.fromList([
        ..._oggPage(packets: [identification], headerType: 2),
        ..._oggPage(
          packets: [List<int>.filled(255, 1)],
          sequence: 1,
        ),
      ]);
      expect(
        () => stripOggVorbisCommentsSelectivePoc(
          crossPage,
          selectedKeys: {'TITLE'},
        ),
        throwsFormatException,
      );
    });

    test('fails closed for Opus, chained streams, and malformed comments', () {
      final opus = Uint8List.fromList(
        _oggPage(packets: [
          <int>[...'OpusHead'.codeUnits, 1]
        ], headerType: 2),
      );
      final malformed = Uint8List.fromList([
        ..._oggPage(
          packets: [
            <int>[0x01, ...'vorbis'.codeUnits]
          ],
          headerType: 2,
        ),
        ..._oggPage(
          packets: [
            <int>[0x03, ...'vorbis'.codeUnits, 0xff]
          ],
          sequence: 1,
        ),
      ]);
      final chained = Uint8List.fromList([
        ..._oggPage(
          packets: [
            <int>[0x01, ...'vorbis'.codeUnits]
          ],
          headerType: 2,
        ),
        ..._oggPage(
          packets: [
            <int>[0x03, ...'vorbis'.codeUnits]
          ],
          sequence: 1,
          serial: 0x76543210,
        ),
      ]);

      for (final input in [opus, malformed, chained]) {
        expect(
          () => stripOggVorbisCommentsSelectivePoc(
            input,
            selectedKeys: {'TITLE'},
          ),
          throwsFormatException,
        );
      }
    });
  });
}

List<String> _commentStrings(Uint8List packet) {
  final view = ByteData.sublistView(packet);
  final vendorLength = view.getUint32(7, Endian.little);
  var offset = 11 + vendorLength;
  final count = view.getUint32(offset, Endian.little);
  offset += 4;
  final comments = <String>[];
  for (var i = 0; i < count; i++) {
    final length = view.getUint32(offset, Endian.little);
    offset += 4;
    comments.add(String.fromCharCodes(packet.sublist(offset, offset + length)));
    offset += length;
  }
  expect(offset, packet.length);
  return comments;
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

List<int> _flacStreamInfoBlock({bool isLast = false}) {
  return _flacBlock(
    type: 0,
    isLast: isLast,
    payload: List<int>.filled(34, 0x11),
  );
}

List<int> _flacPaddingBlock({required int size}) {
  return _flacBlock(type: 6, isLast: true, payload: List<int>.filled(size, 0));
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

List<({int type, bool isLast, Uint8List payload})> _flacBlocks(
  Uint8List bytes,
) {
  final blocks = <({int type, bool isLast, Uint8List payload})>[];
  var offset = 4;
  while (offset + 4 <= bytes.length) {
    final flags = bytes[offset];
    final size = (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    blocks.add((
      type: flags & 0x7F,
      isLast: flags & 0x80 != 0,
      payload: bytes.sublist(offset + 4, offset + 4 + size),
    ));
    if (flags & 0x80 != 0) break;
    offset += 4 + size;
  }
  return blocks;
}

List<int> _oggPage({
  required List<List<int>> packets,
  int headerType = 0,
  int sequence = 0,
  int serial = 0x12345678,
}) {
  final laces = <int>[];
  final payload = <int>[];
  for (final packet in packets) {
    final (packetLaces, packetBytes) = _lacePacket(packet);
    laces.addAll(packetLaces);
    payload.addAll(packetBytes);
  }
  final page = <int>[
    ...'OggS'.codeUnits,
    0x00, // version
    headerType,
    ..._le64(0), // granule position
    ..._le32(serial), // serial
    ..._le32(sequence),
    0x00, 0x00, 0x00, 0x00, // CRC placeholder
    laces.length,
    ...laces,
    ...payload,
  ];
  final crc = _xiphCrc(page);
  page[22] = crc & 0xFF;
  page[23] = (crc >> 8) & 0xFF;
  page[24] = (crc >> 16) & 0xFF;
  page[25] = (crc >> 24) & 0xFF;
  return page;
}

(List<int>, List<int>) _lacePacket(List<int> packet) {
  if (packet.isEmpty) return (<int>[0], <int>[]);
  final laces = <int>[];
  final payload = <int>[];
  var offset = 0;
  while (packet.length - offset > 255) {
    laces.add(255);
    payload.addAll(packet.sublist(offset, offset + 255));
    offset += 255;
  }
  laces.add(packet.length - offset);
  payload.addAll(packet.sublist(offset));
  if (laces.last == 255) laces.add(0);
  return (laces, payload);
}

List<Uint8List> _oggPackets(Uint8List bytes, int pageStart) {
  final segmentCount = bytes[pageStart + 26];
  final tableStart = pageStart + 27;
  final packets = <Uint8List>[];
  var cursor = tableStart + segmentCount;
  var packetStart = cursor;
  for (var i = 0; i < segmentCount; i++) {
    cursor += bytes[tableStart + i];
    if (bytes[tableStart + i] < 255) {
      packets.add(bytes.sublist(packetStart, cursor));
      packetStart = cursor;
    }
  }
  return packets;
}

List<int> _le32(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

List<int> _le64(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 56) & 0xFF,
    ];

/// Test-only page builder checksum. Kept separate from production code and
/// independently written from the Xiph/Ogg specification.
int _crc(List<int> page) {
  var crc = 0;
  for (var i = 0; i < page.length; i++) {
    if (i >= 22 && i < 26) continue;
    crc ^= page[i];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc;
}

int _xiphCrc(List<int> page) {
  final covered = <int>[...page.take(22), ...page.skip(26)];
  return _independentOggCrc(covered);
}

int _independentOggCrc(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte << 24;
    for (var i = 0; i < 8; i++) {
      if ((crc & 0x80000000) != 0) {
        crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
      } else {
        crc = (crc << 1) & 0xFFFFFFFF;
      }
    }
  }
  return crc;
}
