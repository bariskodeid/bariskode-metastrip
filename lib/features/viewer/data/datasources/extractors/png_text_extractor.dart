import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Extracts text chunks (tEXt / iTXt) from raw PNG [bytes].
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
  return [
    MetadataFieldEntity(
      section: 'PNG Text',
      label: truncateMetadataValue(keyword),
      value: truncateMetadataValue(value),
      isPrivacySensitive: isTextPrivacySensitive(keyword),
    ),
  ];
}

List<MetadataFieldEntity> _parseInternationalTextChunk(Uint8List data) {
  final keywordEnd = data.indexOf(0);
  if (keywordEnd <= 0 || keywordEnd + 2 >= data.length) return const [];
  if (data[keywordEnd + 1] != 0) return const []; // compressed text skipped

  var cursor = keywordEnd + 3;
  final languageEnd = data.indexOf(0, cursor);
  if (languageEnd < 0) return const [];
  cursor = languageEnd + 1;
  final translatedEnd = data.indexOf(0, cursor);
  if (translatedEnd < 0) return const [];
  cursor = translatedEnd + 1;

  final keyword = String.fromCharCodes(data.sublist(0, keywordEnd));
  final value = utf8.decode(data.sublist(cursor), allowMalformed: true);
  return [
    MetadataFieldEntity(
      section: 'PNG Text',
      label: truncateMetadataValue(keyword),
      value: truncateMetadataValue(value),
      isPrivacySensitive: isTextPrivacySensitive(keyword),
    ),
  ];
}