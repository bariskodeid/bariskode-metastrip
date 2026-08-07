import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Truncates a metadata value to [AppConstants.maxMetadataFieldChars] chars.
///
/// Values longer than the cap are cut off and suffixed with a truncation
/// marker so the extracted output stays readable for very large chunks.
String truncateMetadataValue(String value) {
  if (value.length <= AppConstants.maxMetadataFieldChars) return value;
  return '${value.substring(0, AppConstants.maxMetadataFieldChars)}… [truncated]';
}

/// Builds a [MetadataFieldEntity] that reports a status (rather than a value)
/// for a given [section] using [label] and the status text [reason].
MetadataFieldEntity statusField(
  String section,
  String label,
  String reason,
) {
  return MetadataFieldEntity(
    section: section,
    label: label,
    value: reason,
  );
}

/// Whether an EXIF tag key should be flagged as privacy sensitive.
bool isExifPrivacySensitive(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('gps') ||
      normalized.contains('artist') ||
      normalized.contains('copyright') ||
      normalized.contains('owner') ||
      normalized.contains('serial') ||
      normalized.contains('datetime') ||
      normalized.contains('make') ||
      normalized.contains('model') ||
      normalized.contains('usercomment') ||
      normalized.contains('imagedescription') ||
      normalized.contains('xp') ||
      normalized.contains('software') ||
      normalized.contains('hostcomputer') ||
      normalized.contains('lens');
}

/// Whether a PNG text chunk keyword should be flagged as privacy sensitive.
bool isTextPrivacySensitive(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('author') ||
      normalized.contains('creator') ||
      normalized.contains('comment') ||
      normalized.contains('copyright') ||
      normalized.contains('description') ||
      normalized.contains('software') ||
      normalized.contains('source');
}