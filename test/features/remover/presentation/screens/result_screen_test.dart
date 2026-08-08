import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
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
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<ProcessingResultEntity> results,
}) {
  return tester.pumpWidget(
    MaterialApp(home: ResultScreen(results: results)),
  );
}
