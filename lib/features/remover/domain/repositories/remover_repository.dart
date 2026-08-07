import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';

/// Contract for stripping metadata from files.
abstract class RemoverRepository {
  /// Strips metadata from [path] into [outputDirectory].
  ///
  /// When [selectiveLabels] is null or empty, the full-strip behavior of each
  /// format applies (current behavior kept for backward compatibility). When
  /// non-empty, only the requested fields are removed for formats that
  /// support selective stripping (currently PNG text chunks and PDF Info
  /// keys). Other formats ignore the labels and always perform a full strip.
  /// Labels use the `label` values produced by the viewer's extractors.
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    Set<String>? selectiveLabels,
  });
}
