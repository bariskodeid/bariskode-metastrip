import 'dart:typed_data';

import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/riff_info_descriptor.dart';

const _headerLength = 12;
const _chunkHeaderLength = 8;
const _maxChunks = 512;
const _maxUint32 = 0xFFFFFFFF;

/// Value-free result of selective WAV `LIST INFO` mutation.
class WavInfoSelectiveResult {
  WavInfoSelectiveResult({
    required this.bytes,
    required Set<MetadataFieldId> removedIds,
    required Set<MetadataFieldId> absentIds,
  })  : removedIds = Set.unmodifiable(removedIds),
        absentIds = Set.unmodifiable(absentIds);

  final Uint8List bytes;
  final Set<MetadataFieldId> removedIds;
  final Set<MetadataFieldId> absentIds;
}

/// Removes every selected allowlisted occurrence from WAV `LIST INFO` chunks.
///
/// Unknown and unselected INFO subchunks, non-INFO LIST chunks, and every
/// unrelated top-level chunk are copied byte-for-byte. Malformed sizes,
/// inconsistent RIFF bounds, missing required pad bytes, and walk-limit
/// breaches fail closed.
WavInfoSelectiveResult stripWavInfoSelective(
  Uint8List bytes, {
  required Set<MetadataFieldId> selectedIds,
}) {
  _validateSelection(selectedIds);
  final rebuilt = _rebuildWithoutValidation(bytes, selectedIds);
  validateWavInfoSelective(
    bytes,
    rebuilt.bytes,
    selectedIds: selectedIds,
    expectedRemovedIds: rebuilt.removedIds,
  );
  return rebuilt;
}

/// Validates generated or locally persisted selective WAV output.
///
/// Rebuilding the expected mutation from the original enforces byte-for-byte
/// preservation of all content outside selected INFO subchunks. The output is
/// also independently walked before comparison so malformed persisted bytes
/// cannot pass by matching an unchecked artifact.
void validateWavInfoSelective(
  Uint8List original,
  Uint8List output, {
  required Set<MetadataFieldId> selectedIds,
  required Set<MetadataFieldId> expectedRemovedIds,
}) {
  _validateSelection(selectedIds);
  _walkChunks(output, start: _headerLength, end: output.length);
  final actualIds = _presentSelectedIds(output, selectedIds);
  if (actualIds.isNotEmpty) {
    throw const FormatException('Selected WAV INFO fields remain');
  }
  final rebuilt = _rebuildWithoutValidation(original, selectedIds);
  if (!_bytesEqual(rebuilt.bytes, output) ||
      !_setsEqual(rebuilt.removedIds, expectedRemovedIds)) {
    throw const FormatException('WAV selective preservation validation failed');
  }
}

WavInfoSelectiveResult _rebuildWithoutValidation(
  Uint8List bytes,
  Set<MetadataFieldId> selectedIds,
) {
  final selectedByCode = <String, MetadataFieldId>{
    for (final id in selectedIds) wavInfoDescriptors[id]!.code.padRight(4): id,
  };
  final removed = <MetadataFieldId>{};
  final output = BytesBuilder(copy: false)
    ..add(bytes.sublist(0, _headerLength));
  for (final chunk
      in _walkChunks(bytes, start: _headerLength, end: bytes.length)) {
    if (chunk.id != 'LIST' ||
        chunk.size < 4 ||
        !_asciiAt(bytes, chunk.dataStart, 'INFO')) {
      output.add(bytes.sublist(chunk.start, chunk.end));
      continue;
    }
    final payload = BytesBuilder(copy: false)..add('INFO'.codeUnits);
    for (final subchunk in _walkChunks(
      bytes,
      start: chunk.dataStart + 4,
      end: chunk.dataEnd,
    )) {
      final selected = selectedByCode[subchunk.id];
      if (selected == null) {
        payload.add(bytes.sublist(subchunk.start, subchunk.end));
      } else {
        removed.add(selected);
      }
    }
    final rebuiltPayload = payload.takeBytes();
    if (rebuiltPayload.length == chunk.size) {
      output.add(bytes.sublist(chunk.start, chunk.end));
    } else {
      output
        ..add('LIST'.codeUnits)
        ..add(encodeWavUint32(rebuiltPayload.length))
        ..add(rebuiltPayload);
      if (rebuiltPayload.length.isOdd) output.addByte(0);
    }
  }
  if (removed.isEmpty) {
    return WavInfoSelectiveResult(
      bytes: bytes,
      removedIds: const {},
      absentIds: selectedIds,
    );
  }
  final result = output.takeBytes();
  _checkUint32(result.length - 8);
  ByteData.sublistView(result).setUint32(4, result.length - 8, Endian.little);
  return WavInfoSelectiveResult(
    bytes: result,
    removedIds: removed,
    absentIds: selectedIds.difference(removed),
  );
}

