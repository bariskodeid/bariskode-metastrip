import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/screens/remover_screen.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

void main() {
  testWidgets('counts only supported files for cleanup', (tester) async {
    await _pumpScreen(
      tester,
      files: [_file('photo.JPG', 'JPG'), _file('clip.mp4', 'mp4')],
    );

    expect(
      find.text('2 FILE(S) QUEUED · 1 SUPPORTED FOR CLEANUP'),
      findsOneWidget,
    );
    expect(find.text('photo.JPG'), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.text('Unsupported by remover'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(
        find.widgetWithText(FilledButton, 'CLEAN 1 FILE(S)'), findsOneWidget);
  });

  testWidgets('disables cleanup for an unsupported-only queue', (tester) async {
    await _pumpScreen(
      tester,
      files: [_file('clip.mp4', 'mp4'), _file('notes.txt', 'txt')],
    );

    expect(
      find.text('2 FILE(S) QUEUED · 0 SUPPORTED FOR CLEANUP'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'CLEAN 0 FILE(S)'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('removing the only supported file disables cleanup',
      (tester) async {
    await _pumpScreen(
      tester,
      files: [_file('photo.jpg', 'jpg'), _file('clip.mp4', 'mp4')],
    );
    final supportedTile = find.ancestor(
      of: find.text('photo.jpg'),
      matching: find.byType(ListTile),
    );

    await tester.tap(
      find.descendant(
        of: supportedTile,
        matching: find.byTooltip('Remove from queue'),
      ),
    );
    await tester.pump();

    expect(find.text('photo.jpg'), findsNothing);
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(
      find.text('1 FILE(S) QUEUED · 0 SUPPORTED FOR CLEANUP'),
      findsOneWidget,
    );
  });

  testWidgets('clear queue shows the empty state', (tester) async {
    await _pumpScreen(tester, files: [_file('photo.jpg', 'jpg')]);

    await tester.tap(find.byTooltip('Clear queue'));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'ADD FILES'), findsOneWidget);
    expect(find.byTooltip('Clear queue'), findsNothing);
  });

  testWidgets('empty state ADD FILES opens the picker', (tester) async {
    var pickerCalls = 0;
    await _pumpScreen(
      tester,
      picker: () async {
        pickerCalls++;
        return null;
      },
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ADD FILES'));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
  });

  testWidgets('selected supported file enters the queue', (tester) async {
    await _pumpScreen(
      tester,
      picker: () async => [
        _platformFile('/picked/photo.jpg', name: 'photo.jpg', size: 1234),
      ],
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ADD FILES'));
    await tester.pump();
    await tester.pump();

    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('1 FILE(S) QUEUED · 1 SUPPORTED FOR CLEANUP'),
        findsOneWidget);
  });

  testWidgets('picker cancellation leaves the queue unchanged', (tester) async {
    await _pumpScreen(tester, picker: () async => null);

    await tester.tap(find.byTooltip('Add files'));
    await tester.pumpAndSettle();

    expect(find.text('0 FILE(S) QUEUED · 0 SUPPORTED FOR CLEANUP'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ADD FILES'), findsOneWidget);
  });

  testWidgets('picker failure shows feedback', (tester) async {
    await _pumpScreen(
      tester,
      picker: () async => throw StateError('picker unavailable'),
    );

    await tester.tap(find.byTooltip('Add files'));
    await tester.pump();

    expect(
      find.text('Unable to pick files. Check permissions and retry.'),
      findsOneWidget,
    );
  });

  testWidgets('duplicate selection shows feedback and is not queued',
      (tester) async {
    final file = _file('photo.jpg', 'jpg');
    await _pumpScreen(
      tester,
      files: [file],
      picker: () async => [
        _platformFile(file.path, name: file.name, size: file.sizeBytes),
      ],
    );

    await tester.tap(find.byTooltip('Add files'));
    await tester.pump();
    await tester.pump();

    expect(find.text('1 FILE(S) QUEUED · 1 SUPPORTED FOR CLEANUP'),
        findsOneWidget);
    expect(
      find.text(
        '1 file(s) skipped: too large, duplicate, or over 50 limit.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('oversized selection is rejected with feedback', (tester) async {
    await _pumpScreen(
      tester,
      picker: () async => [
        _platformFile(
          '/picked/large.pdf',
          name: 'large.pdf',
          size: 51 * 1024 * 1024,
        ),
      ],
    );

    await tester.tap(find.widgetWithText(FilledButton, 'ADD FILES'));
    await tester.pump();
    await tester.pump();

    expect(find.text('large.pdf'), findsNothing);
    expect(
      find.text(
        '1 file(s) skipped: too large, duplicate, or over 50 limit.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  List<FileItemEntity> files = const [],
  Future<List<PlatformFile>?> Function()? picker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RemoverScreen(
        initialFiles: files,
        outputFolderRepository: _UnexpectedOutputFolderRepository(),
        removerRepository: _UnexpectedRemoverRepository(),
        pickFiles: picker ?? (() async => null),
      ),
    ),
  );
  await tester.pump();
}

PlatformFile _platformFile(String path,
        {required String name, required int size}) =>
    PlatformFile(name: name, size: size, path: path);

FileItemEntity _file(String name, String extension) => FileItemEntity(
      path: '/fixtures/$name',
      name: name,
      extension: extension,
      sizeBytes: 100,
      addedAt: DateTime(2026),
    );

class _UnexpectedRemoverRepository implements RemoverRepository {
  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    Set<String>? selectiveLabels,
  }) {
    throw StateError('stripFile should not be called by this test');
  }
}

class _UnexpectedOutputFolderRepository implements OutputFolderRepository {
  @override
  Future<String> getValidOutputFolder() {
    throw StateError('getValidOutputFolder should not be called by this test');
  }
}
