/// Broad file families used by capability-aware UI and routing.
enum FormatCategory {
  image,
  video,
  audio,
  document,
  archive,
}

/// The highest support level currently available for a format.
enum SupportLevel {
  filesystemOnly,
  extractOnly,
  removeFull,
  removeSelective,
}

/// The dominant I/O strategy required by the current implementation.
enum ProcessingStrategy {
  inMemory,
  streaming,
  temporaryFile,
  platformAdapter,
}

/// Declarative output validation available after metadata removal.
enum OutputValidationStrategy {
  none,
  signature,
  containerStructure,
  bestEffort,
}

/// Confidence level for removal within the documented stripper scope.
enum RemovalCoverage {
  unavailable,
  verifiedSupportedScope,
  bestEffort,
}

/// Feature-independent declaration of support for one format or alias family.
///
/// Handler factories are deliberately opaque. Core records whether a feature
/// handler exists without importing feature implementations or constructing
/// them. Feature-owned registries retain all parser and stripper logic.
class FormatCapability {
  const FormatCapability({
    required this.extensions,
    required this.mimeTypes,
    required this.category,
    required this.supportsExtraction,
    required this.supportsFullRemoval,
    required this.supportsSelectiveRemoval,
    required this.processingStrategy,
    required this.extractionHandlerFactory,
    required this.removalHandlerFactory,
    this.extractionSizeLimitBytes,
    this.removalSizeLimitBytes,
    this.outputValidationStrategy = OutputValidationStrategy.none,
    RemovalCoverage? removalCoverage,
    this.knownLimitations = const [],
    this.isExperimental = false,
  }) : _removalCoverage = removalCoverage;

  final Set<String> extensions;
  final Set<String> mimeTypes;
  final FormatCategory category;
  final bool supportsExtraction;
  final bool supportsFullRemoval;
  final bool supportsSelectiveRemoval;
  final ProcessingStrategy processingStrategy;
  final Object Function()? extractionHandlerFactory;
  final Object Function()? removalHandlerFactory;
  final int? extractionSizeLimitBytes;
  final int? removalSizeLimitBytes;
  final OutputValidationStrategy outputValidationStrategy;
  final RemovalCoverage? _removalCoverage;
  final List<String> knownLimitations;
  final bool isExperimental;

  RemovalCoverage get removalCoverage =>
      _removalCoverage ??
      (supportsFullRemoval
          ? RemovalCoverage.bestEffort
          : RemovalCoverage.unavailable);

  SupportLevel get supportLevel {
    if (supportsSelectiveRemoval) return SupportLevel.removeSelective;
    if (supportsFullRemoval) return SupportLevel.removeFull;
    if (supportsExtraction) return SupportLevel.extractOnly;
    return SupportLevel.filesystemOnly;
  }
}