Set<MetadataFieldId> _presentSelectedIds(
  Uint8List bytes,
  Set<MetadataFieldId> selectedIds,
) {
  final idsByCode = <String, MetadataFieldId>{
    for (final id in selectedIds) wavInfoDescriptors[id]!.code.padRight(4): id,
  };
  final present = <MetadataFieldId>{};
  for (final chunk
      in _walkChunks(bytes, start: _headerLength, end: bytes.length)) {
    if (chunk.id != 'LIST' ||
        chunk.size < 4 ||
        !_asciiAt(bytes, chunk.dataStart, 'INFO')) {
      continue;
    }
    for (final subchunk in _walkChunks(
      bytes,
      start: chunk.dataStart + 4,
      end: chunk.dataEnd,
    )) {
      final id = idsByCode[subchunk.id];
      if (id != null) present.add(id);
    }
  }
  return present;
}

void _validateSelection(Set<MetadataFieldId> selectedIds) {
  if (selectedIds.isEmpty) {
    throw const FormatException('No metadata fields selected');
  }
  if (!selectedIds.every(wavInfoDescriptors.containsKey)) {
    throw const FormatException('Unsupported selective metadata field');
  }
}

List<_Chunk> _walkChunks(
  Uint8List bytes, {
  required int start,
  required int end,
}) {
  if (start == _headerLength) {
    if (bytes.length < _headerLength ||
        !_asciiAt(bytes, 0, 'RIFF') ||
        !_asciiAt(bytes, 8, 'WAVE')) {
      throw const FormatException('Not a valid WAV file');
    }
    final declared =
        ByteData.sublistView(bytes, 4, 8).getUint32(0, Endian.little);
    if (declared != bytes.length - 8) {
      throw const FormatException('Invalid WAV RIFF bounds');
    }
  }
  if (start > end || end > bytes.length) {
    throw const FormatException('Invalid WAV chunk bounds');
  }
  final chunks = <_Chunk>[];
  var offset = start;
  while (offset < end) {
    if (chunks.length >= _maxChunks) {
      throw const FormatException('RIFF chunk walk limit exceeded');
    }
    if (offset + _chunkHeaderLength > end) {
      throw const FormatException('Truncated WAV chunk header');
    }
    final size = ByteData.sublistView(bytes, offset + 4, offset + 8)
        .getUint32(0, Endian.little);
    final dataStart = offset + _chunkHeaderLength;
    final dataEnd = dataStart + size;
    if (dataEnd > end) {
      throw const FormatException('Truncated WAV chunk data');
    }
    final chunkEnd = dataEnd + (size.isOdd ? 1 : 0);
    if (chunkEnd > end) {
      throw const FormatException('Missing WAV chunk pad byte');
    }
    chunks.add(
      _Chunk(
        id: String.fromCharCodes(bytes.sublist(offset, offset + 4)),
        start: offset,
        dataStart: dataStart,
        dataEnd: dataEnd,
        end: chunkEnd,
        size: size,
      ),
    );
    offset = chunkEnd;
  }
  return chunks;
}

bool _asciiAt(Uint8List bytes, int offset, String value) {
  if (offset < 0 || offset + value.length > bytes.length) return false;
  for (var index = 0; index < value.length; index++) {
    if (bytes[offset + index] != value.codeUnitAt(index)) return false;
  }
  return true;
}

/// Encodes a checked unsigned 32-bit WAV size in little-endian order.
///
/// Kept public so the output-size boundary can be tested without allocating a
/// multi-gigabyte RIFF artifact.
Uint8List encodeWavUint32(int value) {
  _checkUint32(value);
  return Uint8List.fromList([
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}

void _checkUint32(int value) {
  if (value < 0 || value > _maxUint32) {
    throw const FormatException('WAV output exceeds uint32 size range');
  }
}

bool _bytesEqual(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _setsEqual<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

class _Chunk {
  const _Chunk({
    required this.id,
    required this.start,
    required this.dataStart,
    required this.dataEnd,
    required this.end,
    required this.size,
  });

  final String id;
  final int start;
  final int dataStart;
  final int dataEnd;
  final int end;
  final int size;
}
