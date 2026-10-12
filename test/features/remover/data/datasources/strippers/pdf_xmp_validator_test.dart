import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_xmp_packet_parser.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_xmp_validator.dart';

void main() {
  group('findPdfXmpPacketRanges', () {
    test('reports the content range between both instructions', () {
      const text = '%PDF-1.4\n$_begin<x:xmpmeta/>$_end\n%%EOF';
      final ranges = findPdfXmpPacketRanges(text);

      expect(ranges, hasLength(1));
      expect(
        text.substring(ranges.single.start, ranges.single.end),
        '<x:xmpmeta/>',
      );
    });

    test('returns no range when the payload has no packet', () {
      expect(findPdfXmpPacketRanges('%PDF-1.4\n/Title (a)\n%%EOF'), isEmpty);
    });

    test('fails closed on a missing end instruction', () {
      expect(
        () => findPdfXmpPacketRanges('%PDF-1.4\n$_begin<x:xmpmeta/>\n%%EOF'),
        throwsFormatException,
      );
    });

    test('fails closed on a nested begin instruction', () {
      expect(
        () => findPdfXmpPacketRanges('%PDF-1.4\n$_begin$_begin$_end\n%%EOF'),
        throwsFormatException,
      );
    });

    test('fails closed on an end instruction without a begin', () {
      expect(
        () => findPdfXmpPacketRanges('%PDF-1.4\n$_end\n%%EOF'),
        throwsFormatException,
      );
    });

    test('fails closed on a truncated instruction', () {
      expect(
        () => findPdfXmpPacketRanges('%PDF-1.4\n<?xpacket begin=""'),
        throwsFormatException,
      );
    });

    test('fails closed on an unrecognized instruction body', () {
      expect(
        () => findPdfXmpPacketRanges('%PDF-1.4\n<?xpacket wat?>\n%%EOF'),
        throwsFormatException,
      );
    });

    test('fails closed above the packet occurrence cap', () {
      final packets = List.filled(
        maxPdfXmpPacketOccurrences + 1,
        '$_begin x $_end',
      ).join();

      expect(
        () => findPdfXmpPacketRanges('%PDF-1.4\n$packets\n%%EOF'),
        throwsFormatException,
      );
    });
  });

  group('validateGeneratedPdfXmpMutation', () {
    test('accepts a blanked packet that keeps its instructions', () {
      final input = _bytes('%PDF-1.4\n$_begin<x:xmpmeta/>$_end\n%%EOF');
      final output = _bytes(
        '%PDF-1.4\n$_begin${' ' * '<x:xmpmeta/>'.length}$_end\n%%EOF',
      );

      expect(
        () => validateGeneratedPdfXmpMutation(input, output),
        returnsNormally,
      );
    });

    test('rejects surviving packet content', () {
      final input = _bytes('%PDF-1.4\n$_begin<x:xmpmeta/>$_end\n%%EOF');

      expect(
        () => validateGeneratedPdfXmpMutation(input, input),
        throwsFormatException,
      );
    });

    test('rejects a length change', () {
      final input = _bytes('%PDF-1.4\n$_begin<x/>$_end\n%%EOF');
      final output = _bytes('%PDF-1.4\n$_begin$_end\n%%EOF');

      expect(
        () => validateGeneratedPdfXmpMutation(input, output),
        throwsFormatException,
      );
    });

    test('rejects a damaged packet instruction', () {
      final input = _bytes('%PDF-1.4\n$_begin<x/>$_end\n%%EOF');
      final output = Uint8List.fromList(input);
      final markerAt = latin1.decode(input).indexOf(_end);
      output.fillRange(markerAt, markerAt + _end.length, 0x20);

      expect(
        () => validateGeneratedPdfXmpMutation(input, output),
        throwsFormatException,
      );
    });

    test('accepts a PDF without any packet', () {
      final bytes = _bytes('%PDF-1.4\n/Title (a)\n%%EOF');

      expect(
        () => validateGeneratedPdfXmpMutation(bytes, bytes),
        returnsNormally,
      );
    });
  });
}

const _begin = '<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>';
const _end = '<?xpacket end="w"?>';

Uint8List _bytes(String value) => Uint8List.fromList(latin1.encode(value));
