import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';

/// Contract for stripping metadata from files.
abstract class RemoverRepository {
  Future<ProcessingResultEntity> stripFile(
    String path, {
    String? outputDirectory,
  });
}
