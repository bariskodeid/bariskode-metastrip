import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/format/format_registry.dart';
import 'package:metastrip/core/processing/isolate_runner.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/bmp_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/gif_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/id3_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/odf_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/openxml_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_validator.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_value_parser.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/riff_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/vorbis_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/webp_stripper.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';

enum _RemovalRoute {
  jpeg,
  png,
  pdf,
  mp3,
  flac,
  ogg,
  opus,
  wav,
  aiff,
  openXml,
  odf,
  gif,
  webp,
  bmp,
  zip,
}

/// Successful datasource output with value-free cleanup facts.
class MetadataRemovalOutput {
  const MetadataRemovalOutput({required this.file, required this.report});

  final File file;
  final StripReport report;
}

class MetadataRemoverDatasource {
  MetadataRemoverDatasource({
    Future<void> Function(File claim)? claimCleanup,
    Future<Uint8List> Function(File output)? persistedOutputReader,
  })  : _claimCleanup = claimCleanup ?? _deleteClaim,
        _persistedOutputReader = persistedOutputReader ?? _readPersistedOutput;

  final Future<void> Function(File claim) _claimCleanup;
  final Future<Uint8List> Function(File output) _persistedOutputReader;

  /// Returns whether this datasource has a remover route for [extension].
  static bool supportsExtension(String extension) {
    final normalized = FormatRegistry.normalizeExtension(extension);
    return FormatRegistry.standard.supportsRemoval(normalized) &&
        _routes.containsKey(normalized);
  }

  /// Concrete routes used by [stripMetadata].
  static const Map<String, _RemovalRoute> _routes = {
    'jpg': _RemovalRoute.jpeg,
    'jpeg': _RemovalRoute.jpeg,
    'png': _RemovalRoute.png,
    'pdf': _RemovalRoute.pdf,
    'mp3': _RemovalRoute.mp3,
    'flac': _RemovalRoute.flac,
    'ogg': _RemovalRoute.ogg,
    'opus': _RemovalRoute.opus,
    'wav': _RemovalRoute.wav,
    'aiff': _RemovalRoute.aiff,
    'docx': _RemovalRoute.openXml,
    'xlsx': _RemovalRoute.openXml,
    'pptx': _RemovalRoute.openXml,
    'odt': _RemovalRoute.odf,
    'ods': _RemovalRoute.odf,
    'odp': _RemovalRoute.odf,
    'gif': _RemovalRoute.gif,
    'webp': _RemovalRoute.webp,
    'bmp': _RemovalRoute.bmp,
    'zip': _RemovalRoute.zip,
  };

  static Set<String> get handlerExtensions => Set.unmodifiable(_routes.keys);

  static List<String> get handlerConsistencyIssues =>
      FormatRegistry.standard.handlerMapConsistencyIssues(
        removalHandlerExtensions: _routes.keys,
      );

  /// Applies an explicit [policy] and returns the clean copy plus its report.
  Future<MetadataRemovalOutput> stripMetadataWithPolicy(
    String inputPath, {
    required String outputDirectory,
    required StripPolicy policy,
  }) async {
    final extension = FormatRegistry.normalizeExtension(p.extension(inputPath));
    final capability = FormatRegistry.standard.lookup(extension);
    if (policy.mode == StripPolicyMode.selective) {
      if (capability?.supportsSelectiveRemoval != true) {
        throw const FormatException(
          'Selective cleanup is unavailable for this format',
        );
      }
      _validateFieldIdsForExtension(extension, policy.selectedFieldIds);
    }

    if (policy.mode == StripPolicyMode.supportedCleanup) {
      if (extension == 'bmp') {
        return _stripBmpWithReport(
          inputPath,
          outputDirectory: outputDirectory,
        );
      }
      if (extension == 'pdf') {
        return _stripPdfWithReport(
          inputPath,
          outputDirectory: outputDirectory,
        );
      }
      if (extension == 'zip') {
        return _stripZipWithReport(
          inputPath,
          outputDirectory: outputDirectory,
        );
      }
      final file = await stripMetadata(
        inputPath,
        outputDirectory: outputDirectory,
      );
      return MetadataRemovalOutput(
        file: file,
        report: StripReport.snapshot(
          warnings:
              extension == 'pdf' ? const [_pdfBestEffortWarning] : const [],
          verificationOutcome: extension == 'pdf'
              ? StripVerificationOutcome.attemptedUnverified
              : StripVerificationOutcome.notAttempted,
        ),
      );
    }

    return switch (extension) {
      'png' => _stripSelectivePng(
          inputPath,
          outputDirectory,
          policy.selectedFieldIds,
        ),
      'pdf' => _stripSelectivePdf(
          inputPath,
          outputDirectory,
          policy.selectedFieldIds,
        ),
      _ => throw const FormatException(
          'Selective cleanup is unavailable for this format',
        ),
    };
  }

