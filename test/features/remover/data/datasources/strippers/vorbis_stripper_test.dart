import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
    ..._le32(0x12345678), // serial
    ..._le32(sequence),
    0x00, 0x00, 0x00, 0x00, // CRC placeholder
    laces.length,
    ...laces,
    ...payload,
  ];
  final crc = _crc(page);
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

/// Ogg page CRC, same algorithm as the stripper: reflected CRC-32 with
/// polynomial 0x04C11DB7, init 0, no final XOR, covering the header without
/// the CRC field (bytes 0..21) plus everything from the segment count on.
int _crc(List<int> page) {
  var crc = 0;
  void update(int value) {
    crc ^= value;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }

  for (var i = 0; i < 22; i++) {
    update(page[i]);
  }
  for (var i = 26; i < page.length; i++) {
    update(page[i]);
  }
  return crc;
}
