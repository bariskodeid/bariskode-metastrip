import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/supported_extensions.dart';
import 'package:metastrip/core/format/format_registry.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/format_registry.dart';

void main() {
  test('remover registry contains exactly the supported MVP formats', () {
    expect(RemoverStrippableExtensions.values, {
      'jpg',
      'jpeg',
      'png',
      'pdf',
      'mp3',
      'flac',
      'ogg',
      'opus',
      'wav',
      'aiff',
      'docx',
      'xlsx',
      'pptx',
      'odt',
      'ods',
      'odp',
      'gif',
      'webp',
      'bmp',
      'zip',
    });
  });

  test('every registered format has a datasource route', () {
    for (final extension in RemoverStrippableExtensions.values) {
      expect(
        MetadataRemoverDatasource.supportsExtension(extension),
        isTrue,
        reason: 'Missing datasource route for $extension',
      );
    }
  });

  test('datasource routes and advertised removal capability agree', () {
    expect(MetadataRemoverDatasource.handlerConsistencyIssues, isEmpty);
    expect(
      FormatRegistry.standard.handlerMapConsistencyIssues(
        removalHandlerExtensions: MetadataRemoverDatasource.handlerExtensions,
      ),
      isEmpty,
    );
  });

  test('viewer routes and advertised extraction capability agree', () {
    expect(extractionHandlerConsistencyIssues, isEmpty);
    expect(
      supportedExtractionExtensions,
      FormatRegistry.standard.extractionExtensions,
    );
  });

  test('routing is case insensitive and rejects unregistered aliases', () {
    expect(MetadataRemoverDatasource.supportsExtension('JpEg'), isTrue);
    expect(MetadataRemoverDatasource.supportsExtension('AIF'), isFalse);
    expect(MetadataRemoverDatasource.supportsExtension('bmp'), isTrue);
    expect(MetadataRemoverDatasource.supportsExtension('tiff'), isFalse);
    expect(MetadataRemoverDatasource.supportsExtension('tif'), isFalse);
    expect(MetadataRemoverDatasource.supportsExtension('zip'), isTrue);
    expect(MetadataRemoverDatasource.supportsExtension('.ZIP'), isTrue);
    expect(MetadataRemoverDatasource.supportsExtension('mp4'), isFalse);
  });
}
