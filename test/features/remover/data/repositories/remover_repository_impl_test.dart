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

  test('no-space file system exception reports storage full', () async {
    final repository = RemoverRepositoryImpl(
      _FileSystemThrowingDatasource(
        const FileSystemException('No space left on device'),
      ),
    );

    final result = await repository.stripFile(
      '/input/photo.jpg',
      outputDirectory: '/output',
      policy: const StripPolicy.supportedCleanup(),
    );

    expect(result.error, 'Storage full. Free up space and retry.');
  });

  test('errno 28 file system exception reports storage full', () async {
    final repository = RemoverRepositoryImpl(
      _FileSystemThrowingDatasource(
        const FileSystemException(
          'write failed',
          '/output/photo_clean.jpg',
          OSError('No error details', 28),
        ),
      ),
    );

    final result = await repository.stripFile(
      '/input/photo.jpg',
      outputDirectory: '/output',
      policy: const StripPolicy.supportedCleanup(),
    );

    expect(result.error, 'Storage full. Free up space and retry.');
  });

  test('ordinary file system exception remains generic', () async {
    final repository = RemoverRepositoryImpl(
      _FileSystemThrowingDatasource(
        const FileSystemException('Permission denied'),
      ),
    );

    final result = await repository.stripFile(
      '/input/photo.jpg',
      outputDirectory: '/output',
      policy: const StripPolicy.supportedCleanup(),
    );

    expect(result.error, 'File system error: unreadable or unwritable');
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

  group('fail-closed rejections map to specific messages', () {
    const cases = {
      'Ogg comment packet spans pages':
          'Ogg/Opus files with embedded cover art or other large comments '
              'are not supported yet',
      'PDF Info dictionary is not stored as plain text (compressed '
              'object streams are not supported)':
          'This PDF stores its document info in a compressed object '
              'stream, which is not supported yet',
      'EPUB mimetype must be the first entry, stored, with no extra field':
          'This EPUB has a missing or invalid mimetype entry, so it '
              'cannot be cleaned safely',
      'EPUB is missing the required mimetype entry':
          'This EPUB has a missing or invalid mimetype entry, so it '
              'cannot be cleaned safely',
      'EPUB mimetype entry does not contain application/epub+zip':
          'This EPUB has a missing or invalid mimetype entry, so it '
              'cannot be cleaned safely',
      'ZIP directory mismatch':
          'The ZIP directory does not match its contents, so it cannot be '
              'cleaned safely',
    };
    for (final MapEntry(key: thrown, value: shown) in cases.entries) {
      test(thrown, () async {
        final repository = RemoverRepositoryImpl(
          _FormatThrowingDatasource(FormatException(thrown)),
        );

        final result = await repository.stripFile(
          '/input/file.bin',
          outputDirectory: '/output',
          policy: const StripPolicy.supportedCleanup(),
        );

        expect(result.success, isFalse);
        expect(result.error, shown);
      });
    }

    test('object-stream PDF rejection reaches the user message', () async {
      final dir = await Directory.systemTemp.createTemp('metastrip_repo_');
      addTearDown(() => dir.delete(recursive: true));
      final input = File('${dir.path}${Platform.pathSeparator}doc.pdf');
      await input.writeAsString(
        '%PDF-1.5\n'
        '5 0 obj\n<< /Type /ObjStm /N 1 /First 4 /Length 30 >>\n'
        'stream\n7 0 << /Title (Secret) >>\nendstream\nendobj\n'
        '9 0 obj\n<< /Type /XRef /Size 10 /Info 7 0 R /Length 0 >>\n'
        'stream\n\nendstream\nendobj\nstartxref\n0\n%%EOF',
      );

      final result = await RemoverRepositoryImpl().stripFile(
        input.path,
        outputDirectory: dir.path,
        policy: const StripPolicy.supportedCleanup(),
      );

      expect(
        result.error,
        'This PDF stores its document info in a compressed object stream, '
        'which is not supported yet',
      );
    });

    test('other format errors stay generic', () async {
      final repository = RemoverRepositoryImpl(
        _FormatThrowingDatasource(
          const FormatException('Truncated GIF sub-block'),
        ),
      );

      final result = await repository.stripFile(
        '/input/file.gif',
        outputDirectory: '/output',
        policy: const StripPolicy.supportedCleanup(),
      );

      expect(result.error, 'File format invalid or corrupt');
    });
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

class _FileSystemThrowingDatasource extends MetadataRemoverDatasource {
  _FileSystemThrowingDatasource(this.exception);

  final FileSystemException exception;

  @override
  Future<MetadataRemovalOutput> stripMetadataWithPolicy(
    String inputPath, {
    required String outputDirectory,
    required StripPolicy policy,
  }) {
    throw exception;
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

class _FormatThrowingDatasource extends MetadataRemoverDatasource {
  _FormatThrowingDatasource(this.exception);

  final FormatException exception;

  @override
  Future<MetadataRemovalOutput> stripMetadataWithPolicy(
    String inputPath, {
    required String outputDirectory,
    required StripPolicy policy,
  }) {
    throw exception;
  }
}
