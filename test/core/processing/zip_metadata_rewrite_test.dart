import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/supported_extensions.dart';
import 'package:metastrip/core/processing/zip_repack.dart';

void main() {
  group('rewriteZipMetadata', () {
    test('removes EOCD and central-entry comments', () {
      final output = rewriteZipMetadata(_fixture());
      final zip = _readZip(output);

      expect(zip.archiveComment, isEmpty);
      expect(zip.entries.map((entry) => entry.comment), everyElement(isEmpty));
    });

    test('normalizes local and central DOS date/time to the ZIP epoch', () {
      final zip = _readZip(rewriteZipMetadata(_fixture()));

      for (final entry in zip.entries) {
        expect(entry.localTime, 0);
        expect(entry.localDate, 0x21);
        expect(entry.centralTime, 0);
        expect(entry.centralDate, 0x21);
      }
    });

    test('removes framed timestamp extras and preserves unknown extras', () {
      final zip = _readZip(rewriteZipMetadata(_fixture()));

      for (final entry in zip.entries) {
        expect(entry.localExtras[0x1234], [1, 2, 3, 4]);
        expect(entry.centralExtras[0x1234], [1, 2, 3, 4]);
        expect(entry.localExtras, isNot(contains(0x5455)));
        expect(entry.localExtras, isNot(contains(0x000a)));
        expect(entry.centralExtras, isNot(contains(0x5455)));
        expect(entry.centralExtras, isNot(contains(0x000a)));
      }
    });

    test('preserves compressed bytes, CRC, sizes, names, order, and payload',
        () {
      final before = _readZip(_fixture());
      final after = _readZip(rewriteZipMetadata(_fixture()));

      expect(after.entries, hasLength(before.entries.length));
      for (var i = 0; i < before.entries.length; i++) {
        final expected = before.entries[i];
        final actual = after.entries[i];
        expect(actual.name, expected.name);
        expect(actual.compressedPayload, expected.compressedPayload);
        expect(actual.crc, expected.crc);
        expect(actual.compressedSize, expected.compressedSize);
        expect(actual.uncompressedSize, expected.uncompressedSize);
      }
    });

    test('rejects malformed and unsafe archives through existing guards', () {
      final malformed = _fixture();
      _set16(malformed, _findEocd(malformed) + 20, 1);
      expect(() => rewriteZipMetadata(malformed), throwsFormatException);

      expect(
        () => rewriteZipMetadata(_fixture(firstName: '../unsafe.bin')),
        throwsFormatException,
      );

      final malformedExtra = _fixture();
      final firstExtra = 30 + _u16at(malformedExtra, 26);
      _set16(malformedExtra, firstExtra + 2, 0xffff);
      expect(() => rewriteZipMetadata(malformedExtra), throwsFormatException);
    });

    test('rejects a prepended local-header gap', () {
      final bytes = rewriteZipMetadata(_fixture()).toList();
      bytes.insert(0, 0x7f);
      _set32(
        bytes,
        _findEocd(bytes) + 16,
        _u32at(bytes, _findEocd(bytes) + 16) + 1,
      );
      _set32(bytes, _centralOffset(bytes) + 42, 1);
      expect(() => validateCanonicalZipMetadata(Uint8List.fromList(bytes)),
          throwsFormatException);
    });

    test('rejects a gap between physically ordered local records', () {
      final bytes = rewriteZipMetadata(_fixture()).toList();
      final directory = _centralOffset(bytes);
      final secondCentral = directory +
          46 +
          _u16at(bytes, directory + 28) +
          _u16at(bytes, directory + 30) +
          _u16at(bytes, directory + 32);
      final secondLocal = _u32at(bytes, secondCentral + 42);
      bytes.insert(secondLocal, 0x7f);
      _set32(bytes, secondCentral + 43, secondLocal + 1);
      _set32(bytes, _findEocd(bytes) + 16, directory + 1);
      expect(() => validateCanonicalZipMetadata(Uint8List.fromList(bytes)),
          throwsFormatException);
    });

    test('rejects a gap before the central directory', () {
      final bytes = rewriteZipMetadata(_fixture()).toList();
      final directory = _centralOffset(bytes);
      bytes.insert(directory, 0x7f);
      _set32(bytes, _findEocd(bytes) + 16, directory + 1);
      expect(() => validateCanonicalZipMetadata(Uint8List.fromList(bytes)),
          throwsFormatException);
    });

    test('validator rejects a nonzero EOCD comment', () {
      final bytes = rewriteZipMetadata(_fixture()).toList();
      final eocd = _findEocd(Uint8List.fromList(bytes));
      bytes.add(0x7f);
      bytes[eocd + 20] = 1;
      bytes[eocd + 21] = 0;
      expect(() => validateCanonicalZipMetadata(Uint8List.fromList(bytes)),
          throwsFormatException);
    });

    test('adds APK and EPUB to the archive remover contract', () {
      expect(RemoverStrippableExtensions.contains('zip'), isTrue);
      expect(RemoverStrippableExtensions.contains('apk'), isTrue);
      expect(RemoverStrippableExtensions.contains('epub'), isTrue);
    });
  });
}

