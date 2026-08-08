import 'package:metastrip/core/format/format_registry.dart';

/// Backwards-compatible access to file extensions accepted by the Viewer.
class SupportedExtensions {
  SupportedExtensions._();

  static final List<String> values =
      FormatRegistry.standard.extensions.toList(growable: false);

  static bool contains(String extension) =>
      FormatRegistry.standard.supportsViewerExtension(extension);
}

/// Extensions the Remover MVP can actually strip.
///
/// The capability registry is the source of truth. This facade remains for
/// compatibility with existing Viewer/Remover callers.
class RemoverStrippableExtensions {
  RemoverStrippableExtensions._();

  static final Set<String> values = FormatRegistry.standard.removableExtensions;

  static bool contains(String extension) =>
      FormatRegistry.standard.supportsRemoval(extension);
}
