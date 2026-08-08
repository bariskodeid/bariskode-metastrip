import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/core/utils/file_utils.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Section label shared by every archive field.
const String archiveSection = 'Archive';

/// Section label for Android package manifest fields.
const String apkManifestSection = 'APK Manifest';

/// Maximum number of entries listed before sizes are truncated defensively.
const int _maxZipEntries = 200;

/// Decompresses [entry] within a strict byte budget to defend against
/// decompression-bomb zip entries.
///
/// Returns null without touching [ArchiveFile.content] when the entry's
/// declared uncompressed size already exceeds [maxBytes]. When the declared
/// size is within bounds but the real content is still larger than [maxBytes]
/// (a lied header), throws [FormatException] instead of materializing an
/// oversized buffer. Both extractors and the repack path use this helper so
/// the same decompression budget is enforced everywhere.
Uint8List? decodeArchiveFileSafely(
  ArchiveFile entry, {
  required int maxBytes,
}) =>
    decodeZipEntrySafely(entry, maxBytes: maxBytes);

/// Extracts archive metadata from raw [bytes] for [extension].
///
/// [extension] must be `zip`, `apk` or `epub`. Reports entry count plus summed
/// compressed and uncompressed sizes for up to [_maxZipEntries] entries. For
/// `apk` files the `AndroidManifest.xml` entry is scanned for package,
/// versionCode and versionName attribute names (which survive in the binary
/// XML string pool). Returns a single status field when the bytes are not a
/// valid zip or the archive has no entries; this function never throws.
Future<List<MetadataFieldEntity>> extractZip(
  Uint8List bytes, {
  required String extension,
}) async {
  try {
    final archive = decodeGuardedZip(bytes);
    if (archive.isEmpty) {
      return [
        statusField(archiveSection, 'Status', 'No archive entries'),
      ];
    }

    final sizes = _entrySizes(archive);
    final fields = <MetadataFieldEntity>[
      _field(archiveSection, 'Entries', '${archive.files.length}'),
      _field(
        archiveSection,
        'Compressed Size',
        FileUtils.formatBytes(sizes.compressed),
      ),
      _field(
        archiveSection,
        'Uncompressed Size',
        FileUtils.formatBytes(sizes.uncompressed),
      ),
    ];
    if (archive.files.length > _maxZipEntries) {
      fields.add(_field(archiveSection, 'Entries Truncated', 'true'));
    }

    if (extension.toLowerCase() == 'apk') {
      fields.addAll(_extractApkManifest(archive));
    }
    return fields;
  } catch (_) {
    return [
      statusField(archiveSection, 'Status', 'Invalid archive'),
    ];
  }
}

/// Aggregated compressed and uncompressed sizes of [archive] entries.
///
/// Iteration stops after [_maxZipEntries] entries so a zip bomb with many
/// headers cannot cause unbounded work on the extraction side.
({int compressed, int uncompressed}) _entrySizes(Archive archive) {
  var compressed = 0;
  var uncompressed = 0;
  final limit = archive.files.length > _maxZipEntries
      ? _maxZipEntries
      : archive.files.length;
  for (var i = 0; i < limit; i++) {
    final file = archive.files[i];
    compressed += file.rawContent?.length ?? 0;
    uncompressed += file.size;
  }
  return (compressed: compressed, uncompressed: uncompressed);
}

/// Extracts package attributes from an APK `AndroidManifest.xml` entry.
List<MetadataFieldEntity> _extractApkManifest(Archive archive) {
  final manifest = _findEntry(archive, 'AndroidManifest.xml');
  if (manifest == null) return const <MetadataFieldEntity>[];

  final content = decodeArchiveFileSafely(
    manifest,
    maxBytes: AppConstants.maxZipEntryDecompressBytes,
  );
  if (content == null) {
    return [
      statusField(
        apkManifestSection,
        'Status',
        'Manifest is too large to read safely',
      ),
    ];
  }

  final text = latin1.decode(content);
  final fields = <MetadataFieldEntity>[];
  void add(String label, String? value) {
    if (value == null || value.isEmpty) return;
    fields.add(_field(apkManifestSection, label, value));
  }

  add('Package Name', _attributeValue(text, 'package'));
  add('Version Code', _attributeValue(text, 'versionCode'));
  add('Version Name', _attributeValue(text, 'versionName'));
  return fields;
}

/// Returns the value of the first `name="..."` attribute in [content].
String? _attributeValue(String content, String name) {
  final match = RegExp(
    '${_escapeRegex(name)}="([^"]*)"',
  ).firstMatch(content);
  return match?.group(1);
}

/// Returns the first entry whose name matches [name] in [archive].
///
/// Names are compared through [normalizeEntryPath], the shared canonical path
/// used by the remover strippers, so `docProps\core.xml` and `a/./meta.xml`
/// resolve exactly like `docProps/core.xml` and `a/meta.xml`. A non-root
/// location such as `a/AndroidManifest.xml` matches `AndroidManifest.xml`.
ArchiveFile? _findEntry(Archive archive, String name) {
  for (final file in archive.files) {
    final entryName = normalizeEntryPath(file.name);
    if (entryName == name || entryName.endsWith('/$name')) return file;
  }
  return null;
}

/// Builds a metadata field in the given [section].
MetadataFieldEntity _field(String section, String label, String value) {
  return MetadataFieldEntity(
    section: section,
    label: label,
    value: truncateMetadataValue(value),
  );
}

/// Escapes regex special characters in [value].
String _escapeRegex(String value) {
  return value.replaceAllMapped(
    RegExp(r'[.*+?^${}()|[\]\\]'),
    (match) => '\\${match.group(0)}',
  );
}
