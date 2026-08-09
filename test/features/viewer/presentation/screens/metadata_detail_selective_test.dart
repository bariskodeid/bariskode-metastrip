import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:metastrip/features/viewer/presentation/screens/metadata_detail_screen.dart';

void main() {
  testWidgets('selective action forwards checked IDs and ignores XMP',
      (tester) async {
    Set<MetadataFieldId>? handedOff;
    await tester.pumpWidget(
      MaterialApp(
        home: MetadataDetailScreen(
          file: _file('document.pdf', 'pdf'),
          metadataLoader: (_, {required computeHash}) async =>
              const MetadataEntity(
            fields: [
              MetadataFieldEntity(
                section: 'PDF Document',
                label: 'Author',
                value: 'Ada',
                id: MetadataFieldId.pdfInfoAuthor,
              ),
              MetadataFieldEntity(
                section: 'PDF Document',
                label: 'XMP Packet',
                value: 'packet',
              ),
            ],
          ),
          onSelectiveCleanup: (ids) async => handedOff = ids,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));

    expect(handedOff, {MetadataFieldId.pdfInfoAuthor});
    expect(() => handedOff!.add(MetadataFieldId.pdfInfoTitle),
        throwsUnsupportedError);
  });

  testWidgets('non-selective formats show no checkboxes or action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MetadataDetailScreen(
          file: _file('photo.jpg', 'jpg'),
          metadataLoader: (_, {required computeHash}) async => MetadataEntity(
            fields: [
              MetadataFieldEntity(
                section: 'EXIF',
                label: 'Author',
                value: 'Ada',
                id: MetadataFieldId.pngText('Author'),
              ),
            ],
          ),
          onSelectiveCleanup: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('RAW METADATA renders but is not selectively selectable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MetadataDetailScreen(
          file: _file('document.pdf', 'pdf'),
          metadataLoader: (_, {required computeHash}) async =>
              const MetadataEntity(
            fields: [
              MetadataFieldEntity(
                section: 'PDF Document',
                label: 'Author',
                value: 'Ada',
                id: MetadataFieldId.pdfInfoAuthor,
              ),
              MetadataFieldEntity(
                section: '  raw metadata  ',
                label: 'Raw packet',
                value: '<raw>',
                id: MetadataFieldId.pdfInfoTitle,
              ),
            ],
          ),
          onSelectiveCleanup: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('  RAW METADATA  '), findsOneWidget);
    expect(find.text('Raw packet'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    final rawFieldTile = find.ancestor(
      of: find.text('Raw packet'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: rawFieldTile, matching: find.byType(Checkbox)),
      findsNothing,
    );
  });

  testWidgets('selective handoff ignores a rapid second tap', (tester) async {
    var handoffs = 0;
    final routeCompletion = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: MetadataDetailScreen(
          file: _file('document.pdf', 'pdf'),
          metadataLoader: (_, {required computeHash}) async =>
              const MetadataEntity(
            fields: [
              MetadataFieldEntity(
                section: 'PDF Document',
                label: 'Author',
                value: 'Ada',
                id: MetadataFieldId.pdfInfoAuthor,
              ),
            ],
          ),
          onSelectiveCleanup: (_) {
            handoffs++;
            return routeCompletion.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    expect(handoffs, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    routeCompletion.complete();
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

FileItemEntity _file(String name, String extension) => FileItemEntity(
      path: '/input/$name',
      name: name,
      extension: extension,
      sizeBytes: 100,
      addedAt: DateTime(2026),
    );
