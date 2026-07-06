import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:exif/exif.dart';
import 'package:intl/intl.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/processing/isolate_runner.dart';
import 'package:metastrip/core/utils/file_utils.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:mime/mime.dart';

class MetadataExtractorDatasource {
  static final _hashCache = <String, String>{};

  Future<MetadataEntity> extractBasic(
    FileItemEntity file, {
    bool computeHash = false,
  }) async {
    final ioFile = File(file.path);
    final stat = await ioFile.stat();
    final length = stat.size < 512 ? stat.size : 512;
    final randomAccessFile = await ioFile.open();
    final headerBytes = await randomAccessFile.read(length);
    await randomAccessFile.close();
    final mimeType =
        lookupMimeType(file.path, headerBytes: headerBytes) ?? 'unknown';
    final hashValue = await _hashValue(ioFile, stat, computeHash);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

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
          value: file.extension.toUpperCase(),
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
        ...await _extractExifFields(ioFile, file.extension, stat.size),
        ...await _extractPngTextFields(ioFile, file.extension, stat.size),
      ],
    );
  }

  Future<String> _hashValue(File file, FileStat stat, bool computeHash) async {
    if (!computeHash) return 'Not computed';
    if (stat.size > AppConstants.maxInlineHashSizeBytes) {
      return 'Skipped for files larger than ${FileUtils.formatBytes(AppConstants.maxInlineHashSizeBytes)}';
    }

    final key =
        '${file.path}|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
    final cached = _hashCache[key];
    if (cached != null) return cached;

    final bytes = await file.readAsBytes();
    final digest = await runOnWorker(() => _sha256Hex(bytes));
    _hashCache[key] = digest;
    return digest;
  }

  Future<List<MetadataFieldEntity>> _extractPngTextFields(
    File file,
    String extension,
    int sizeBytes,
  ) async {
    if (extension.toLowerCase() != 'png') return const [];

    if (sizeBytes > AppConstants.maxInlineExifSizeBytes) {
      return [
        MetadataFieldEntity(
          section: 'PNG Text',
          label: 'PNG Text Scan',
          value:
              'Skipped for files larger than ${FileUtils.formatBytes(AppConstants.maxInlineExifSizeBytes)}',
        ),
      ];
    }

    try {
      final bytes = await file.readAsBytes();
      if (!_hasPngSignature(bytes)) {
        return const [
          MetadataFieldEntity(
            section: 'PNG Text',
            label: 'Status',
            value: 'Invalid PNG signature',
          ),
        ];
      }

      final fields = <MetadataFieldEntity>[];
      var offset = 8;
      while (offset + 8 <= bytes.length) {
        final length =
            ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
        final type =
            String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
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
        return const [
          MetadataFieldEntity(
            section: 'PNG Text',
            label: 'Status',
            value: 'No PNG text metadata found',
          ),
        ];
      }

      return fields;
    } catch (_) {
      return const [
        MetadataFieldEntity(
          section: 'PNG Text',
          label: 'Status',
          value: 'Unable to parse PNG text metadata',
        ),
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
        label: keyword,
        value: _truncateMetadataValue(value),
        isPrivacySensitive: _isTextPrivacySensitive(keyword),
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
        label: keyword,
        value: _truncateMetadataValue(value),
        isPrivacySensitive: _isTextPrivacySensitive(keyword),
      ),
    ];
  }

  Future<List<MetadataFieldEntity>> _extractExifFields(
    File file,
    String extension,
    int sizeBytes,
  ) async {
    if (!{'jpg', 'jpeg', 'tif', 'tiff'}.contains(extension.toLowerCase())) {
      return const [];
    }

    if (sizeBytes > AppConstants.maxInlineExifSizeBytes) {
      return [
        MetadataFieldEntity(
          section: 'Image EXIF',
          label: 'EXIF Scan',
          value:
              'Skipped for files larger than ${FileUtils.formatBytes(AppConstants.maxInlineExifSizeBytes)}',
        ),
      ];
    }

    try {
      final tags = await readExifFromBytes(await file.readAsBytes());
      if (tags.isEmpty) {
        return const [
          MetadataFieldEntity(
            section: 'Image EXIF',
            label: 'Status',
            value: 'No EXIF metadata found',
          ),
        ];
      }

      return tags.entries
          .map(
            (entry) => MetadataFieldEntity(
              section: 'Image EXIF',
              label: entry.key,
              value: entry.value.printable,
              isPrivacySensitive: _isExifPrivacySensitive(entry.key),
            ),
          )
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));
    } catch (_) {
      return const [
        MetadataFieldEntity(
          section: 'Image EXIF',
          label: 'Status',
          value: 'Unable to parse EXIF metadata',
        ),
      ];
    }
  }

  bool _isExifPrivacySensitive(String key) {
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

  bool _isTextPrivacySensitive(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('author') ||
        normalized.contains('creator') ||
        normalized.contains('comment') ||
        normalized.contains('copyright') ||
        normalized.contains('description') ||
        normalized.contains('software') ||
        normalized.contains('source');
  }

  String _truncateMetadataValue(String value) {
    if (value.length <= AppConstants.maxMetadataFieldChars) return value;
    return '${value.substring(0, AppConstants.maxMetadataFieldChars)}… [truncated]';
  }
}

String _sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();
