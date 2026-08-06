import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';

void main() {
  test('unknown exception details are not exposed', () async {
    final repository = RemoverRepositoryImpl(_ThrowingDatasource());

    final result = await repository.stripFile(
      '/private/input.jpg',
      outputDirectory: '/private/output',
    );

    expect(result.error, 'Unexpected processing error');
    expect(result.error, isNot(contains('secret')));
    expect(result.error, isNot(contains('/private')));
  });
}

class _ThrowingDatasource extends MetadataRemoverDatasource {
  @override
  Future<File> stripMetadata(
    String inputPath, {
    String? outputDirectory,
  }) {
    throw StateError('secret at /private/input.jpg');
  }
}
