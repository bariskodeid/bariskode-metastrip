import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/riff_info_descriptor.dart';

/// Human labels for AIFF chunks (four-character code to readable label).
const Map<String, String> _aiffLabels = {
  'NAME': 'Title',
  'AUTH': 'Author',
  '(c) ': 'Copyright',
};

/// Maximum number of chunks scanned within one container defensively.
const int _maxChunks = 64;

/// Extracts RIFF metadata from raw [bytes] for the given [extension].
///
/// Handles the WAV (`RIFF...WAVE` with `LIST INFO` sub-chunks) and AIFF
/// (`FORM...AIFF`) formats, surfacing known metadata chunks plus any embedded
/// `ID3` payload. Returns a status field when the container is invalid or has
/// no metadata; this function never throws.
Future<List<MetadataFieldEntity>> extractRiff(
  Uint8List bytes, {
  required String extension,
}) async {
  try {
    final ext = extension.toLowerCase();
    if (ext == 'wav') return _extractWav(bytes);
    if (ext == 'aiff' || ext == 'aif' || ext == 'aifc') {
      return _extractAiff(bytes);
    }
    return [
      statusField('Audio RIFF', 'Status', 'Not a valid RIFF file'),
    ];
  } catch (_) {
    return [
      statusField('Audio RIFF', 'Status', 'Not a valid RIFF file'),
    ];
  }
}

/// Parses a WAV file (`RIFF`/`WAVE`) and its `LIST`/`ID3`/`bext` chunks.
List<MetadataFieldEntity> _extractWav(Uint8List bytes) {
  if (!_asciiAt(bytes, 0, 'RIFF') || !_asciiAt(bytes, 8, 'WAVE')) {
    return [
      statusField('Audio RIFF', 'Status', 'Not a valid RIFF file'),
    ];
  }

  final fields = <MetadataFieldEntity>[];
  var offset = 12;
  for (var i = 0; i < _maxChunks && offset + 8 <= bytes.length; i++) {
    final size = ByteData.sublistView(
      bytes,
      offset + 4,
      offset + 8,
    ).getUint32(0, Endian.little);
    final dataStart = offset + 8;
    final dataEnd = dataStart + size;
    if (dataEnd > bytes.length) break;

    final id = _chunkId(bytes, offset);
    if (id == 'LIST') {
      _parseInfoList(bytes.sublist(dataStart, dataEnd), fields);
    } else if (id == 'ID3 ') {
      _addText(fields, 'ID3', bytes.sublist(dataStart, dataEnd));
    } else if (id == 'bext') {
      _addText(
        fields,
        'Broadcast Extension',
        bytes.sublist(dataStart, dataEnd),
      );
    }

    offset = dataEnd;
    if (size.isOdd) offset++; // pad byte alignment
  }

  if (fields.isEmpty) {
    return [
      statusField('Audio RIFF', 'Status', 'No RIFF metadata found'),
    ];
  }
  return fields;
}

/// Parses an AIFF file (`FORM`/`AIFF`) and its text chunks.
List<MetadataFieldEntity> _extractAiff(Uint8List bytes) {
  if (!_asciiAt(bytes, 0, 'FORM') || !_asciiAt(bytes, 8, 'AIFF')) {
    return [
      statusField('Audio RIFF', 'Status', 'Not a valid RIFF file'),
    ];
  }

  final fields = <MetadataFieldEntity>[];
  var offset = 12;
  for (var i = 0; i < _maxChunks && offset + 8 <= bytes.length; i++) {
    final size = ByteData.sublistView(
      bytes,
      offset + 4,
      offset + 8,
    ).getUint32(0, Endian.big);
    final dataStart = offset + 8;
    final dataEnd = dataStart + size;
    if (dataEnd > bytes.length) break;

    final id = _chunkId(bytes, offset);
    final label = _aiffLabels[id];
    if (label != null) {
      _addText(fields, label, bytes.sublist(dataStart, dataEnd));
    } else if (id == 'ID3 ') {
      _addText(fields, 'ID3', bytes.sublist(dataStart, dataEnd));
    }

    offset = dataEnd;
    if (size.isOdd) offset++; // pad byte alignment
  }

  if (fields.isEmpty) {
    return [
      statusField('Audio RIFF', 'Status', 'No RIFF metadata found'),
    ];
  }
  return fields;
}

/// Reads the four-byte chunk identifier at [offset] as ASCII.
String _chunkId(Uint8List bytes, int offset) {
  return String.fromCharCodes(bytes.sublist(offset, offset + 4));
}

/// Parses the contents of a `LIST` chunk, handling the `INFO` sub-format.
///
/// [content] starts with the four-byte list type; `INFO` sub-chunks use the
/// little-endian RIFF convention and may be padded to even lengths.
void _parseInfoList(Uint8List content, List<MetadataFieldEntity> fields) {
  if (content.length < 4 || !_asciiAt(content, 0, 'INFO')) return;

  var offset = 4;
  for (var i = 0; i < _maxChunks && offset + 8 <= content.length; i++) {
    final subId = String.fromCharCodes(
      content.sublist(offset, offset + 4),
    );
    final size = ByteData.sublistView(
      content,
      offset + 4,
      offset + 8,
    ).getUint32(0, Endian.little);
    final dataStart = offset + 8;
    final dataEnd = dataStart + size;
    if (dataEnd > content.length) break;

    final descriptor = _wavInfoDescriptor(subId);
    if (descriptor != null) {
      _addText(
        fields,
        descriptor.$2.label,
        content.sublist(dataStart, dataEnd),
        id: descriptor.$1,
      );
    }

    offset = dataEnd;
    if (size.isOdd) offset++; // pad byte alignment
  }
}

/// Adds a truncated, privacy-flagged field using [data] decoded as Latin-1.
void _addText(
  List<MetadataFieldEntity> fields,
  String label,
  Uint8List data, {
  MetadataFieldId? id,
}) {
  final value = latin1.decode(data).trim();
  if (value.isEmpty) return;
  fields.add(
    MetadataFieldEntity(
      section: 'Audio RIFF',
      label: label,
      value: truncateMetadataValue(value),
      id: id,
      isPrivacySensitive: isTextPrivacySensitive(label),
    ),
  );
}

/// Whether [bytes] holds the ASCII [text] at byte [offset].
bool _asciiAt(Uint8List bytes, int offset, String text) {
  final codes = text.codeUnits;
  if (offset + codes.length > bytes.length) return false;
  for (var i = 0; i < codes.length; i++) {
    if (bytes[offset + i] != codes[i]) return false;
  }
  return true;
}

(MetadataFieldId, RiffInfoDescriptor)? _wavInfoDescriptor(String code) {
  for (final entry in wavInfoDescriptors.entries) {
    if (entry.value.code.padRight(4) == code) return (entry.key, entry.value);
  }
  return null;
}
