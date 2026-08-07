import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/isolate_runner.dart';
import 'package:metastrip/core/utils/file_utils.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/format_registry.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:mime/mime.dart';

/// Datasource that extracts basic file metadata plus inline format fields.
///
/// Acts as a slim facade: it owns filesystem reads, hashing, MIME lookup and
/// per-format routing/caps, and delegates format parsing to the extractors
/// under `extractors/`. Routing is driven by the format registry so every
/// supported extension is handled with the same bounded/full read strategy.
class MetadataExtractorDatasource {
  static final _hashCache = <String, String>{};
  static const int _maxHashCacheEntries = 512;

  Future<MetadataEntity> extractBasic(
    FileItemEntity file, {
    bool computeHash = false,
  }) async {
    final ioFile = File(file.path);
    final stat = await ioFile.stat();
    final headerLength = stat.size < 512 ? stat.size : 512;
    final headerBytes = await _readRange(ioFile, 0, headerLength);
    final mimeType =
        lookupMimeType(file.path, headerBytes: headerBytes) ?? 'unknown';
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final extension = file.extension.trim().toLowerCase();
    final fileSize = stat.size;

    final spec = formatSpecFor(extension);
    final payload = spec?.extractor != null
        ? await _readExtractionPayload(ioFile, extension, fileSize)
        : null;

    List<MetadataFieldEntity> formatFields;
    String? isolateHash;
    if (payload != null) {
      try {
        final result = await runOnWorker(
          () => _parseAll(payload, file.path, extension, fileSize, computeHash),
        );
        formatFields = result.fields;
        isolateHash = result.hash;
      } catch (_) {
        formatFields = [
          statusField(
            spec?.skipSection ?? 'Contents',
            'Status',
            'Unable to parse metadata',
          ),
        ];
      }
    } else if (spec?.extractor != null) {
      formatFields = [
        statusField(
          spec!.skipSection,
          spec.skipLabel,
          'Skipped for files larger than '
              '${FileUtils.formatBytes(spec.maxBytes)}',
        ),
      ];
    } else {
      formatFields = const [];
    }

    final hashValue = await _resolveHash(
      file: ioFile,
      stat: stat,
      computeHash: computeHash,
      isolateHash: isolateHash,
    );

    return MetadataEntity(
      fields: [
        MetadataFieldEntity(
          section: 'File',
          label: 'Name',
          value: file.name,
        ),
        MetadataFieldEntity(
          section: 'File',
          label: 'Extension',
          value: extension.toUpperCase(),
        ),
        MetadataFieldEntity(
          section: 'File',
          label: 'MIME Type',
          value: mimeType,
        ),
        MetadataFieldEntity(
          section: 'File',
          label: 'Size',
          value: FileUtils.formatBytes(stat.size),
        ),
        MetadataFieldEntity(
          section: 'Timestamps',
          label: 'Modified',
          value: dateFormat.format(stat.modified),
          isPrivacySensitive: true,
        ),
        MetadataFieldEntity(
          section: 'Timestamps',
          label: 'Accessed',
          value: dateFormat.format(stat.accessed),
          isPrivacySensitive: true,
        ),
        MetadataFieldEntity(
          section: 'Integrity',
          label: 'SHA-256',
          value: hashValue,
        ),
        ...formatFields,
      ],
    );
  }

  /// Reads the byte payload handed to the format extractor for [extension].
  ///
  /// Returns null when the extension is not registered, when the full-read
  /// payload exceeds the spec cap (the caller adds a skip field instead), or
  /// when there is nothing to parse. Bounded formats only read the first
  /// [AppConstants.maxAudioScanBytes] bytes; MP3 additionally pulls the
  /// trailing 128 bytes so the ID3v1 tag survives for larger files.
  Future<Uint8List?> _readExtractionPayload(
    File file,
    String extension,
    int fileSize,
  ) async {
    final spec = formatSpecFor(extension);
    if (spec?.extractor == null) return null;
    if (spec!.boundedRead) {
      return _readBoundedPayload(file, extension, fileSize);
    }
    if (fileSize > spec.maxBytes) return null;
    return file.readAsBytes();
  }

