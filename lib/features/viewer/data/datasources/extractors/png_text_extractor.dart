import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/exif_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Maximum inflated size of a compressed text chunk value.
const int _maxInflatedTextBytes = 1024 * 1024;

/// Extracts text chunks (tEXt / zTXt / iTXt) and the eXIf chunk from raw PNG [bytes].
///
/// Returns a single status field when the bytes lack a PNG signature, when
/// no text metadata is found, or when the chunk stream cannot be parsed.
Future<List<MetadataFieldEntity>> extractPngText(Uint8List bytes) async {
  try {
    if (!_hasPngSignature(bytes)) {
      return [statusField('PNG Text', 'Status', 'Invalid PNG signature')];
    }

    final fields = <MetadataFieldEntity>[];
    var offset = 8;
    while (offset + 8 <= bytes.length) {
      final length =
          ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      final dataStart = offset + 8;
      if (length > bytes.length - dataStart - 4) break;
      final dataEnd = dataStart + length;

      if (type == 'tEXt') {
        fields.addAll(_parseTextChunk(bytes.sublist(dataStart, dataEnd)));
      } else if (type == 'iTXt') {
        fields.addAll(
          _parseInternationalTextChunk(bytes.sublist(dataStart, dataEnd)),
        );
      } else if (type == 'zTXt') {
        fields.addAll(
            _parseCompressedTextChunk(bytes.sublist(dataStart, dataEnd)));
      } else if (type == 'eXIf') {
        fields.addAll(await _parseExifChunk(bytes.sublist(dataStart, dataEnd)));
      }

      if (fields.length >= AppConstants.maxPngTextChunks) break;

      offset = dataEnd + 4;
      if (type == 'IEND') break;
    }

    if (fields.isEmpty) {
      return [
        statusField('PNG Text', 'Status', 'No PNG text metadata found'),
      ];
    }

    return fields;
  } catch (_) {
    return [
      statusField('PNG Text', 'Status', 'Unable to parse PNG text metadata'),
    ];
  }
}

bool _hasPngSignature(Uint8List bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

List<MetadataFieldEntity> _parseTextChunk(Uint8List data) {
  final separator = data.indexOf(0);
  if (separator <= 0) return const [];
  final keyword = String.fromCharCodes(data.sublist(0, separator));
  final value = String.fromCharCodes(data.sublist(separator + 1));
  return [_textField(keyword, value)];
}

List<MetadataFieldEntity> _parseInternationalTextChunk(Uint8List data) {
  final keywordEnd = data.indexOf(0);
  if (keywordEnd <= 0 || keywordEnd + 2 >= data.length) return const [];
  final compressed = data[keywordEnd + 1] == 1;
  if (data[keywordEnd + 1] > 1) return const [];
  if (compressed && data[keywordEnd + 2] != 0) return const [];

  var cursor = keywordEnd + 3;
  final languageEnd = data.indexOf(0, cursor);
  if (languageEnd < 0) return const [];
  cursor = languageEnd + 1;
  final translatedEnd = data.indexOf(0, cursor);
  if (translatedEnd < 0) return const [];
  cursor = translatedEnd + 1;

  final keyword = String.fromCharCodes(data.sublist(0, keywordEnd));
  final raw = data.sublist(cursor);
  if (!compressed) {
    return [_textField(keyword, utf8.decode(raw, allowMalformed: true))];
  }
  return [_inflatedField(keyword, raw, utf8)];
}

List<MetadataFieldEntity> _parseCompressedTextChunk(Uint8List data) {
  final keywordEnd = data.indexOf(0);
  if (keywordEnd <= 0 || keywordEnd + 1 >= data.length) return const [];
  if (data[keywordEnd + 1] != 0) return const []; // unknown method
  final keyword = String.fromCharCodes(data.sublist(0, keywordEnd));
  return [_inflatedField(keyword, data.sublist(keywordEnd + 2), latin1)];
}

MetadataFieldEntity _textField(String keyword, String value) {
  return MetadataFieldEntity(
    section: 'PNG Text',
    label: truncateMetadataValue(keyword),
    value: truncateMetadataValue(value),
    id: _selectableId(keyword),
    isPrivacySensitive: isTextPrivacySensitive(keyword),
  );
}

/// Inflates [compressed] under [_maxInflatedTextBytes]; oversized or invalid
/// streams yield a status value instead of throwing.
MetadataFieldEntity _inflatedField(
  String keyword,
  Uint8List compressed,
  Encoding encoding,
) {
  try {
    final inflated = inflateZlibBounded(
      compressed,
      maxBytes: _maxInflatedTextBytes,
    );
    return _textField(keyword, encoding.decode(inflated));
  } on FormatException catch (error) {
    final tooLarge = error.message.contains('exceeds');
    return MetadataFieldEntity(
      section: 'PNG Text',
      label: truncateMetadataValue(keyword),
      value: tooLarge
          ? 'Compressed value exceeds 1 MiB; not shown'
          : 'Compressed value could not be decoded',
      id: _selectableId(keyword),
      isPrivacySensitive: isTextPrivacySensitive(keyword),
    );
  }
}

/// Surfaces an eXIf chunk: parsed EXIF tags when readable, plus a presence
/// field so the user knows the chunk will be removed.
Future<List<MetadataFieldEntity>> _parseExifChunk(Uint8List data) async {
  final presence = MetadataFieldEntity(
    section: 'PNG Text',
    label: 'EXIF',
    value: 'eXIf chunk present (${data.length} bytes)',
    isPrivacySensitive: true,
  );
  final parsed = await extractExif(data);
  final tags = parsed.where((f) => f.label != 'Status').toList();
  return [presence, ...tags];
}

MetadataFieldId? _selectableId(String keyword) {
  try {
    return MetadataFieldId.pngText(keyword);
  } on ArgumentError {
    return null;
  }
}
