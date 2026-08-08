import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/format/format_capability.dart';
import 'package:metastrip/core/format/format_registry.dart';

void main() {
  const viewerExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'tiff',
    'tif',
    'heic',
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    '3gp',
    'flv',
    'wmv',
    'mp3',
    'flac',
    'aac',
    'ogg',
    'wav',
    'm4a',
    'opus',
    'wma',
    'aiff',
    'aif',
    'aifc',
    'pdf',
    'docx',
    'xlsx',
    'pptx',
    'odt',
    'ods',
    'odp',
    'rtf',
    'txt',
    'zip',
    'tar',
    'apk',
    'epub',
  };

  const removerExtensions = <String>{
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
  };

  group('shared format capability registry', () {
    test('covers every extension currently accepted by the Viewer', () {
      expect(FormatRegistry.standard.extensions, viewerExtensions);
      expect(FormatRegistry.standard.extensions, hasLength(41));

      for (final extension in viewerExtensions) {
        expect(
          FormatRegistry.standard.lookup(extension),
          isNotNull,
          reason: 'Missing Viewer capability for .$extension',
        );
      }
    });

    test('advertises exactly the Phase 4 removable extensions', () {
      expect(FormatRegistry.standard.removableExtensions, removerExtensions);
      expect(FormatRegistry.standard.removableExtensions, hasLength(20));
    });

    test('normalizes case, whitespace, and any leading dots', () {
      final registry = FormatRegistry.standard;
      final jpeg = registry.lookup('jpeg');

      expect(registry.lookup('JpEg'), same(jpeg));
      expect(registry.lookup('.JPEG'), same(jpeg));
      expect(registry.lookup('  ..JpEg  '), same(jpeg));
      expect(registry.lookup(''), isNull);
      expect(registry.lookup('...'), isNull);
      expect(registry.lookup('.unknown'), isNull);
    });

    test('separates extraction, full removal, and selective removal', () {
      final registry = FormatRegistry.standard;

      final png = registry.lookup('png')!;
      expect(png.supportsExtraction, isTrue);
      expect(png.supportsFullRemoval, isTrue);
      expect(png.supportsSelectiveRemoval, isTrue);

      final pdf = registry.lookup('pdf')!;
      expect(pdf.supportsExtraction, isTrue);
      expect(pdf.supportsFullRemoval, isTrue);
      expect(pdf.supportsSelectiveRemoval, isTrue);

      final jpeg = registry.lookup('jpg')!;
      expect(jpeg.supportsExtraction, isTrue);
      expect(jpeg.supportsFullRemoval, isTrue);
      expect(jpeg.supportsSelectiveRemoval, isFalse);

      final bmp = registry.lookup('bmp')!;
      expect(bmp.supportsExtraction, isTrue);
      expect(bmp.supportsFullRemoval, isTrue);
      expect(bmp.supportsSelectiveRemoval, isFalse);

      final zip = registry.lookup('zip')!;
      expect(zip.supportsExtraction, isTrue);
      expect(zip.supportsFullRemoval, isTrue);
      expect(zip.supportsSelectiveRemoval, isFalse);
      expect(zip.category, FormatCategory.archive);
      expect(
        zip.outputValidationStrategy,
        OutputValidationStrategy.containerStructure,
      );

      for (final extension in ['tiff', 'tif']) {
        final tiff = registry.lookup(extension)!;
        expect(tiff.supportsExtraction, isTrue);
        expect(tiff.supportsFullRemoval, isFalse);
        expect(tiff.supportsSelectiveRemoval, isFalse);
      }

      final mp4 = registry.lookup('mp4')!;
      expect(mp4.supportsExtraction, isFalse);
      expect(mp4.supportsFullRemoval, isFalse);
      expect(mp4.supportsSelectiveRemoval, isFalse);
    });

    test('declares a processing strategy for every format', () {
      expect(ProcessingStrategy.values, {
        ProcessingStrategy.inMemory,
        ProcessingStrategy.streaming,
        ProcessingStrategy.temporaryFile,
        ProcessingStrategy.platformAdapter,
      });

      for (final extension in viewerExtensions) {
        expect(
          FormatRegistry.standard.lookup(extension)!.processingStrategy,
          isA<ProcessingStrategy>(),
          reason: 'Missing processing strategy for .$extension',
        );
      }
    });

    test('labels best-effort removal without claiming verified coverage', () {
      final registry = FormatRegistry.standard;

      expect(
        registry.lookup('pdf')!.removalCoverage,
        RemovalCoverage.bestEffort,
      );
      expect(
        registry.lookup('ogg')!.removalCoverage,
        RemovalCoverage.bestEffort,
      );
      expect(
        registry.lookup('jpeg')!.removalCoverage,
        RemovalCoverage.bestEffort,
      );
      expect(
        registry.lookup('mp4')!.removalCoverage,
        RemovalCoverage.unavailable,
      );
    });

    test('the standard registry advertises only capabilities with handlers',
        () {
      expect(FormatRegistry.standard.handlerConsistencyIssues, isEmpty);
    });

    test('reports handler map declarations missing in either direction', () {
      final registry = FormatRegistry(
        capabilities: [
          _capability(
            supportsExtraction: true,
            extractionHandlerFactory: Object.new,
            supportsFullRemoval: true,
            removalHandlerFactory: Object.new,
          ),
        ],
      );

      expect(
        registry.handlerMapConsistencyIssues(
          extractionHandlerExtensions: const ['extra'],
          removalHandlerExtensions: const ['test'],
        ),
        containsAll([
          contains('.test advertises extraction'),
          contains('.extra has a extraction handler'),
        ]),
      );
    });
  });

  group('advertised-handler consistency', () {
    test('detects advertised extraction without an extraction handler', () {
      final registry = FormatRegistry(
        capabilities: [
          _capability(
            supportsExtraction: true,
            extractionHandlerFactory: null,
          ),
        ],
      );

      expect(
        registry.handlerConsistencyIssues,
        contains(contains('extraction')),
      );
    });

    test('detects an extraction handler that is not advertised', () {
      final registry = FormatRegistry(
        capabilities: [
          _capability(
            supportsExtraction: false,
            extractionHandlerFactory: Object.new,
          ),
        ],
      );

      expect(
        registry.handlerConsistencyIssues,
        contains(contains('extraction')),
      );
    });

    test('detects advertised removal without a removal handler', () {
      final registry = FormatRegistry(
        capabilities: [
          _capability(
            supportsFullRemoval: true,
            removalHandlerFactory: null,
          ),
        ],
      );

      expect(
        registry.handlerConsistencyIssues,
        contains(contains('removal')),
      );
    });

    test('detects a removal handler that is not advertised', () {
      final registry = FormatRegistry(
        capabilities: [
          _capability(
            supportsFullRemoval: false,
            removalHandlerFactory: Object.new,
          ),
        ],
      );

      expect(
        registry.handlerConsistencyIssues,
        contains(contains('removal')),
      );
    });

    test('detects selective support without full removal support', () {
      final registry = FormatRegistry(
        capabilities: [
          _capability(
            supportsFullRemoval: false,
            supportsSelectiveRemoval: true,
          ),
        ],
      );

      expect(
        registry.handlerConsistencyIssues,
        contains(contains('selective')),
      );
    });
  });
}

FormatCapability _capability({
  bool supportsExtraction = false,
  bool supportsFullRemoval = false,
  bool supportsSelectiveRemoval = false,
  Object Function()? extractionHandlerFactory,
  Object Function()? removalHandlerFactory,
}) {
  return FormatCapability(
    extensions: const {'test'},
    mimeTypes: const {'application/x-test'},
    category: FormatCategory.document,
    supportsExtraction: supportsExtraction,
    supportsFullRemoval: supportsFullRemoval,
    supportsSelectiveRemoval: supportsSelectiveRemoval,
    processingStrategy: ProcessingStrategy.inMemory,
    extractionHandlerFactory: extractionHandlerFactory,
    removalHandlerFactory: removalHandlerFactory,
  );
}
