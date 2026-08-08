import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';

/// Contract for stripping metadata from files.
abstract class RemoverRepository {
  /// Strips metadata from [path] into [outputDirectory].
  ///
  /// [policy] is required so an empty selective choice can never become full
  /// cleanup accidentally.
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    required StripPolicy policy,
  });
}
