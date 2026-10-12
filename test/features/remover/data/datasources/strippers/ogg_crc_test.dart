import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/ogg_crc.dart';

void main() {
  group('oggCrc32', () {
    test(
        'oggCrc32 matches the CRC-32 (MSB-first, init 0, no xorout) check '
        'value', () {
      expect(oggCrc32(ascii.encode('123456789')), 0x89A1897F);
    });

    test('returns 0 for empty input', () {
      expect(oggCrc32(const []), 0);
    });
  });

  group('oggPageCrc', () {
    test('oggPageCrc zeroes the CRC field instead of skipping it', () {
      final page = _buildOggPage(
        crcBytes: const [0xDE, 0xAD, 0xBE, 0xEF],
        payload: ascii.encode('payload bytes'),
      );
      final zeroed = Uint8List.fromList(page)..setRange(22, 26, [0, 0, 0, 0]);
      final skipped = <int>[...page.take(22), ...page.skip(26)];

      expect(oggPageCrc(page), oggCrc32(zeroed));
      expect(oggPageCrc(page), isNot(oggCrc32(skipped)));
    });

    test('ignores whatever is currently stored in the CRC field', () {
      final payload = ascii.encode('same payload');
      final a = _buildOggPage(crcBytes: const [0, 0, 0, 0], payload: payload);
      final b = _buildOggPage(
        crcBytes: const [0xFF, 0x01, 0x80, 0x7F],
        payload: payload,
      );

      expect(oggPageCrc(a), oggPageCrc(b));
    });

    test('does not mutate the page', () {
      final page = _buildOggPage(
        crcBytes: const [1, 2, 3, 4],
        payload: const [9, 8, 7],
      );
      final copy = Uint8List.fromList(page);

      oggPageCrc(page);

      expect(page, copy);
    });

    test('rejects a buffer shorter than an Ogg page header', () {
      expect(() => oggPageCrc(Uint8List(26)), throwsFormatException);
    });
  });
}

/// Builds a single-segment Ogg page storing [crcBytes] verbatim at 22..25.
Uint8List _buildOggPage({
  required List<int> crcBytes,
  required List<int> payload,
}) {
  return Uint8List.fromList([
    ...ascii.encode('OggS'),
    0x00, // version
    0x02, // BOS
    ...List<int>.filled(8, 0), // granule position
    0x78, 0x56, 0x34, 0x12, // serial
    0x00, 0x00, 0x00, 0x00, // sequence
    ...crcBytes,
    0x01, // segment count
    payload.length,
    ...payload,
  ]);
}
