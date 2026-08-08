import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';
import 'package:metastrip/features/remover/presentation/screens/result_screen.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('summarizes successful and failed processing results',
      (tester) async {
    await _pumpScreen(
      tester,
      results: [
        ProcessingResultEntity.success(
          inputPath: p.join('fixtures', 'photo.jpg'),
          outputPath: p.join('output', 'photo_clean.jpg'),
          bytesWritten: 1024,
        ),
        ProcessingResultEntity.success(
          inputPath: p.join('fixtures', 'document.pdf'),
          outputPath: p.join('output', 'document_clean.pdf'),
          bytesWritten: 512,
        ),
        ProcessingResultEntity.failure(
          inputPath: p.join('fixtures', 'broken.png'),
          error: 'Malformed PNG',
        ),
      ],
    );

    expect(find.text('COPIES CREATED'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(find.text('photo_clean.jpg'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('document_clean.pdf'),
      100,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('document_clean.pdf'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Malformed PNG'),
      100,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Malformed PNG'), findsOneWidget);
  });

  testWidgets('shows zero summary and empty message for no results',
      (tester) async {
    await _pumpScreen(tester, results: const []);

    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('No files were processed.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'DONE'), findsOneWidget);
  });

  testWidgets('describes the complete remover MVP scope', (tester) async {
    await _pumpScreen(tester, results: const []);

    expect(
      find.text(
        'Audio, image, and office metadata cleanup. '
        'PDF DocInfo cleanup is best effort.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('distinguishes local PNG, SAF PNG, and PDF outcomes',
      (tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pngAuthor = MetadataFieldId.pngText('Author');
    await _pumpScreen(
      tester,
      results: [
        ProcessingResultEntity.success(
          inputPath: p.join('fixtures', 'photo.png'),
          outputPath: p.join('output', 'photo_clean.png'),
          report: StripReport.snapshot(
            requestedFieldIds: [pngAuthor],
            removedFieldIds: [pngAuthor],
            unsupportedFieldIds: const [MetadataFieldId.pdfInfoTitle],
            verificationOutcome: StripVerificationOutcome.verified,
            outputValidated: true,
            reencoded: true,
          ),
        ),
        ProcessingResultEntity.success(
          inputPath: p.join('fixtures', 'document.pdf'),
          outputPath: p.join('output', 'document_clean.pdf'),
          report: StripReport.snapshot(
            requestedFieldIds: const [MetadataFieldId.pdfInfoAuthor],
            warnings: const ['PDF metadata cleanup was not verified'],
            verificationOutcome: StripVerificationOutcome.attemptedUnverified,
          ),
        ),
        ProcessingResultEntity.success(
          inputPath: p.join('fixtures', 'saf-photo.png'),
          outputPath: 'content://output/saf-photo.png',
          report: StripReport.snapshot(
            requestedFieldIds: [pngAuthor],
            removedFieldIds: [pngAuthor],
            verificationOutcome: StripVerificationOutcome.attemptedUnverified,
            warnings: const [
              'Generated PNG bytes were validated, but the persisted SAF '
                  'artifact was not read back.',
            ],
          ),
        ),
        ProcessingResultEntity.success(
          inputPath: p.join('fixtures', 'full-document.pdf'),
          outputPath: p.join('output', 'full-document_clean.pdf'),
          report: StripReport.snapshot(
            warnings: const ['PDF metadata cleanup was not verified'],
            verificationOutcome: StripVerificationOutcome.attemptedUnverified,
          ),
        ),
      ],
    );

    expect(find.textContaining('1 selected field(s) removed'), findsOneWidget);
    expect(
      find.textContaining('Local persisted artifact verified'),
      findsOneWidget,
    );
    expect(
        find.textContaining('1 selected field(s) unsupported'), findsOneWidget);
    expect(find.textContaining('Output was reencoded'), findsOneWidget);
    expect(
      find.textContaining('1 selected field(s) best-effort attempted'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Generated clean bytes passed validation; persisted output unverified',
      ),
      findsOneWidget,
    );
    expect(
        find.textContaining('Cleanup best-effort attempted'), findsOneWidget);
    expect(
      find.textContaining('PDF metadata cleanup was not verified'),
      findsNWidgets(2),
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<ProcessingResultEntity> results,
}) {
  return tester.pumpWidget(
    MaterialApp(home: ResultScreen(results: results)),
  );
}
