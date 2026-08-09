import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/wav_info_selective_stripper.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/riff_info_descriptor.dart';

void main() {
  test('shared allowlist exposes exactly the eleven stable WAV INFO codes', () {
    expect(
      wavInfoDescriptors.values.map((descriptor) => descriptor.code).toSet(),
      {
        'INAM',
        'ICOP',
        'ICRD',
        'IGNR',
        'IART',
        'ICMT',
        'ISFT',
        'ISBJ',
        'IENG',
        'IKEY',
        'IRL ',
      },
    );
    for (final id in wavInfoDescriptors.keys) {
      expect(MetadataFieldId.parse(id.value), id);
      expect(id.isWavInfo, isTrue);
    }
  });

  test('removes all selected occurrences and preserves other chunks', () {
    final bytes = _wav([
      ('fmt ', List<int>.filled(3, 1)),
      (
        'LIST',
        [
          ...'INFO'.codeUnits,
          ..._chunk('INAM', 'one'),
          ..._chunk('INAM', 'two'),
          ..._chunk('IART', 'artist'),
          ..._chunk('XXXX', 'unknown'),
        ]
      ),
      ('LIST', [...'adtl'.codeUnits, ..._chunk('INAM', 'keep')]),
      ('bext', [1, 2, 3]),
      ('ID3 ', [...'ID3'.codeUnits, 0]),
      ('data', List<int>.filled(4, 9)),
    ]);

    final result = stripWavInfoSelective(
      bytes,
      selectedIds: {MetadataFieldId.wavInfoInam},
    );

    expect(result.removedIds, {MetadataFieldId.wavInfoInam});
    expect(result.absentIds, isEmpty);
    expect(String.fromCharCodes(result.bytes), contains('artist'));
    expect(String.fromCharCodes(result.bytes), contains('unknown'));
    expect(String.fromCharCodes(result.bytes), contains('keep'));
    expect(String.fromCharCodes(result.bytes), contains('bext'));
    expect(String.fromCharCodes(result.bytes), contains('ID3'));
    expect(String.fromCharCodes(result.bytes), isNot(contains('one')));
    expect(String.fromCharCodes(result.bytes), isNot(contains('two')));
    expect(
      ByteData.sublistView(result.bytes).getUint32(4, Endian.little),
      result.bytes.length - 8,
    );
  });

  test('removes selected duplicates across multiple INFO lists', () {
    final bytes = _wav([
      ('LIST', [...'INFO'.codeUnits, ..._chunk('INAM', 'one')]),
      (
        'LIST',
        [
          ...'INFO'.codeUnits,
          ..._chunk('IART', 'keep'),
          ..._chunk('INAM', 'two'),
          ..._chunk('INAM', 'three'),
        ]
      ),
      ('data', [1, 2]),
    ]);

    final result = stripWavInfoSelective(
      bytes,
      selectedIds: {MetadataFieldId.wavInfoInam},
    );
    final text = String.fromCharCodes(result.bytes);

    expect(text, isNot(contains('one')));
    expect(text, isNot(contains('two')));
    expect(text, isNot(contains('three')));
    expect(text, contains('keep'));
    expect(result.removedIds, {MetadataFieldId.wavInfoInam});
  });

  test('reports selected fields that were already absent', () {
    final bytes = _wav([
      ('fmt ', [1, 2]),
      ('data', [3, 4])
    ]);
    final result = stripWavInfoSelective(
      bytes,
      selectedIds: {MetadataFieldId.wavInfoIrl},
    );
    expect(identical(result.bytes, bytes), isTrue);
    expect(result.removedIds, isEmpty);
    expect(result.absentIds, {MetadataFieldId.wavInfoIrl});
  });

  test('fails closed for malformed nested INFO bounds and missing padding', () {
    final malformedList = _wav([
      ('LIST', [...'INFO'.codeUnits, ...'INAM'.codeUnits, ..._le32(99), 1]),
    ]);
    expect(
      () => stripWavInfoSelective(
        malformedList,
        selectedIds: {MetadataFieldId.wavInfoInam},
      ),
      throwsFormatException,
    );

    final valid = _wav([
      ('LIST', [...'INFO'.codeUnits, ..._chunk('INAM', 'x')])
    ]);
    final truncated = Uint8List.fromList(valid.sublist(0, valid.length - 1));
    ByteData.sublistView(truncated).setUint32(
      4,
      truncated.length - 8,
      Endian.little,
    );
    expect(
      () => stripWavInfoSelective(
        truncated,
        selectedIds: {MetadataFieldId.wavInfoInam},
      ),
      throwsFormatException,
    );
  });

  test('rejects RIFF declared size mismatches in both directions', () {
    final valid = _wav([
      ('data', [1, 2])
    ]);
    for (final declared in [valid.length - 9, valid.length - 7]) {
      final malformed = Uint8List.fromList(valid);
      ByteData.sublistView(malformed).setUint32(4, declared, Endian.little);
      expect(
        () => stripWavInfoSelective(
          malformed,
          selectedIds: {MetadataFieldId.wavInfoInam},
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects malformed top-level bounds and a missing top-level pad', () {
    final truncatedData = _wav([
      ('data', [1, 2])
    ]);
    ByteData.sublistView(truncatedData).setUint32(16, 3, Endian.little);
    expect(
      () => stripWavInfoSelective(
        truncatedData,
        selectedIds: {MetadataFieldId.wavInfoInam},
      ),
      throwsFormatException,
    );

    final validOdd = _wav([
      ('data', [1])
    ]);
    final missingPad =
        Uint8List.fromList(validOdd.sublist(0, validOdd.length - 1));
    ByteData.sublistView(missingPad).setUint32(
      4,
      missingPad.length - 8,
      Endian.little,
    );
    expect(
      () => stripWavInfoSelective(
        missingPad,
        selectedIds: {MetadataFieldId.wavInfoInam},
      ),
      throwsFormatException,
    );
  });

  test('accepts 512 chunks and rejects the 513th', () {
    final atLimit = _wav(List.generate(512, (_) => ('JUNK', <int>[])));
    final overLimit = _wav(List.generate(513, (_) => ('JUNK', <int>[])));

    expect(
      stripWavInfoSelective(
        atLimit,
        selectedIds: {MetadataFieldId.wavInfoInam},
      ).absentIds,
      {MetadataFieldId.wavInfoInam},
    );
    expect(
      () => stripWavInfoSelective(
        overLimit,
        selectedIds: {MetadataFieldId.wavInfoInam},
      ),
      throwsFormatException,
    );
  });

  test('checks the uint32 output-size range explicitly', () {
    expect(encodeWavUint32(0xFFFFFFFF), [0xFF, 0xFF, 0xFF, 0xFF]);
    expect(() => encodeWavUint32(0x100000000), throwsFormatException);
    expect(() => encodeWavUint32(-1), throwsFormatException);
  });
}

Uint8List _wav(List<(String, List<int>)> chunks) {
  final body = <int>[...'WAVE'.codeUnits];
  for (final chunk in chunks) {
    body.addAll(_containerChunk(chunk.$1, chunk.$2));
  }
  return Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._le32(body.length),
    ...body,
  ]);
}

List<int> _containerChunk(String id, List<int> data) => [
      ...id.padRight(4).codeUnits,
      ..._le32(data.length),
      ...data,
      if (data.length.isOdd) 0,
    ];

List<int> _chunk(String id, String value) =>
    _containerChunk(id, value.codeUnits);

List<int> _le32(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