Uint8List _fixture({String firstName = 'first.bin'}) {
  final first = _entry(firstName, [0x10, 0x20, 0x30, 0x40], localOffset: 0);
  final second = _entry(
    'second.bin',
    [0x99, 0x88, 0x77],
    localOffset: first.local.length,
  );
  final bytes = BytesBuilder(copy: false)
    ..add(first.local)
    ..add(second.local);
  final centralOffset = bytes.length;
  bytes
    ..add(first.central)
    ..add(second.central);
  final centralSize = bytes.length - centralOffset;
  bytes
    ..add(_u32(0x06054b50))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(2))
    ..add(_u16(2))
    ..add(_u32(centralSize))
    ..add(_u32(centralOffset));
  final comment = utf8.encode('archive-comment');
  bytes
    ..add(_u16(comment.length))
    ..add(comment);
  return bytes.toBytes();
}

_BuiltEntry _entry(
  String name,
  List<int> payload, {
  required int localOffset,
}) {
  final nameBytes = utf8.encode(name);
  final crc = _crc32(payload);
  final extra = <int>[
    ..._extra(0x1234, [1, 2, 3, 4]),
    ..._extra(0x5455, [7, 0, 0, 0, 0]),
    ..._extra(0x000a, [8, 9, 10, 11]),
  ];
  final local = <int>[
    ..._u32(0x04034b50),
    ..._u16(20),
    ..._u16(0x800),
    ..._u16(0),
    ..._u16(0x5a7b),
    ..._u16(0x4a21),
    ..._u32(crc),
    ..._u32(payload.length),
    ..._u32(payload.length),
    ..._u16(nameBytes.length),
    ..._u16(extra.length),
    ...nameBytes,
    ...extra,
    ...payload,
  ];
  final central = <int>[
    ..._u32(0x02014b50),
    ..._u16(20),
    ..._u16(20),
    ..._u16(0x800),
    ..._u16(0),
    ..._u16(0x5a7b),
    ..._u16(0x4a21),
    ..._u32(crc),
    ..._u32(payload.length),
    ..._u32(payload.length),
    ..._u16(nameBytes.length),
    ..._u16(extra.length),
    ..._u16(13),
    ..._u16(0),
    ..._u16(0),
    ..._u32(0),
    ..._u32(localOffset),
    ...nameBytes,
    ...extra,
    ...utf8.encode('entry-comment'),
  ];
  return _BuiltEntry(local, central);
}

List<int> _extra(int id, List<int> data) => [
      ..._u16(id),
      ..._u16(data.length),
      ...data,
    ];

List<int> _u16(int value) => [value & 0xff, (value >> 8) & 0xff];
List<int> _u32(int value) => [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];

void _set16(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint16(offset, value, Endian.little);
}

void _set32(List<int> bytes, int offset, int value) {
  for (var i = 0; i < 4; i++) {
    bytes[offset + i] = (value >> (8 * i)) & 0xff;
  }
}

