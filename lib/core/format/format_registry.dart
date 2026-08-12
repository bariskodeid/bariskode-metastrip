import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/format/format_capability.dart';

/// Shared, feature-independent source of truth for file format capabilities.
class FormatRegistry {
  FormatRegistry({required Iterable<FormatCapability> capabilities})
      : capabilities = List.unmodifiable(capabilities) {
    for (final capability in this.capabilities) {
      for (final extension in capability.extensions) {
        final normalized = normalizeExtension(extension);
        if (normalized.isEmpty) {
          throw ArgumentError.value(
              extension, 'extensions', 'Must not be empty');
        }
        if (_byExtension.containsKey(normalized)) {
          throw ArgumentError.value(
            extension,
            'extensions',
            'Duplicate normalized extension',
          );
        }
        _byExtension[normalized] = capability;
      }
    }
  }

  final List<FormatCapability> capabilities;
  final Map<String, FormatCapability> _byExtension = {};

  /// Production capability declarations for all Viewer-accepted formats.
  static final FormatRegistry standard = FormatRegistry(
    capabilities: _standardCapabilities,
  );

  Set<String> get extensions => Set.unmodifiable(_byExtension.keys);

  Set<String> get extractionExtensions => Set.unmodifiable(
        _byExtension.entries
            .where((entry) => entry.value.supportsExtraction)
            .map((entry) => entry.key),
      );

  Set<String> get removableExtensions => Set.unmodifiable(
        _byExtension.entries
            .where((entry) => entry.value.supportsFullRemoval)
            .map((entry) => entry.key),
      );

  Set<String> get selectiveRemovalExtensions => Set.unmodifiable(
        _byExtension.entries
            .where((entry) => entry.value.supportsSelectiveRemoval)
            .map((entry) => entry.key),
      );

  FormatCapability? lookup(String extension) {
    final normalized = normalizeExtension(extension);
    return normalized.isEmpty ? null : _byExtension[normalized];
  }

  bool supportsViewerExtension(String extension) => lookup(extension) != null;

  bool supportsRemoval(String extension) =>
      lookup(extension)?.supportsFullRemoval ?? false;

  /// Reports capability/handler declarations that disagree in either direction.
  List<String> get handlerConsistencyIssues {
    final issues = <String>[];
    for (final capability in capabilities) {
      final label = capability.extensions.map((value) => '.$value').join('/');
      final hasExtractionHandler = capability.extractionHandlerFactory != null;
      if (capability.supportsExtraction != hasExtractionHandler) {
        issues.add(
          '$label extraction support and handler declaration disagree',
        );
      }

      final hasRemovalHandler = capability.removalHandlerFactory != null;
      if (capability.supportsFullRemoval != hasRemovalHandler) {
        issues.add('$label removal support and handler declaration disagree');
      }
      if (capability.supportsSelectiveRemoval &&
          !capability.supportsFullRemoval) {
        issues.add('$label selective removal requires full removal support');
      }
      if (capability.supportsFullRemoval ==
          (capability.removalCoverage == RemovalCoverage.unavailable)) {
        issues.add('$label removal support and coverage disagree');
      }
    }
    return List.unmodifiable(issues);
  }

  /// Reports disagreements between declared support and feature handler maps.
  ///
  /// Features pass the extensions their concrete handler maps can route. This
  /// keeps the core declarative: it never imports, instantiates, or invokes a
  /// feature handler.
  List<String> handlerMapConsistencyIssues({
    Iterable<String>? extractionHandlerExtensions,
    Iterable<String>? removalHandlerExtensions,
  }) {
    final issues = <String>[];
    if (extractionHandlerExtensions != null) {
      _addHandlerMapIssues(
        issues: issues,
        kind: 'extraction',
        advertised: extractionExtensions,
        handlers: extractionHandlerExtensions,
      );
    }
    if (removalHandlerExtensions != null) {
      _addHandlerMapIssues(
        issues: issues,
        kind: 'removal',
        advertised: removableExtensions,
        handlers: removalHandlerExtensions,
      );
    }
    return List.unmodifiable(issues);
  }

  void _addHandlerMapIssues({
    required List<String> issues,
    required String kind,
    required Set<String> advertised,
    required Iterable<String> handlers,
  }) {
    final normalizedHandlers = handlers.map(normalizeExtension).toSet()
      ..remove('');
    for (final extension in advertised.difference(normalizedHandlers)) {
      issues.add('.$extension advertises $kind without a $kind handler');
    }
    for (final extension in normalizedHandlers.difference(advertised)) {
      issues.add('.$extension has a $kind handler without advertised support');
    }
  }