  void _validateFieldIdsForExtension(
    String extension,
    Set<MetadataFieldId> fieldIds,
  ) {
    if (fieldIds.isEmpty) {
      throw const FormatException('No metadata fields selected');
    }
    final valid = switch (extension) {
      'png' => fieldIds.every((id) => id.isPngText),
      'pdf' => fieldIds.every((id) => id.isPdfInfo),
      _ => false,
    };
    if (!valid) {
      throw const FormatException('Metadata field does not match file format');
    }
  }

  Future<MetadataRemovalOutput> _stripSelectivePng(
    String inputPath,
    String outputDirectory,
    Set<MetadataFieldId> requestedIds,
  ) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('PNG too large for remover MVP');
    }
    final inputBytes = await _readBoundedBytes(
      input,
      AppConstants.maxRemoverFileSizeBytes + 1,
    );
    if (inputBytes.length > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('PNG too large for remover MVP');
    }
    final labels = requestedIds.map((id) => id.pngKeyword!).toSet();
    final stripped = await runOnWorker(
      () => _stripPngBytesWithReport(
        inputBytes,
        selectiveLabels: labels,
      ),
    );
    _validateSelectivePngOutput(stripped.bytes, labels);
    final file = await _writeCleanCopy(
      inputPath,
      stripped.bytes,
      outputDirectory,
    );
    final isSafOutput = file.path.startsWith('content://');
    if (!isSafOutput) {
      try {
        final persistedBytes = await _persistedOutputReader(file);
        _validateSelectivePngOutput(persistedBytes, labels);
      } on Object {
        // File paths are not stable identities. Leave the unverified output
        // in place rather than deleting a path that another writer may have
        // substituted during validation.
        rethrow;
      }
    }
    final removedIds =
        stripped.removedLabels.map(MetadataFieldId.pngText).toSet();
    final warnings = isSafOutput
        ? const [
            'Generated PNG bytes were validated, but the persisted SAF '
                'artifact was not read back.',
          ]
        : const <String>[];
    return MetadataRemovalOutput(
      file: file,
      report: StripReport.snapshot(
        requestedFieldIds: requestedIds,
        removedFieldIds: removedIds,
        warnings: warnings,
        verificationOutcome: isSafOutput
            ? StripVerificationOutcome.attemptedUnverified
            : StripVerificationOutcome.verified,
        outputValidated: !isSafOutput,
      ),
    );
  }

  Future<MetadataRemovalOutput> _stripSelectivePdf(
    String inputPath,
    String outputDirectory,
    Set<MetadataFieldId> requestedIds,
  ) async {
    final labels = requestedIds.map((id) => id.pdfInfoKey!).toSet();
    return _stripPdfWithReport(
      inputPath,
      outputDirectory: outputDirectory,
      requestedIds: requestedIds,
      selectedKeys: labels,
    );
  }

  Future<MetadataRemovalOutput> _stripPdfWithReport(
    String inputPath, {
    required String outputDirectory,
    Set<MetadataFieldId> requestedIds = const {},
    Set<String>? selectedKeys,
  }) async {
    final output = await stripPdfMetadata(
      inputPath,
      outputDirectory: outputDirectory,
      selectiveLabels: selectedKeys,
    );
    return MetadataRemovalOutput(
      file: output,
      report: StripReport.snapshot(
        requestedFieldIds: requestedIds,
        warnings: const [_pdfBestEffortWarning],
        verificationOutcome: StripVerificationOutcome.attemptedUnverified,
        outputValidated: false,
      ),
    );
  }

  Future<Uint8List> _readBoundedBytes(File file, int maxBytes) async {
    final handle = await file.open();
    try {
      return Uint8List.fromList(await handle.read(maxBytes));
    } finally {
      await handle.close();
    }
  }

  /// Strips metadata from [inputPath] into the configured output folder.
  ///
  /// A null [selectiveLabels] value requests full removal. A non-empty set
  /// requests field-level removal and is accepted only for formats that support
  /// it (PNG text chunks and PDF Info keys). Empty sets, unsupported formats,
  /// and unknown field labels are rejected.
  Future<File> stripMetadata(
    String inputPath, {
    String? outputDirectory,
    Set<String>? selectiveLabels,
  }) async {
    final ext = FormatRegistry.normalizeExtension(p.extension(inputPath));
    final route = _routes[ext];
    if (!FormatRegistry.standard.supportsRemoval(ext) || route == null) {
      throw FileSystemException('Unsupported remover format: $ext');
    }
    if (selectiveLabels != null && selectiveLabels.isEmpty) {
      throw const FormatException('No metadata fields selected');
    }
    if (selectiveLabels != null &&
        !FormatRegistry.standard.lookup(ext)!.supportsSelectiveRemoval) {
      throw const FormatException(
        'Selective cleanup is unavailable for this format',
      );
    }
    if (route == _RemovalRoute.pdf &&
        selectiveLabels != null &&
        selectiveLabels.isNotEmpty &&
        !selectiveLabels.every(_pdfInfoKeys.contains)) {
      throw const FormatException('Unsupported selective metadata field');
    }
    return switch (route) {
      _RemovalRoute.jpeg => stripJpegMetadata(
          inputPath,
          outputDirectory: outputDirectory,
        ),
      _RemovalRoute.png => stripPngMetadata(
          inputPath,
          outputDirectory: outputDirectory,
          selectiveLabels: selectiveLabels,
        ),
      _RemovalRoute.pdf => stripPdfMetadata(
          inputPath,
          outputDirectory: outputDirectory,
          selectiveLabels: selectiveLabels,
        ),
      _RemovalRoute.mp3 =>
        stripMp3Metadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.flac =>
        stripFlacMetadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.ogg =>
        stripOggMetadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.opus =>
        stripOpusMetadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.wav =>
        stripWavMetadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.aiff => stripAiffMetadata(
          inputPath,
          outputDirectory: outputDirectory,
        ),
      _RemovalRoute.openXml => stripOpenXmlMetadata(
          inputPath,
          outputDirectory: outputDirectory,
        ),
      _RemovalRoute.odf => stripOdfMetadata(
          inputPath,
          outputDirectory: outputDirectory,
        ),
      _RemovalRoute.gif =>
        stripGifMetadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.webp =>
        stripWebpMetadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.bmp =>
        stripBmpMetadata(inputPath, outputDirectory: outputDirectory),
      _RemovalRoute.zip =>
        stripZipMetadata(inputPath, outputDirectory: outputDirectory),
    };
  }

  Future<File> stripJpegMetadata(
    String inputPath, {
    String? outputDirectory,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('JPEG too large for remover MVP');
    }

    final bytes = await _readBoundedBytes(
      input,
      AppConstants.maxRemoverFileSizeBytes + 1,
    );
    if (bytes.length > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('JPEG too large for remover MVP');
    }
    final outputBytes = await runOnWorker(() => _stripJpegBytes(bytes));
    return _writeCleanCopy(inputPath, outputBytes, outputDirectory);
  }

  /// Writes a PNG clean copy, removing text metadata chunks.
  ///
  /// A null [selectiveLabels] keeps the current full-strip behavior:
  /// tEXt/zTXt/iTXt text chunks plus the eXIf and tIME chunks are removed.
  /// When [selectiveLabels] is provided, only text chunks whose keyword
  /// matches a label are removed; every other chunk (image data plus any
  /// unselected metadata, including eXIf and tIME) is preserved. Labels use
  /// the PNG text keyword produced by the viewer's extractor.
  Future<File> stripPngMetadata(
    String inputPath, {
    String? outputDirectory,
    Set<String>? selectiveLabels,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('PNG too large for remover MVP');
    }

    final bytes = await _readBoundedBytes(
      input,
      AppConstants.maxRemoverFileSizeBytes + 1,
    );
    if (bytes.length > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('PNG too large for remover MVP');
    }
    final outputBytes = await runOnWorker(
      () => _stripPngBytes(bytes, selectiveLabels: selectiveLabels),
    );
    return _writeCleanCopy(inputPath, outputBytes, outputDirectory);
  }

  /// Writes a clean PDF copy, blanking document Info values.
  ///
  /// A null [selectiveLabels] blanks all nine Info keys as before. When
  /// [selectiveLabels] is provided, only the keys present in the set are
  /// blanked; the other Info entries keep their values. Labels use the PDF
  /// Info key names produced by the extractor (for example `Title`).
  Future<File> stripPdfMetadata(
    String inputPath, {
    String? outputDirectory,
    Set<String>? selectiveLabels,
  }) async {
    if (selectiveLabels != null && selectiveLabels.isEmpty) {
      throw const FormatException('Selective PDF fields cannot be empty');
    }
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('PDF too large for remover MVP');
    }

    final bytes = await _readBoundedBytes(
      input,
      AppConstants.maxRemoverFileSizeBytes + 1,
    );
    if (bytes.length > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('PDF too large for remover MVP');
    }
    final outputBytes = await runOnWorker(
      () => _stripPdfInfoBytes(bytes, selectiveLabels: selectiveLabels),
    );
    validateGeneratedPdfInfoMutation(
      bytes,
      outputBytes,
      selectedKeys: selectiveLabels,
    );
    return _writeCleanCopy(inputPath, outputBytes, outputDirectory);
  }

  Future<File> stripMp3Metadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      stripId3,
      inputPath,
      'MP3 too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripFlacMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      (bytes) => stripVorbisComments(bytes, extension: 'flac'),
      inputPath,
      'FLAC too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripOggMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      (bytes) => stripVorbisComments(bytes, extension: 'ogg'),
      inputPath,
      'OGG too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripOpusMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      (bytes) => stripVorbisComments(bytes, extension: 'ogg'),
      inputPath,
      'Opus too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripWavMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      (bytes) => stripRiff(bytes, extension: 'wav'),
      inputPath,
      'WAV too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripAiffMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      (bytes) => stripRiff(bytes, extension: 'aiff'),
      inputPath,
      'AIFF too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripOpenXmlMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      (bytes) => stripOpenXml(
        bytes,
        extension: FormatRegistry.normalizeExtension(p.extension(inputPath)),
      ),
      inputPath,
      'Office document too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripOdfMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      (bytes) => stripOdf(
        bytes,
        extension: FormatRegistry.normalizeExtension(p.extension(inputPath)),
      ),
      inputPath,
      'ODF document too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripGifMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      stripGif,
      inputPath,
      'GIF too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  Future<File> stripWebpMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    return _stripWithBytes(
      stripWebp,
      inputPath,
      'WebP too large for remover MVP',
      outputDirectory: outputDirectory,
    );
  }

  /// Writes and verifies a canonical BMP clean copy.
  Future<File> stripBmpMetadata(
    String inputPath, {
    String? outputDirectory,
  }) async {
    final result = await _stripBmpWithReport(
      inputPath,
      outputDirectory: outputDirectory,
    );
    return result.file;
  }

  /// Writes a ZIP copy with container-level metadata normalized.
  Future<File> stripZipMetadata(
    String inputPath, {
    String? outputDirectory,
  }) async {
    final result = await _stripZipWithReport(
      inputPath,
      outputDirectory: outputDirectory,
    );
    return result.file;
  }

  Future<MetadataRemovalOutput> _stripZipWithReport(
    String inputPath, {
    required String? outputDirectory,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('ZIP too large for remover MVP');
    }
    final inputBytes = await _readBoundedBytes(
      input,
      AppConstants.maxRemoverFileSizeBytes + 1,
    );
    if (inputBytes.length > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('ZIP too large for remover MVP');
    }
    final outputBytes = await runOnWorker(
      () => rewriteZipMetadata(inputBytes),
    );
    _validateGeneratedZip(outputBytes);
    final output = await _writeCleanCopy(
      inputPath,
      outputBytes,
      outputDirectory,
    );
    final isSafOutput = output.path.startsWith('content://');
    if (!isSafOutput) {
      FileStat? installedStat;
      try {
        installedStat = await output.stat();
        if (installedStat.type != FileSystemEntityType.file ||
            installedStat.size != outputBytes.length) {
          throw const FormatException('ZIP persisted output size changed');
        }
        final persisted = await _persistedOutputReader(output);
        final validatedStat = await output.stat();
        if (!_sameStatAttributes(installedStat, validatedStat)) {
          throw const FormatException('ZIP persisted output changed');
        }
        _validateGeneratedZip(persisted);
        if (!_sameBytes(persisted, outputBytes)) {
          throw const FormatException('ZIP persisted output differs');
        }
      } on Object {
        // FileStat exposes mutable attributes, not a reliable file identity.
        // Never delete a persisted output from a failed validation based only
        // on matching size/timestamps: another writer may have substituted it.
        rethrow;
      }
    }
    return MetadataRemovalOutput(
      file: output,
      report: StripReport.snapshot(
        warnings: const [
          'ZIP container metadata was cleaned; metadata inside archive members was not recursively cleaned.',
        ],
        verificationOutcome: isSafOutput
            ? StripVerificationOutcome.attemptedUnverified
            : StripVerificationOutcome.verified,
        outputValidated: !isSafOutput,
      ),
    );
  }

  void _validateGeneratedZip(Uint8List bytes) {
    validateCanonicalZipMetadata(bytes);
  }

  Future<MetadataRemovalOutput> _stripBmpWithReport(
    String inputPath, {
    required String? outputDirectory,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('BMP too large for remover MVP');
    }
    final inputBytes = await _readBoundedBytes(
      input,
      AppConstants.maxRemoverFileSizeBytes + 1,
    );
    if (inputBytes.length > AppConstants.maxRemoverFileSizeBytes) {
      throw const FileSystemException('BMP too large for remover MVP');
    }

    final outputBytes = await runOnWorker(() => stripBmp(inputBytes));
    validateBmpOutput(inputBytes, outputBytes);
    final output = await _writeCleanCopy(
      inputPath,
      outputBytes,
      outputDirectory,
    );
    final isSafOutput = output.path.startsWith('content://');
    if (!isSafOutput) {
      FileStat? installedStat;
      try {
        installedStat = await output.stat();
        if (installedStat.type != FileSystemEntityType.file ||
            installedStat.size != outputBytes.length) {
          throw const FormatException('BMP persisted output size changed');
        }
        final persistedBytes = await _persistedOutputReader(output);
        final validatedStat = await output.stat();
        if (!_sameStatAttributes(installedStat, validatedStat)) {
          throw const FormatException('BMP persisted output changed');
        }
        validateBmpOutput(inputBytes, persistedBytes);
      } on Object {
        // FileStat size/timestamps are not identity. Leave the failed output
        // in place rather than risk deleting a replacement installed by an
        // unrelated writer.
        if (installedStat == null) {
          throw const FormatException(
            'Output validation failed; unverified copy may remain',
          );
        }
        rethrow;
      }
    }

    return MetadataRemovalOutput(
      file: output,
      report: StripReport.snapshot(
        warnings: isSafOutput ? const [_safBmpValidationWarning] : const [],
        verificationOutcome: isSafOutput
            ? StripVerificationOutcome.attemptedUnverified
            : StripVerificationOutcome.verified,
        outputValidated: !isSafOutput,
      ),
    );
  }

  /// Shared pipeline for the newer strip*Metadata methods: stat + size cap +
  /// worker scrub + clean-copy install. Same behavior as [stripPdfMetadata].
  ///
  /// [selectiveLabels] is accepted for signature consistency. The public
  /// facade rejects selective requests before formats routed through this
  /// helper can reach it.
  Future<File> _stripWithBytes(
    Uint8List Function(Uint8List) stripper,
    String inputPath,
    String errorMessage, {
    String? outputDirectory,
    // Parameter is part of the uniform facade contract; the formats routed
    // here have no granular fields, so it is deliberately left unread.
    // ignore: unused_element_parameter
    Set<String>? selectiveLabels,
  }) async {
    final input = File(inputPath);
    final stat = await input.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a file');
    }
    if (stat.size > AppConstants.maxRemoverFileSizeBytes) {
      throw FileSystemException(errorMessage);
    }

    final bytes = await _readBoundedBytes(
      input,
      AppConstants.maxRemoverFileSizeBytes + 1,
    );
    if (bytes.length > AppConstants.maxRemoverFileSizeBytes) {
      throw FileSystemException(errorMessage);
    }
    final outputBytes = await runOnWorker(() => stripper(bytes));
    return _writeCleanCopy(inputPath, outputBytes, outputDirectory);
  }

  Future<File> _writeCleanCopy(
    String inputPath,
    Uint8List bytes,
    String? outputDirectory,
  ) async {
    final directory = await validateOutputFolder(outputDirectory ?? '');
    if (Platform.isAndroid && directory.startsWith('content://')) {
      return _writeCleanCopyViaSaf(inputPath, bytes, directory);
    }

    final basename = p.basenameWithoutExtension(inputPath);
    final ext = p.extension(inputPath);

    for (var index = 0; index <= 999; index++) {
      final suffix = index == 0 ? '' : '_$index';
      final output = File(p.join(directory, '${basename}_clean$suffix$ext'));
      final claim = File('${output.path}.claim');
      final temporary = File(
        '${output.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      var claimed = false;
      try {
        if (await output.exists()) continue;
        await claim.create(exclusive: true);
        claimed = true;
        await temporary.create(exclusive: true);
        // The complete bytes are flushed to a uniquely named temporary file.
        // A crash can leave only auxiliary files, never a partial file under
        // the final clean filename.
        await temporary.writeAsBytes(bytes, flush: true);
        if (await output.exists()) {
          await _runBestEffort(() => temporary.delete());
          await _runBestEffort(() => claim.delete());
          continue;
        }
        // Dart has no cross-platform atomic, no-overwrite rename primitive.
        // The claim/check above protects normal concurrent jobs; an
        // external writer racing this final rename remains a platform limit.
        final installed = await temporary.rename(output.path);
        await _runBestEffort(() => _claimCleanup(claim));
        return installed;
      } on FileSystemException {
        if (claimed && await temporary.exists()) {
          await _runBestEffort(() => temporary.delete());
        }
        if (claimed && await claim.exists()) {
          await _runBestEffort(() => claim.delete());
        }
        if (await output.exists() || (!claimed && await claim.exists())) {
          continue;
        }
        rethrow;
      } catch (_) {
        if (await temporary.exists()) {
          await _runBestEffort(() => temporary.delete());
        }
        if (claimed && await claim.exists()) {
          await _runBestEffort(() => claim.delete());
        }
        rethrow;
      }
    }
    throw const FileSystemException('Too many output filename collisions');
  }

  /// Writes the clean copy into an Android Storage Access Framework grant.
  ///
  /// `writeFileBytes` never overwrites: on a name collision the provider
  /// auto-renames the new file. The returned [File] is only a path token
  /// whose path is the created document's `content://` URI; the repository
  /// resolves size through SAF for these paths.
  Future<File> _writeCleanCopyViaSaf(
    String inputPath,
    Uint8List bytes,
    String directoryUri,
  ) async {
    final name = '${p.basenameWithoutExtension(inputPath)}_clean'
        '${p.extension(inputPath)}';
    final mime = lookupMimeType(name) ?? 'application/octet-stream';
    try {
      final document = await Saf().writeFileBytes(
        directoryUri,
        name,
        mime,
        bytes,
      );
      return File(document.uri);
    } catch (_) {
      throw const FileSystemException('SAF output write failed');
    }
  }
}

