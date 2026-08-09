import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

const _flacMagicLength = 4;
const _blockHeaderLength = 4;
const _vorbisCommentType = 4;
const _maxVorbisKeyBytes = 1024;

/// A structural FLAC snapshot backed by the bytes that were parsed.
///
/// Metadata blocks and the audio suffix are represented by ranges rather than
/// copies. Audio frames are deliberately not decoded.
class FlacSnapshot {
  const FlacSnapshot({
    required this.source,
    required this.blocks,
    required this.comments,
    required this.audioOffset,
  });

  final Uint8List source;
  final List<FlacBlockSnapshot> blocks;
  final List<FlacCommentSnapshot> comments;
  final int audioOffset;

  int get audioLength => source.length - audioOffset;
}

class FlacBlockSnapshot {
  const FlacBlockSnapshot({
    required this.type,
    required this.isLast,
    required this.offset,
    required this.length,
  });

  final int type;
  final bool isLast;
  final int offset;
  final int length;
}

class FlacCommentSnapshot {
  const FlacCommentSnapshot({
    required this.vendorOffset,
    required this.vendorLength,
    required this.entries,
  });

  final int vendorOffset;
  final int vendorLength;
  final List<FlacCommentEntrySnapshot> entries;
}

class FlacCommentEntrySnapshot {
  const FlacCommentEntrySnapshot({
    required this.offset,
    required this.length,
    required this.key,
  });

  final int offset;
  final int length;
  final String key;
}

