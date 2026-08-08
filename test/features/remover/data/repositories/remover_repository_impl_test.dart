import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';

void main() {
  test('unknown exception details are not exposed', () async {
    final repository = RemoverRepositoryImpl(_ThrowingDatasource());

    final result = await repository.stripFile(
      '/private/input.jpg',
      outputDirectory: '/private/output',
      policy: const StripPolicy.supportedCleanup(),
    );

    expect(result.error, 'Unexpected processing error');
    expect(result.error, isNot(contains('secret')));
    expect(result.error, isNot(contains('/private')));
  });

  test('post-write output stat failure keeps a successful result', () async {
    final repository = RemoverRepositoryImpl(
      _SuccessfulDatasource(),
      (_) async => throw const FileSystemException('stat failed'),
    );

    final result = await repository.stripFile(
      '/input/photo.png',
      outputDirectory: '/output',
      policy: const StripPolicy.supportedCleanup(),
    );

    expect(result.success, isTrue);
    expect(result.outputPath, '/output/photo_clean.png');
    expect(result.bytesWritten, 0);
  });
}

class _ThrowingDatasource extends MetadataRemoverDatasource {
  @override
  Future<MetadataRemovalOutput> stripMetadataWithPolicy(
    String inputPath, {
    required String outputDirectory,
    required StripPolicy policy,
  }) {
    throw StateError('secret at /private/input.jpg');
  }
}

class _SuccessfulDatasource extends MetadataRemoverDatasource {
  @override
  Future<MetadataRemovalOutput> stripMetadataWithPolicy(
    String inputPath, {
    required String outputDirectory,
    required StripPolicy policy,
  }) async {
    return MetadataRemovalOutput(
      file: File('$outputDirectory/photo_clean.png'),
      report: StripReport(),
    );
  }
}