Future<void> _deleteClaim(File claim) => claim.delete();

Future<Uint8List> _readPersistedOutput(File output) async {
  final handle = await output.open();
  try {
    return Uint8List.fromList(
      await handle.read(AppConstants.maxRemoverFileSizeBytes + 1),
    );
  } finally {
    await handle.close();
  }
}

/// Compares observable stat attributes only. This is useful for detecting a
/// change during one validation pass, but is deliberately not treated as file
/// identity and must never authorize deletion of the path.
bool _sameStatAttributes(FileStat expected, FileStat actual) =>
    expected.type == FileSystemEntityType.file &&
    actual.type == FileSystemEntityType.file &&
    expected.size == actual.size &&
    expected.modified == actual.modified &&
    expected.changed == actual.changed;

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

Future<void> _runBestEffort(Future<void> Function() cleanup) async {
  try {
    await cleanup();
  } catch (_) {
    // Auxiliary cleanup must not hide the operation's primary outcome.
  }
}

Uint8List _stripJpegBytes(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    throw const FormatException('Not a valid JPEG file');
  }

  final output = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
  var offset = 2;
  var inScan = false;
  var hasScan = false;
  while (true) {
    if (offset >= bytes.length) {
      throw const FormatException('JPEG is missing an EOI marker');
    }

    var markerStart = offset;
    if (inScan) {
      final entropyStart = offset;
      while (bytes[offset] != 0xFF) {
        offset++;
        if (offset >= bytes.length) {
          throw const FormatException('JPEG is missing an EOI marker');
        }
      }
      markerStart = offset;
      output.add(bytes.sublist(entropyStart, markerStart));
    } else if (bytes[offset] != 0xFF) {
      throw const FormatException('Invalid JPEG marker stream');
    }

    while (offset < bytes.length && bytes[offset] == 0xFF) {
      offset++;
    }
    if (offset >= bytes.length) {
      throw const FormatException('Truncated JPEG scan marker');
    }

    final marker = bytes[offset++];
    if (inScan && (marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7))) {
      output.add(bytes.sublist(markerStart, offset));
      continue;
    }
    if (marker == 0xD9) {
      if (!hasScan) {
        throw const FormatException('JPEG is missing an SOS marker');
      }
      output.add(bytes.sublist(markerStart, offset));
      return output.toBytes();
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      output.add(bytes.sublist(markerStart, offset));
      continue;
    }
    if (marker == 0x00 || marker == 0xD8) {
      throw const FormatException('Invalid JPEG marker stream');
    }
    if (offset + 2 > bytes.length) {
      throw const FormatException('Truncated JPEG segment length');
    }
    final length = ByteData.sublistView(
      bytes,
      offset,
      offset + 2,
    ).getUint16(0);
    if (length < 2 || offset + length > bytes.length) {
      throw const FormatException('Invalid JPEG segment length');
    }
    final segmentEnd = offset + length;
    const strippedMarkers = {0xE1, 0xE2, 0xEC, 0xED, 0xEE, 0xFE};
    if (!strippedMarkers.contains(marker)) {
      output.add(bytes.sublist(markerStart, segmentEnd));
    }
    offset = segmentEnd;

    if (marker == 0xDA) {
      hasScan = true;
      inScan = true;
    } else {
      // DNL may occur inside entropy-coded data and resumes the same scan.
      inScan = inScan && marker == 0xDC;
    }
  }
}