FlacSnapshot parseFlacStructure(Uint8List bytes) {
  if (bytes.length < _flacMagicLength ||
      !_asciiEquals(bytes, 0, const [0x66, 0x4C, 0x61, 0x43])) {
    throw const FormatException('Not a valid FLAC file');
  }
  final blocks = <FlacBlockSnapshot>[];
  final comments = <FlacCommentSnapshot>[];
  var offset = _flacMagicLength;
  var sawLast = false;
  var sawStreamInfo = false;
  while (!sawLast) {
    if (offset + _blockHeaderLength > bytes.length) {
      throw const FormatException('FLAC metadata has no final block');
    }
    final flags = bytes[offset];
    final type = flags & 0x7F;
    if (type >= 7) throw const FormatException('Reserved FLAC block type');
    final size = (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final end = offset + _blockHeaderLength + size;
    if (end > bytes.length) {
      throw const FormatException('Truncated FLAC metadata block');
    }
    final isLast = flags & 0x80 != 0;
    if (blocks.isEmpty && (type != 0 || size != 34)) {
      throw const FormatException('FLAC must start with canonical STREAMINFO');
    }
    if (type == 0) {
      if (sawStreamInfo) {
        throw const FormatException('Duplicate FLAC STREAMINFO block');
      }
      sawStreamInfo = true;
    }
    blocks.add(
      FlacBlockSnapshot(
        type: type,
        isLast: isLast,
        offset: offset,
        length: end - offset,
      ),
    );
    if (type == _vorbisCommentType) {
      comments.add(_parseComment(bytes, offset + _blockHeaderLength, end));
    }
    sawLast = isLast;
    offset = end;
  }
  if (blocks.isEmpty) throw const FormatException('FLAC has no metadata');
  return FlacSnapshot(
    source: bytes,
    blocks: List.unmodifiable(blocks),
    comments: List.unmodifiable(comments),
    audioOffset: offset,
  );
}

FlacCommentSnapshot _parseComment(Uint8List source, int start, int end) {
  if (end - start < 8) {
    throw const FormatException('Malformed FLAC comments');
  }
  final view = ByteData.sublistView(source);
  var offset = start;
  final vendorLength = view.getUint32(offset, Endian.little);
  offset += 4;
  if (vendorLength > end - offset || offset + vendorLength + 4 > end) {
    throw const FormatException('Malformed FLAC comments');
  }
  final vendorOffset = offset;
  _validateUtf8(source, offset, offset + vendorLength);
  offset += vendorLength;
  final count = view.getUint32(offset, Endian.little);
  offset += 4;
  final entries = <FlacCommentEntrySnapshot>[];
  for (var i = 0; i < count; i++) {
    if (offset + 4 > end) {
      throw const FormatException('Malformed FLAC comments');
    }
    final length = view.getUint32(offset, Endian.little);
    offset += 4;
    if (length > end - offset) {
      throw const FormatException('Malformed FLAC comments');
    }
    final entryOffset = offset;
    final entryEnd = offset + length;
    final equals = _indexOfByte(source, 0x3D, entryOffset, entryEnd);
    if (equals <= entryOffset) {
      throw const FormatException('Malformed FLAC comment entry');
    }
    final keyLength = equals - entryOffset;
    if (keyLength > _maxVorbisKeyBytes) {
      throw const FormatException('FLAC comment key is too long');
    }
    _validateUtf8(source, entryOffset, entryEnd);
    final key = MetadataFieldId.normalizeVorbisCommentKey(
      utf8.decode(Uint8List.sublistView(source, entryOffset, equals)),
    );
    entries.add(
      FlacCommentEntrySnapshot(
        offset: entryOffset,
        length: length,
        key: key,
      ),
    );
    offset = entryEnd;
  }
  if (offset != end) throw const FormatException('Malformed FLAC comments');
  return FlacCommentSnapshot(
    vendorOffset: vendorOffset,
    vendorLength: vendorLength,
    entries: List.unmodifiable(entries),
  );
}

/// Verifies selective mutation facts. Audio frame decoding is deliberately out
/// of scope: this is structural, comment, and persistence validation only.
void validateFlacSelectivePreservation(
  Uint8List original,
  Uint8List generated, {
  required Set<String> selectedKeys,
  Uint8List? persisted,
}) {
  final before = parseFlacStructure(original);
  final after = parseFlacStructure(generated);
  final selected =
      selectedKeys.map(MetadataFieldId.normalizeVorbisCommentKey).toSet();
  _compareFlacFacts(before, after, selected);
  if (persisted != null) {
    if (!_sameRange(generated, 0, persisted, 0, generated.length) ||
        generated.length != persisted.length) {
      throw const FormatException(
        'Persisted FLAC bytes differ from generated bytes',
      );
    }
    final saved = parseFlacStructure(persisted);
    _compareFlacFacts(before, saved, selected);
    _compareFlacFacts(after, saved, selected);
  }
}

void _compareFlacFacts(
  FlacSnapshot before,
  FlacSnapshot after,
  Set<String> selected,
) {
  if (before.blocks.length != after.blocks.length ||
      before.comments.length != after.comments.length) {
    throw const FormatException('FLAC metadata structure changed');
  }
  var commentIndex = 0;
  for (var i = 0; i < before.blocks.length; i++) {
    final oldBlock = before.blocks[i];
    final newBlock = after.blocks[i];
    if (oldBlock.type != newBlock.type || oldBlock.isLast != newBlock.isLast) {
      throw const FormatException('FLAC metadata structure changed');
    }
    if (oldBlock.type != _vorbisCommentType &&
        !_sameRange(
          before.source,
          oldBlock.offset,
          after.source,
          newBlock.offset,
          oldBlock.length,
        )) {
      throw const FormatException('FLAC non-comment metadata changed');
    }
    if (oldBlock.type != _vorbisCommentType &&
        oldBlock.length != newBlock.length) {
      throw const FormatException('FLAC non-comment metadata changed');
    }
    if (oldBlock.type == _vorbisCommentType) {
      _compareComment(
        before,
        before.comments[commentIndex],
        after,
        after.comments[commentIndex],
        selected,
      );
      commentIndex++;
    }
  }
  if (before.audioLength != after.audioLength ||
      !_sameRange(
        before.source,
        before.audioOffset,
        after.source,
        after.audioOffset,
        before.audioLength,
      )) {
    throw const FormatException('FLAC audio suffix changed');
  }
}

void _compareComment(
  FlacSnapshot before,
  FlacCommentSnapshot oldComment,
  FlacSnapshot after,
  FlacCommentSnapshot newComment,
  Set<String> selected,
) {
  if (oldComment.vendorLength != newComment.vendorLength ||
      !_sameRange(
        before.source,
        oldComment.vendorOffset,
        after.source,
        newComment.vendorOffset,
        oldComment.vendorLength,
      )) {
    throw const FormatException('FLAC comment vendor changed');
  }
  var newIndex = 0;
  for (final oldEntry in oldComment.entries) {
    if (selected.contains(oldEntry.key)) continue;
    if (newIndex >= newComment.entries.length) {
      throw const FormatException('FLAC unselected comments changed');
    }
    final newEntry = newComment.entries[newIndex++];
    if (oldEntry.length != newEntry.length ||
        !_sameRange(
          before.source,
          oldEntry.offset,
          after.source,
          newEntry.offset,
          oldEntry.length,
        )) {
      throw const FormatException('FLAC unselected comments changed');
    }
  }
  if (newIndex != newComment.entries.length) {
    throw const FormatException('FLAC unselected comments changed');
  }
  for (final entry in newComment.entries) {
    if (selected.contains(entry.key)) {
      throw const FormatException('Selected FLAC comment remains');
    }
  }
}

bool _sameRange(
  Uint8List first,
  int firstOffset,
  Uint8List second,
  int secondOffset,
  int length,
) {
  if (firstOffset < 0 ||
      secondOffset < 0 ||
      length < 0 ||
      firstOffset + length > first.length ||
      secondOffset + length > second.length) {
    return false;
  }
  for (var i = 0; i < length; i++) {
    if (first[firstOffset + i] != second[secondOffset + i]) return false;
  }
  return true;
}

int _indexOfByte(Uint8List bytes, int value, int start, int end) {
  for (var i = start; i < end; i++) {
    if (bytes[i] == value) return i;
  }
  return -1;
}

void _validateUtf8(Uint8List bytes, int start, int end) {
  var offset = start;
  while (offset < end) {
    final first = bytes[offset++];
    if (first <= 0x7F) continue;
    final continuationCount = switch (first) {
      >= 0xC2 && <= 0xDF => 1,
      >= 0xE0 && <= 0xEF => 2,
      >= 0xF0 && <= 0xF4 => 3,
      _ => throw const FormatException('Malformed UTF-8 in FLAC comments'),
    };
    if (offset + continuationCount > end) {
      throw const FormatException('Malformed UTF-8 in FLAC comments');
    }
    final second = bytes[offset];
    if ((first == 0xE0 && second < 0xA0) ||
        (first == 0xED && second > 0x9F) ||
        (first == 0xF0 && second < 0x90) ||
        (first == 0xF4 && second > 0x8F)) {
      throw const FormatException('Malformed UTF-8 in FLAC comments');
    }
    for (var i = 0; i < continuationCount; i++) {
      if (bytes[offset++] & 0xC0 != 0x80) {
        throw const FormatException('Malformed UTF-8 in FLAC comments');
      }
    }
  }
}

bool _asciiEquals(Uint8List bytes, int offset, List<int> expected) {
  if (offset < 0 || offset + expected.length > bytes.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (bytes[offset + i] != expected[i]) return false;
  }
  return true;
}
