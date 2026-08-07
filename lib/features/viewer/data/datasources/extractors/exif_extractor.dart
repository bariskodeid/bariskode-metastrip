import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Extracts EXIF metadata fields from raw image [bytes].
///
/// Returns a single status field when no EXIF data is present or when the
/// bytes cannot be parsed as EXIF.
Future<List<MetadataFieldEntity>> extractExif(Uint8List bytes) async {
  try {
    final tags = await readExifFromBytes(bytes);
    if (tags.isEmpty) {
      return [statusField('Image EXIF', 'Status', 'No EXIF metadata found')];
    }

    return tags.entries
        .map(
          (entry) => MetadataFieldEntity(
            section: 'Image EXIF',
            label: entry.key,
            value: entry.value.printable,
            isPrivacySensitive: isExifPrivacySensitive(entry.key),
          ),
        )
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  } catch (_) {
    return [
      statusField('Image EXIF', 'Status', 'Unable to parse EXIF metadata'),
    ];
  }
}