/// Strips a PNG clean copy from [bytes].
///
/// With a null or empty [selectiveLabels] the full-strip set applies and
/// every tEXt/zTXt/iTXt chunk plus the eXIf and tIME chunks are removed.
/// With a non-empty [selectiveLabels] only text chunks whose keyword equals
/// one of the labels are removed; unselected text chunks and the eXIf/tIME
/// chunks are preserved because the caller asked to delete just the
/// selected fields.
Uint8List _stripPngBytes(Uint8List bytes, {Set<String>? selectiveLabels}) =>
    _stripPngBytesWithReport(bytes, selectiveLabels: selectiveLabels).bytes;

({Uint8List bytes, Set<String> removedLabels}) _stripPngBytesWithReport(
  Uint8List bytes, {
  Set<String>? selectiveLabels,
}) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) {
    throw const FormatException('Not a valid PNG file');
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      throw const FormatException('Not a valid PNG file');
    }
  }
  final isSelective = selectiveLabels != null && selectiveLabels.isNotEmpty;
  final removedLabels = <String>{};
  final output = BytesBuilder(copy: false)..add(signature);
  var offset = 8;
  while (true) {
    if (offset == bytes.length) {
      throw const FormatException('PNG is missing an IEND chunk');
    }
    if (bytes.length - offset < 12) {
      throw const FormatException('Truncated PNG chunk');
    }
    final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (length > bytes.length - offset - 12) {
      throw const FormatException('Invalid PNG chunk length');
    }
    final chunkEnd = offset + 12 + length;
    final storedCrc = ByteData.sublistView(
      bytes,
      chunkEnd - 4,
      chunkEnd,
    ).getUint32(0);
    final calculatedCrc = _pngCrc32(bytes, offset + 4, chunkEnd - 4);
    if (storedCrc != calculatedCrc) {
      throw const FormatException('Invalid PNG chunk CRC');
    }
    if (type == 'IEND' && length != 0) {
      throw const FormatException('Invalid PNG IEND chunk');
    }
    final matchedLabel = isSelective
        ? _matchingSelectivePngLabel(
            type,
            bytes,
            offset + 8,
            chunkEnd - 4,
            selectiveLabels,
          )
        : null;
    if (matchedLabel != null) removedLabels.add(matchedLabel);
    final shouldKeep = isSelective
        ? matchedLabel == null
        // Full strip drops text chunks, EXIF, and the last-modified
        // timestamp (tIME leaks edit history; pHYs carry pixel dimensions).
        : !{'tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME'}.contains(type);
    if (shouldKeep) {
      output.add(bytes.sublist(offset, chunkEnd));
    }
    offset = chunkEnd;
    if (type == 'IEND') {
      if (isSelective && !removedLabels.containsAll(selectiveLabels)) {
        throw const FormatException('Unsupported selective metadata field');
      }
      return (
        bytes: output.toBytes(),
        removedLabels: Set.unmodifiable(removedLabels),
      );
    }
  }
}