int _centralOffset(List<int> bytes) => _u32at(bytes, _findEocd(bytes) + 16);

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc >> 1) ^ (0xedb88320 * (crc & 1));
    }
  }
  return crc ^ 0xffffffff;
}

class _BuiltEntry {
  const _BuiltEntry(this.local, this.central);
  final List<int> local;
  final List<int> central;
}

class _Zip {
  const _Zip(this.archiveComment, this.entries);
  final List<int> archiveComment;
  final List<_Entry> entries;
}

class _Entry {
  const _Entry({
    required this.name,
    required this.comment,
    required this.localTime,
    required this.localDate,
    required this.centralTime,
    required this.centralDate,
    required this.localExtras,
    required this.centralExtras,
    required this.compressedPayload,
    required this.crc,
    required this.compressedSize,
    required this.uncompressedSize,
  });
  final String name;
  final List<int> comment, compressedPayload;
  final Map<int, List<int>> localExtras, centralExtras;
  final int localTime,
      localDate,
      centralTime,
      centralDate,
      crc,
      compressedSize,
      uncompressedSize;
}

_Zip _readZip(Uint8List bytes) {
  final eocd = _findEocd(bytes);
  final count = _u16at(bytes, eocd + 10);
  var cursor = _u32at(bytes, eocd + 16);
  final entries = <_Entry>[];
  for (var i = 0; i < count; i++) {
    final nameLength = _u16at(bytes, cursor + 28);
    final extraLength = _u16at(bytes, cursor + 30);
    final commentLength = _u16at(bytes, cursor + 32);
    final localOffset = _u32at(bytes, cursor + 42);
    final name =
        utf8.decode(bytes.sublist(cursor + 46, cursor + 46 + nameLength));
    final centralExtra = bytes.sublist(
        cursor + 46 + nameLength, cursor + 46 + nameLength + extraLength);
    final localNameLength = _u16at(bytes, localOffset + 26);
    final localExtraLength = _u16at(bytes, localOffset + 28);
    final dataStart = localOffset + 30 + localNameLength + localExtraLength;
    entries.add(_Entry(
      name: name,
      comment: bytes.sublist(cursor + 46 + nameLength + extraLength,
          cursor + 46 + nameLength + extraLength + commentLength),
      localTime: _u16at(bytes, localOffset + 10),
      localDate: _u16at(bytes, localOffset + 12),
      centralTime: _u16at(bytes, cursor + 12),
      centralDate: _u16at(bytes, cursor + 14),
      localExtras:
          _extras(bytes.sublist(localOffset + 30 + localNameLength, dataStart)),
      centralExtras: _extras(centralExtra),
      compressedPayload:
          bytes.sublist(dataStart, dataStart + _u32at(bytes, cursor + 20)),
      crc: _u32at(bytes, cursor + 16),
      compressedSize: _u32at(bytes, cursor + 20),
      uncompressedSize: _u32at(bytes, cursor + 24),
    ));
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  return _Zip(bytes.sublist(eocd + 22, bytes.length), entries);
}

Map<int, List<int>> _extras(List<int> extra) {
  final fields = <int, List<int>>{};
  for (var i = 0; i < extra.length;) {
    final id = extra[i] | extra[i + 1] << 8;
    final length = extra[i + 2] | extra[i + 3] << 8;
    fields[id] = extra.sublist(i + 4, i + 4 + length);
    i += 4 + length;
  }
  return fields;
}

int _u16at(List<int> bytes, int offset) =>
    bytes[offset] | bytes[offset + 1] << 8;
int _u32at(List<int> bytes, int offset) =>
    bytes[offset] |
    bytes[offset + 1] << 8 |
    bytes[offset + 2] << 16 |
    bytes[offset + 3] << 24;

int _findEocd(List<int> bytes) {
  for (var i = bytes.length - 22; i >= 0; i--) {
    if (_u32at(bytes, i) == 0x06054b50) return i;
  }
  throw StateError('EOCD not found');
}
