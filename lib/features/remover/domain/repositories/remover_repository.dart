import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';

/// Contract for stripping metadata from files.
abstract class RemoverRepository {
  /// Strips metadata from [path] into [outputDirectory].
  ///
  /// Null [selectiveLabels] requests full removal. Empty labels, unknown labels,
  /// and selective requests for unsupported formats are rejected. Non-empty
  /// labels are supported for PNG text chunks and PDF Info keys.
  /// Labels use the `label` values produced by the viewer's extractors.
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    Set<String>? selectiveLabels,
  });
}