void _validateSelectivePngOutput(
  Uint8List bytes,
  Set<String> requestedLabels,
) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) {
    throw const FormatException('Generated PNG is invalid');
  }
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) {
      throw const FormatException('Generated PNG is invalid');
    }
  }

  var offset = signature.length;
  while (true) {
    if (bytes.length - offset < 12) {
      throw const FormatException('Generated PNG is truncated');
    }
    final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
    if (length > bytes.length - offset - 12) {
      throw const FormatException('Generated PNG chunk is invalid');
    }
    final chunkEnd = offset + 12 + length;
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    final storedCrc = ByteData.sublistView(
      bytes,
      chunkEnd - 4,
      chunkEnd,
    ).getUint32(0);
    if (storedCrc != _pngCrc32(bytes, offset + 4, chunkEnd - 4)) {
      throw const FormatException('Generated PNG chunk CRC is invalid');
    }
    final matched = _matchingSelectivePngLabel(
      type,
      bytes,
      offset + 8,
      chunkEnd - 4,
      requestedLabels,
    );
    if (matched != null) {
      throw const FormatException('Requested PNG metadata remains in output');
    }
    offset = chunkEnd;
    if (type == 'IEND') {
      if (length != 0 || offset != bytes.length) {
        throw const FormatException('Generated PNG IEND is invalid');
      }
      return;
    }
  }
}