  /// Normalizes picker values, path extensions, and user-provided aliases.
  static String normalizeExtension(String extension) {
    return extension.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');
  }
}

Object _handlerDeclaration() => Object();

const _memoryLimit = AppConstants.maxRemoverFileSizeBytes;

const List<FormatCapability> _standardCapabilities = [
  FormatCapability(
    extensions: {'jpg', 'jpeg'},
    mimeTypes: {'image/jpeg'},
    category: FormatCategory.image,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxInlineExifSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.containerStructure,
    knownLimitations: [
      'Removal covers JPEG metadata segments handled by the current stripper.',
    ],
  ),
  FormatCapability(
    extensions: {'png'},
    mimeTypes: {'image/png'},
    category: FormatCategory.image,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: true,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxInlineExifSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    knownLimitations: [
      'Selective removal applies to PNG text keywords only.',
    ],
  ),
  FormatCapability(
    extensions: {'webp'},
    mimeTypes: {'image/webp'},
    category: FormatCategory.image,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxInlineExifSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    knownLimitations: [
      'WebP metadata can be removed only through the full-removal route.',
    ],
  ),
  FormatCapability(
    extensions: {'gif'},
    mimeTypes: {'image/gif'},
    category: FormatCategory.image,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxInlineExifSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    knownLimitations: ['Only understood GIF extension blocks are removed.'],
  ),
  FormatCapability(
    extensions: {'bmp'},
    mimeTypes: {'image/bmp'},
    category: FormatCategory.image,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxInlineExifSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.containerStructure,
    removalCoverage: RemovalCoverage.verifiedSupportedScope,
    knownLimitations: [
      'Only canonical 24/32-bit BITMAPINFOHEADER BMPs are supported.'
    ],
  ),
  FormatCapability(
    extensions: {'tiff', 'tif'},
    mimeTypes: {'image/tiff'},
    category: FormatCategory.image,
    supportsExtraction: true,
    supportsFullRemoval: false,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: null,
    extractionSizeLimitBytes: AppConstants.maxInlineExifSizeBytes,
    knownLimitations: [
      'TIFF writing and metadata removal are not implemented.'
    ],
  ),
  FormatCapability(
    extensions: {'heic'},
    mimeTypes: {'image/heic'},
    category: FormatCategory.image,
    supportsExtraction: false,
    supportsFullRemoval: false,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.platformAdapter,
    extractionHandlerFactory: null,
    removalHandlerFactory: null,
    knownLimitations: ['Only filesystem metadata is currently shown.'],
  ),
  FormatCapability(
    extensions: {'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'flv', 'wmv'},
    mimeTypes: {'video/*'},
    category: FormatCategory.video,
    supportsExtraction: false,
    supportsFullRemoval: false,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.platformAdapter,
    extractionHandlerFactory: null,
    removalHandlerFactory: null,
    knownLimitations: ['Only filesystem metadata is currently shown.'],
  ),
  FormatCapability(
    extensions: {'mp3'},
    mimeTypes: {'audio/mpeg'},
    category: FormatCategory.audio,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxAudioScanBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    knownLimitations: ['Extraction scans a bounded prefix and ID3v1 tail.'],
  ),
  FormatCapability(
    extensions: {'flac'},
    mimeTypes: {'audio/flac'},
    category: FormatCategory.audio,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: true,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxAudioScanBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    removalCoverage: RemovalCoverage.bestEffort,
    knownLimitations: [
      'FLAC selective cleanup removes selected Vorbis comment keys while '
          'preserving the vendor, other comments, blocks, and audio payload.',
    ],
  ),
  FormatCapability(
    extensions: {'ogg', 'opus'},
    mimeTypes: {'audio/ogg', 'audio/opus'},
    category: FormatCategory.audio,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxAudioScanBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    removalCoverage: RemovalCoverage.bestEffort,
    knownLimitations: [
      'Ogg/Opus cleanup is best effort and scans a bounded page window; '
          'selective removal remains disabled.',
    ],
  ),
  FormatCapability(
    extensions: {'wav'},
    mimeTypes: {'audio/wav'},
    category: FormatCategory.audio,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: true,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    knownLimitations: [
      'Selective cleanup removes only allowlisted LIST INFO fields; full '
          'cleanup retains the existing broader WAV metadata cleanup.'
    ],
  ),
  FormatCapability(
    extensions: {'aiff'},
    mimeTypes: {'audio/aiff'},
    category: FormatCategory.audio,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.signature,
    knownLimitations: ['Only understood AIFF metadata chunks are removed.'],
  ),
  FormatCapability(
    extensions: {'aac', 'm4a', 'wma', 'aif', 'aifc'},
    mimeTypes: {'audio/*'},
    category: FormatCategory.audio,
    supportsExtraction: false,
    supportsFullRemoval: false,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.streaming,
    extractionHandlerFactory: null,
    removalHandlerFactory: null,
    knownLimitations: ['Only filesystem metadata is currently shown.'],
  ),
  FormatCapability(
    extensions: {'pdf'},
    mimeTypes: {'application/pdf'},
    category: FormatCategory.document,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: true,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxPdfExtractionSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.bestEffort,
    removalCoverage: RemovalCoverage.bestEffort,
    knownLimitations: [
      'Removal is best-effort PDF Info cleanup, not comprehensive sanitization.',
      'Selective removal applies only to supported PDF Info keys.',
    ],
  ),
  FormatCapability(
    extensions: {'docx', 'xlsx', 'pptx'},
    mimeTypes: {
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    },
    category: FormatCategory.document,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: true,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.containerStructure,
    removalCoverage: RemovalCoverage.verifiedSupportedScope,
    knownLimitations: [
      'Selective removal is limited to stable IDs for standard core/app XML '
          'properties; custom and legacy Office properties are not supported.',
    ],
  ),
  FormatCapability(
    extensions: {'odt', 'ods', 'odp'},
    mimeTypes: {
      'application/vnd.oasis.opendocument.text',
      'application/vnd.oasis.opendocument.spreadsheet',
      'application/vnd.oasis.opendocument.presentation',
    },
    category: FormatCategory.document,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: true,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.containerStructure,
    removalCoverage: RemovalCoverage.verifiedSupportedScope,
    knownLimitations: [
      'Selective removal is limited to ten exact stable IDs for canonical '
          'dc/meta properties in one bounded meta.xml part.',
      'Custom and user-defined ODF properties are not supported.',
      'SAF persistence is attempted but not read back on device.',
    ],
  ),
  FormatCapability(
    extensions: {'rtf', 'txt'},
    mimeTypes: {'application/rtf', 'text/plain'},
    category: FormatCategory.document,
    supportsExtraction: false,
    supportsFullRemoval: false,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.streaming,
    extractionHandlerFactory: null,
    removalHandlerFactory: null,
    knownLimitations: ['Only filesystem metadata is currently shown.'],
  ),
  FormatCapability(
    extensions: {'zip'},
    mimeTypes: {'application/zip'},
    category: FormatCategory.archive,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
    outputValidationStrategy: OutputValidationStrategy.containerStructure,
    removalCoverage: RemovalCoverage.verifiedSupportedScope,
    knownLimitations: [
      'Only ZIP container metadata is cleaned; member payload metadata is not recursively cleaned.',
    ],
  ),
  FormatCapability(
    extensions: {'apk', 'epub'},
    mimeTypes: {
      'application/vnd.android.package-archive',
      'application/epub+zip',
    },
    category: FormatCategory.archive,
    supportsExtraction: true,
    supportsFullRemoval: true,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: _handlerDeclaration,
    removalHandlerFactory: _handlerDeclaration,
    extractionSizeLimitBytes: AppConstants.maxArchiveAndDocumentSizeBytes,
    removalSizeLimitBytes: _memoryLimit,
    outputValidationStrategy: OutputValidationStrategy.containerStructure,
    removalCoverage: RemovalCoverage.verifiedSupportedScope,
    knownLimitations: [
      'Container-only ZIP metadata cleanup; member payload metadata is not recursively cleaned.',
      'APK signatures are invalidated; output is not installable.',
      'EPUB output preserves the required mimetype entry.',
    ],
  ),
  FormatCapability(
    extensions: {'tar'},
    mimeTypes: {'application/x-tar'},
    category: FormatCategory.archive,
    supportsExtraction: false,
    supportsFullRemoval: false,
    supportsSelectiveRemoval: false,
    processingStrategy: ProcessingStrategy.streaming,
    extractionHandlerFactory: null,
    removalHandlerFactory: null,
    knownLimitations: ['Only filesystem metadata is currently shown.'],
  ),
];