  /// Reads up to [AppConstants.maxAudioScanBytes] from the start of [file].
  ///
  /// For MP3 files larger than the prefix, the final 128 bytes are appended
  /// so ID3v1.1 tags are still detected.
  Future<Uint8List> _readBoundedPayload(
    File file,
    String extension,
    int fileSize,
  ) async {
    final prefixLength = fileSize < AppConstants.maxAudioScanBytes
        ? fileSize
        : AppConstants.maxAudioScanBytes;
    final prefix = await _readRange(file, 0, prefixLength);
    if (extension == 'mp3' && fileSize > prefixLength) {
      final tail = await _readRange(file, fileSize - 128, 128);
      final builder = BytesBuilder(copy: false);
      builder.add(prefix);
      builder.add(tail);
      return builder.takeBytes();
    }
    return prefix;
  }

  /// Reads exactly [length] bytes starting at byte [start] of [file].
  Future<Uint8List> _readRange(File file, int start, int length) async {
    if (length <= 0) return Uint8List(0);
    final randomAccessFile = await file.open();
    try {
      if (start > 0) await randomAccessFile.setPosition(start);
      return Uint8List.fromList(await randomAccessFile.read(length));
    } finally {
      await randomAccessFile.close();
    }
  }

  /// Resolves the final SHA-256 display value using the registry routing.
  ///
  /// When the parse isolate already hashed the payload (full or bounded read)
  /// that digest is reused and cached. Otherwise the whole file is read and
  /// hashed, matching the original filesystem-only behavior.
  Future<String> _resolveHash({
    required File file,
    required FileStat stat,
    required bool computeHash,
    required String? isolateHash,
  }) async {
    if (!computeHash) return 'Not computed';
    if (stat.size > AppConstants.maxInlineHashSizeBytes) {
      return 'Skipped for files larger than '
          '${FileUtils.formatBytes(AppConstants.maxInlineHashSizeBytes)}';
    }

    final key =
        '${file.path}|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
    final cached = _hashCache[key];
    if (cached != null) return cached;
    if (isolateHash != null) {
      _storeCachedHash(key, isolateHash);
      return isolateHash;
    }

    final bytes = await file.readAsBytes();
    final digest = await runOnWorker(() => _sha256Hex(bytes));
    _storeCachedHash(key, digest);
    return digest;
  }

  /// Stores [value] for [key] in the bounded in-memory hash cache.
  ///
  /// The cache is capped at [_maxHashCacheEntries]; when the cap is reached
  /// the whole cache is dropped so a long session cannot leak memory.
  static void _storeCachedHash(String key, String value) {
    _hashCache[key] = value;
    if (_hashCache.length > _maxHashCacheEntries) {
      _hashCache.clear();
    }
  }
}

/// Parses [bytes] into format fields and optionally hashes the source file.
///
/// Kept as a top-level function so `Isolate.run` only captures sendable
/// parameters. For bounded-read formats (mp3/flac/ogg/opus) the payload is
/// only a prefix, so when a hash is requested the entire [filePath] is read
/// and hashed inside the isolate; the reported SHA-256 is then honest for the
/// whole file. Full-read formats hash the already-loaded [bytes], which are
/// the complete file.
Future<({List<MetadataFieldEntity> fields, String? hash})> _parseAll(
  Uint8List bytes,
  String filePath,
  String extension,
  int sizeBytes,
  bool computeHash,
) async {
  final spec = formatSpecFor(extension);
  final fields = <MetadataFieldEntity>[];
  final extractor = spec?.extractor;
  if (extractor != null) {
    fields.addAll(await extractor(bytes));
  }
  String? hash;
  if (computeHash && sizeBytes <= AppConstants.maxInlineHashSizeBytes) {
    if (spec?.boundedRead == true) {
      hash = _sha256Hex(await File(filePath).readAsBytes());
    } else {
      hash = _sha256Hex(bytes);
    }
  }
  return (fields: fields, hash: hash);
}

String _sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();