/// Returns true when [type] is a text chunk whose keyword (the extractor
/// `label`) exactly matches one of [selectiveLabels].
///
/// Non-text chunks never match: in selective mode eXIf/tIME are preserved
/// unless the label set names one (the extractor never does today; it only
/// outputs text keyword labels).
String? _matchingSelectivePngLabel(
  String type,
  Uint8List bytes,
  int dataStart,
  int dataEnd,
  Set<String> selectiveLabels,
) {
  if (type != 'tEXt' && type != 'zTXt' && type != 'iTXt') return null;
  var separator = dataStart;
  while (separator < dataEnd && bytes[separator] != 0) {
    separator++;
  }
  if (separator == dataStart || separator == dataEnd) return null;
  final label = String.fromCharCodes(bytes.sublist(dataStart, separator));
  return selectiveLabels.contains(label) ? label : null;
}

int _pngCrc32(Uint8List bytes, int start, int end) {
  var crc = 0xFFFFFFFF;
  for (var index = start; index < end; index++) {
    crc ^= bytes[index];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xEDB88320;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Blanks PDF document Info values in [bytes] with same-length spaces.
///
/// With a null [selectiveLabels] all nine known Info keys are blanked (full
/// strip). With a non-empty [selectiveLabels] only the keys
/// present in the set are blanked; unselected Info entries keep their
/// original values. Labels use the PDF Info key names surfaced by the
/// extractor (for example `Title`, `Author`, or `Trapped`).
///
/// The scan is a single linear pass using plain `String.indexOf` searches
/// with no regular expressions, so hostile input (for example an unterminated
/// literal packed with backslashes) is walked once instead of triggering the
/// exponential backtracking of the previous regex search. Output keeps the
/// input byte length: literal `(...)` values, hex `<...>` values, and value
/// tokens are replaced with an equal number of spaces while their delimiters
/// and the `/Key` markers survive.
///
/// Values inside page content streams that happen to match `/Key (...)` are
/// blanked too; this is the same best-effort MVP behavior as the previous
/// implementation and is documented as a known limitation.
Uint8List _stripPdfInfoBytes(
  Uint8List bytes, {
  Set<String>? selectiveLabels,
}) {
  if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
    throw const FormatException('Not a valid PDF file');
  }
  final text = latin1.decode(bytes);
  final outBytes = Uint8List.fromList(bytes);
  final occurrenceBudget = PdfInfoOccurrenceBudget();
  for (final key in _pdfInfoKeysToBlank(selectiveLabels)) {
    _blankPdfInfoKey(text, outBytes, key, occurrenceBudget);
  }
  return outBytes;
}

/// Blanks the value of every `/Key` marker for [key] in [text] within
/// [outBytes].
///
/// Positions align between [text] and [outBytes] because [text] is decoded as
/// latin-1 (one code unit per byte). Each occurrence is visited once and the
/// caller's search offset always moves forward, so the whole scan is linear
/// and never backtracks.
void _blankPdfInfoKey(
  String text,
  Uint8List outBytes,
  String key,
  PdfInfoOccurrenceBudget occurrenceBudget,
) {
  final marker = '/$key';
  var searchFrom = 0;
  while (true) {
    final pos = text.indexOf(marker, searchFrom);
    if (pos < 0) break;
    occurrenceBudget.record();
    final keyEnd = pos + marker.length;
    // A name character directly after `/Key` means this slash belongs to a
    // longer name such as `/TitleFoo`; skip it instead of blanking a suffix.
    if (keyEnd < text.length && isPdfInfoNameChar(text.codeUnitAt(keyEnd))) {
      searchFrom = keyEnd + 1;
      continue;
    }
    final range = parsePdfInfoValueRange(text, keyEnd);
    if (range == null) {
      throw const FormatException('Malformed PDF Info value');
    }
    _blankRange(outBytes, range.start, range.end);
    if (range.replacementAtStart case final replacement?) {
      outBytes[range.start] = replacement;
    }
    searchFrom = range.nextSearchOffset;
  }
}

/// Overwrites [outBytes] in the half-open range `[start, end)` with spaces,
/// preserving the total output length.
void _blankRange(Uint8List outBytes, int start, int end) {
  for (var index = start; index < end; index++) {
    outBytes[index] = 0x20;
  }
}

/// The known PDF Info dictionary keys blanked in full-strip mode.
const List<String> _pdfInfoKeys = [
  'Title',
  'Author',
  'Subject',
  'Keywords',
  'Creator',
  'Producer',
  'CreationDate',
  'ModDate',
  'Trapped',
];

const _pdfBestEffortWarning =
    'Generated PDF byte mutation passed bounded integrity validation, but the '
    'persisted artifact, PDF structure, and other metadata surfaces remain '
    'unverified.';

const _safBmpValidationWarning =
    'Generated BMP bytes were validated, but the persisted SAF artifact was '
    'not read back.';

/// Returns the Info keys to blank for the requested [selectiveLabels].
///
/// Null or empty labels return every known key (full strip); otherwise only
/// keys also present in the label set are returned.
List<String> _pdfInfoKeysToBlank(Set<String>? selectiveLabels) {
  if (selectiveLabels == null || selectiveLabels.isEmpty) return _pdfInfoKeys;
  return _pdfInfoKeys.where(selectiveLabels.contains).toList();
}
