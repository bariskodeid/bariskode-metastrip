import 'dart:io';

import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';

/// Wraps [MetadataRemoverDatasource] and converts thrown errors into
/// [ProcessingResultEntity.failure] so the BLoC never crashes on a single
/// bad file.
///
/// Error messages are sanitized to avoid leaking absolute filesystem paths
/// into UI state (which users may screenshot for bug reports).
class RemoverRepositoryImpl implements RemoverRepository {
  RemoverRepositoryImpl([MetadataRemoverDatasource? datasource])
      : _datasource = datasource ?? MetadataRemoverDatasource();

  final MetadataRemoverDatasource _datasource;

  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    String? outputDirectory,
  }) async {
    try {
      final output = await _datasource.stripMetadata(
        path,
        outputDirectory: outputDirectory,
      );
      final stat = await output.stat();
      return ProcessingResultEntity.success(
        inputPath: path,
        outputPath: output.path,
        bytesWritten: stat.size,
      );
    } catch (error) {
      return ProcessingResultEntity.failure(
        inputPath: path,
        error: _sanitizeError(error),
      );
    }
  }

  /// Maps known exception types to short, opaque messages and strips absolute
  /// paths so filesystem layout is not disclosed in the UI.
  String _sanitizeError(Object error) {
    if (error is FormatException) return 'File format invalid or corrupt';
    if (error is FileSystemException) {
      return 'File system error: unreadable or unwritable';
    }
    final raw = error.toString();
    // Strip path-like substrings (Windows drive paths and Unix paths).
    final sanitized = raw.replaceAll(
      RegExp(r'[A-Za-z]:[\\/]\S+|/\S+'),
      '<path>',
    );
    return sanitized.length > 200
        ? '${sanitized.substring(0, 200)}...'
        : sanitized;
  }
}
