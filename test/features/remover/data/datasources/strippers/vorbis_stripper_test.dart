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
      final commentPacket = _vorbisCommentPacket(
        vendor: 'Xiph.Org',
        comments: const ['TITLE=Hello', 'ARTIST=World'],
      );
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
      expect(packet, hasLength(commentPacket.length));
      expect(packet[countOffset + 4], 1, reason: 'Vorbis framing bit');
      // Trailing bytes of the preserved-length packet are zero padding.
      expect(packet.sublist(countOffset + 5), everyElement(0));

      final strippedPage = result.sublist(
        page2Start,
        page2Start + page2.length,
      );
      final storedCrc = ByteData.sublistView(strippedPage).getUint32(
        22,
        Endian.little,
      );
      expect(storedCrc, _referencePageCrc(strippedPage));
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

    test('rewritten Vorbis comment page carries a libogg-valid CRC', () {
      final page1 = _oggPage(packets: [_vorbisIdPacket], headerType: 0x02);
      final page2 = _oggPage(
        packets: [
          _vorbisCommentPacket(
            vendor: 'Xiph.Org libVorbis I 20200704 (Reducing Environment)',
            comments: const ['TITLE=Secret', 'ARTIST=Someone', 'DATE=2026'],
          ),
          _vorbisSetupPacket,
        ],
        sequence: 1,
      );
      final bytes = Uint8List.fromList([...page1, ...page2]);

      final result = stripVorbisComments(bytes, extension: 'ogg');

      expect(result, isNot(bytes));
      for (final page in _oggPageSpans(result)) {
        final pageBytes = result.sublist(page.start, page.end);
        expect(
          ByteData.sublistView(pageBytes).getUint32(22, Endian.little),
          _referencePageCrc(pageBytes),
          reason: 'page at ${page.start} must carry a libogg-valid CRC',
        );
      }
    });

    test('Vorbis comment header keeps framing bit 1 after count', () {
      final comment = _vorbisCommentPacket(
        vendor: 'vendor',
        comments: const ['TITLE=Secret'],
      );
      final bytes = Uint8List.fromList([
        ..._oggPage(packets: [_vorbisIdPacket], headerType: 0x02),
        ..._oggPage(packets: [comment, _vorbisSetupPacket], sequence: 1),
      ]);

      final result = stripVorbisComments(bytes, extension: 'ogg');

      final packets = _oggPackets(result, _oggPageSpans(result)[1].start);
      final packet = packets.first;
      const countOffset = 7 + 4 + 6;
      expect(packet, hasLength(comment.length));
      expect(
        ByteData.sublistView(packet).getUint32(countOffset, Endian.little),
        0,
      );
      expect(packet[countOffset + 4], 1);
      expect(packet.sublist(countOffset + 5), everyElement(0));
      expect(packets[1], _vorbisSetupPacket);
    });

    test('Opus tags rewrite has no framing byte requirement', () {
      // No comments and no trailing byte: the packet ends right after the
      // count, which is valid for OpusTags (it has no framing bit).
      final bare = _opusTagsPacket(vendor: 'libopus 1.4');
      final withComments = _opusTagsPacket(
        vendor: 'libopus 1.4',
        comments: const ['TITLE=Secret'],
      );
      const countOffset = 8 + 4 + 11;

      for (final tags in [bare, withComments]) {
        final page1 = _oggPage(packets: [_opusHeadPacket], headerType: 0x02);
        final page2 = _oggPage(packets: [tags], sequence: 1);
        final bytes = Uint8List.fromList([...page1, ...page2]);

        final result = stripVorbisComments(bytes, extension: 'ogg');

        expect(result, hasLength(bytes.length));
        final packet = _oggPackets(result, page1.length).single;
        expect(packet, hasLength(tags.length));
        expect(
          ByteData.sublistView(packet).getUint32(countOffset, Endian.little),
          0,
        );
        expect(packet.sublist(countOffset + 4), everyElement(0));
        final rewrittenPage = result.sublist(page1.length);
        expect(
          ByteData.sublistView(rewrittenPage).getUint32(22, Endian.little),
          _referencePageCrc(rewrittenPage),
        );
      }
    });

    test('Vorbis comment header without room for the framing bit throws', () {
      // Count present but no trailing framing byte.
      final comment = <int>[
        0x03,
        ...'vorbis'.codeUnits,
        ..._vorbisCommentPayload(vendor: 'vendor'),
      ];
      final bytes = Uint8List.fromList([
        ..._oggPage(packets: [_vorbisIdPacket], headerType: 0x02),
        ..._oggPage(packets: [comment], sequence: 1),
      ]);

      expect(
        () => stripVorbisComments(bytes, extension: 'ogg'),
        throwsFormatException,
      );
    });

    test('comment packet spanning two pages throws FormatException', () {
      final comment = _vorbisCommentPacket(
        vendor: 'vendor',
        comments: ['METADATA_BLOCK_PICTURE=${'A' * 400}'],
      );
      expect(comment.length, greaterThan(255));
      final first = comment.sublist(0, 255);
      final rest = comment.sublist(255);
      final bytes = Uint8List.fromList([
        ..._oggPage(packets: [_vorbisIdPacket], headerType: 0x02),
        ..._oggRawPage(laces: const [255], payload: first, sequence: 1),
        ..._oggRawPage(
          laces: [rest.length],
          payload: rest,
          headerType: 0x01, // continued packet
          sequence: 2,
        ),
      ]);

      expect(
        () => stripVorbisComments(bytes, extension: 'ogg'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Ogg comment packet spans pages',
          ),
        ),
      );
    });

    test('comment packet shorter than marker+4 throws FormatException', () {
      for (final marker in [
        <int>[0x03, ...'vorbis'.codeUnits],
        'OpusTags'.codeUnits,
      ]) {
        final bytes = Uint8List.fromList([
          ..._oggPage(packets: [_vorbisIdPacket], headerType: 0x02),
          ..._oggPage(
            packets: [
              <int>[...marker, 0x01, 0x00],
            ],
            sequence: 1,
          ),
        ]);

        expect(
          () => stripVorbisComments(bytes, extension: 'ogg'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Truncated Ogg comment packet',
            ),
          ),
        );
      }
    });

    test('does not treat a continued fragment as a comment packet start', () {
      // Page 2 ends a setup packet that began on page 1; that fragment
      // happens to begin with the comment marker but must be left alone.
      final setup = <int>[
        0x05,
        ...'vorbis'.codeUnits,
        ...List<int>.filled(248, 0x02),
        // Continued fragment starts here and mimics a comment header.
        0x03, ...'vorbis'.codeUnits, 0xFF, 0xFF, 0xFF, 0xFF,
      ];
      final bytes = Uint8List.fromList([
        ..._oggRawPage(
          laces: const [30, 255],
          payload: [..._vorbisIdPacket, ...setup.sublist(0, 255)],
          headerType: 0x02,
        ),
        ..._oggRawPage(
          laces: [setup.length - 255],
          payload: setup.sublist(255),
          headerType: 0x01,
          sequence: 1,
        ),
      ]);

      final result = stripVorbisComments(bytes, extension: 'ogg');

      expect(identical(result, bytes), isTrue);
    });
  });

  group('disabled Ogg Vorbis selective POC', () {
    test('accepts and re-emits the Vorbis framing bit', () {
      final comment = _vorbisCommentPacket(
        vendor: 'keep-vendor',
        comments: const ['TITLE=remove', 'ARTIST=keep'],
      );
      final first = _oggPage(packets: [_vorbisIdPacket], headerType: 2);
      final input = Uint8List.fromList([
        ...first,
        ..._oggPage(packets: [comment, _vorbisSetupPacket], sequence: 1),
      ]);

      final result = stripOggVorbisCommentsSelectivePoc(
        input,
        selectedKeys: {'TITLE'},
      );

      expect(result.matchedKeys, {'TITLE'});
      final packets = _oggPackets(result.bytes, first.length);
      final rewritten = packets.first;
      expect(rewritten.last, 1, reason: 'Vorbis framing bit');
      expect(_commentStrings(rewritten.sublist(0, rewritten.length - 1)), [
        'ARTIST=keep',
      ]);
      expect(packets[1], _vorbisSetupPacket);
      for (final page in _oggPageSpans(result.bytes)) {
        final pageBytes = result.bytes.sublist(page.start, page.end);
        expect(
          ByteData.sublistView(pageBytes).getUint32(22, Endian.little),
          _referencePageCrc(pageBytes),
        );
      }
    });

    test('uses the Xiph non-reflected CRC known vector', () {
      expect(_referenceCrc32('123456789'.codeUnits), 0x89A1897F);
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
        _referencePageCrc(rewrittenPage),
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
  return _oggRawPage(
    laces: laces,
    payload: payload,
    headerType: headerType,
    sequence: sequence,
    serial: serial,
  );
}

/// Builds an Ogg page from an explicit lacing table, so tests can create
/// packets that continue onto the next page.
List<int> _oggRawPage({
  required List<int> laces,
  required List<int> payload,
  int headerType = 0,
  int sequence = 0,
  int serial = 0x12345678,
}) {
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
  final crc = _referencePageCrc(page);
  page[22] = crc & 0xFF;
  page[23] = (crc >> 8) & 0xFF;
  page[24] = (crc >> 16) & 0xFF;
  page[25] = (crc >> 24) & 0xFF;
  return page;
}

/// Start/end offsets of every Ogg page in [bytes].
List<({int start, int end})> _oggPageSpans(Uint8List bytes) {
  final spans = <({int start, int end})>[];
  var offset = 0;
  while (offset < bytes.length) {
    final segmentCount = bytes[offset + 26];
    var end = offset + 27 + segmentCount;
    for (var i = 0; i < segmentCount; i++) {
      end += bytes[offset + 27 + i];
    }
    spans.add((start: offset, end: end));
    offset = end;
  }
  return spans;
}

/// 30-byte Vorbis identification header stand-in.
final List<int> _vorbisIdPacket = [
  0x01,
  ...'vorbis'.codeUnits,
  ...List<int>.filled(23, 0x01),
];

final List<int> _vorbisSetupPacket = [
  0x05,
  ...'vorbis'.codeUnits,
  ...List<int>.filled(10, 0x02),
];

final List<int> _opusHeadPacket = [
  ...'OpusHead'.codeUnits,
  ...List<int>.filled(11, 0x01),
];

/// A spec-shaped Vorbis comment header, ending with the framing bit.
List<int> _vorbisCommentPacket({
  required String vendor,
  List<String> comments = const [],
}) {
  return [
    0x03,
    ...'vorbis'.codeUnits,
    ..._vorbisCommentPayload(vendor: vendor, comments: comments),
    0x01, // framing bit
  ];
}

/// An OpusTags packet; unlike Vorbis it has no framing bit.
List<int> _opusTagsPacket({
  required String vendor,
  List<String> comments = const [],
}) {
  return [
    ...'OpusTags'.codeUnits,
    ..._vorbisCommentPayload(vendor: vendor, comments: comments),
  ];
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

/// Test-only Ogg page checksum, written independently of production code
/// from RFC 3533 / libogg: CRC-32 with polynomial `0x04C11DB7`, processed
/// MSB-first (non-reflected), initial value 0 and no final XOR, computed over
/// the whole page with the CRC field (bytes 22..25) set to zero.
int _referencePageCrc(List<int> page) {
  final zeroed = List<int>.of(page)..setRange(22, 26, const [0, 0, 0, 0]);
  return _referenceCrc32(zeroed);
}

/// Table-driven MSB-first CRC-32 reference (poly `0x04C11DB7`, init 0, no
/// reflection, no final XOR). The table is generated here, not shared with
/// production code, so it acts as an independent oracle.
int _referenceCrc32(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc = ((crc << 8) & 0xFFFFFFFF) ^
        _referenceTable[((crc >> 24) ^ byte) & 0xFF];
  }
  return crc;
}

final List<int> _referenceTable = List<int>.generate(256, (index) {
  var value = index << 24;
  for (var bit = 0; bit < 8; bit++) {
    value = (value & 0x80000000) != 0
        ? ((value << 1) ^ 0x04C11DB7) & 0xFFFFFFFF
        : (value << 1) & 0xFFFFFFFF;
  }
  return value;
});
