import 'dart:io';

import 'package:metastrip/core/errors/app_exceptions.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:saf/saf.dart';

/// Wraps [MetadataRemoverDatasource] and converts thrown errors into
/// [ProcessingResultEntity.failure] so the BLoC never crashes on a single
/// bad file.
///
/// Error messages use a fixed allowlist so exception details never reach UI.
class RemoverRepositoryImpl implements RemoverRepository {
  RemoverRepositoryImpl([MetadataRemoverDatasource? datasource])
      : _datasource = datasource ?? MetadataRemoverDatasource();

  final MetadataRemoverDatasource _datasource;

  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
  }) async {
    try {
      final output = await _datasource.stripMetadata(
        path,
        outputDirectory: outputDirectory,
      );
      final bytesWritten = output.path.startsWith('content://')
          ? await _safOutputLength(output.path)
          : (await output.stat()).size;
      return ProcessingResultEntity.success(
        inputPath: path,
        outputPath: output.path,
        bytesWritten: bytesWritten,
      );
    } catch (error) {
      return ProcessingResultEntity.failure(
        inputPath: path,
        error: _safeErrorMessage(error),
      );
    }
  }

  Future<int> _safOutputLength(String uri) async {
    final document = await Saf().stat(uri);
    return document?.length ?? 0;
  }

  String _safeErrorMessage(Object error) {
    if (error is FormatException) return 'File format invalid or corrupt';
    if (error is OutputFolderException) {
      return 'Output folder unavailable or unwritable';
    }
    if (error is FileSystemException) {
      return 'File system error: unreadable or unwritable';
    }
    return 'Unexpected processing error';
  }
}
