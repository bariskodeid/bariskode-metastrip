import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/presentation/screens/metadata_detail_screen.dart';

void main() {
  testWidgets('MetadataDetailScreen renders basic metadata', (tester) async {
    final dir = await Directory.systemTemp.createTemp('metastrip_detail_test_');

    final file = File('${dir.path}${Platform.pathSeparator}sample.txt');
    await file.writeAsString('hello');

    await tester.pumpWidget(
      MaterialApp(
        home: MetadataDetailScreen(
          file: FileItemEntity(
            path: file.path,
            name: 'sample.txt',
            extension: 'txt',
            sizeBytes: 5,
            addedAt: DateTime.now(),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('METADATA DETAIL'), findsOneWidget);
    expect(find.text('sample.txt'), findsWidgets);
    expect(find.text('FILE'), findsOneWidget);
    expect(find.text('Integrity'.toUpperCase()), findsOneWidget);
    expect(find.text('SHA-256'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: true);
}
