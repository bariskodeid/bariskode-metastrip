import 'dart:io';

import 'package:metastrip/core/errors/app_exceptions.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:saf/saf.dart';

/// Wraps [MetadataRemoverDatasource] and converts thrown errors into
/// [ProcessingResultEntity.failure] so the BLoC never crashes on a single
/// bad file.
///
/// Error messages use a fixed allowlist so exception details never reach UI.
class RemoverRepositoryImpl implements RemoverRepository {
  RemoverRepositoryImpl([
    MetadataRemoverDatasource? datasource,
    Future<int> Function(File output)? outputLength,
  ])  : _datasource = datasource ?? MetadataRemoverDatasource(),
        _outputLength = outputLength;

  final MetadataRemoverDatasource _datasource;
  final Future<int> Function(File output)? _outputLength;

  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    required StripPolicy policy,
  }) async {
    try {
      final removal = await _datasource.stripMetadataWithPolicy(
        path,
        outputDirectory: outputDirectory,
        policy: policy,
      );
      final output = removal.file;
      final bytesWritten = await _bestEffortOutputLength(output);
      return ProcessingResultEntity.success(
        inputPath: path,
        outputPath: output.path,
        bytesWritten: bytesWritten,
        report: removal.report,
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

  Future<int> _bestEffortOutputLength(File output) async {
    try {
      final outputLength = _outputLength;
      if (outputLength != null) return await outputLength(output);
      return output.path.startsWith('content://')
          ? await _safOutputLength(output.path)
          : (await output.stat()).size;
    } on Object {
      return 0;
    }
  }

  String _safeErrorMessage(Object error) {
    if (error is FormatException) {
      return switch (error.message) {
        'Selective cleanup is unavailable for this format' =>
          'Selective cleanup is unavailable for this file type',
        'Metadata field does not match file format' =>
          'Selected metadata fields do not match this file type',
        'No metadata fields selected' => 'Select at least one metadata field',
        'Output validation failed; unverified copy may remain' =>
          'Output validation failed; unverified copy may remain',
        _ => 'File format invalid or corrupt',
      };
    }
    if (error is OutputFolderException) {
      return 'Output folder unavailable or unwritable';
    }
    if (error is FileSystemException) {
      return 'File system error: unreadable or unwritable';
    }
    return 'Unexpected processing error';
  }
}
