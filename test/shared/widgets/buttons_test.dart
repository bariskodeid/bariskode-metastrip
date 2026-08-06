import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';
import 'package:metastrip/shared/widgets/secondary_button.dart';

void main() {
  testWidgets('PrimaryButton exposes label and disabled loading semantics',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrimaryButton(
          label: 'Save file',
          onPressed: _noop,
          isLoading: true,
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PrimaryButton));
    expect(semantics.label, 'SAVE FILE');
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SecondaryButton invokes callback and exposes button semantics',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SecondaryButton(
          label: 'Try again',
          onPressed: () => presses++,
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(SecondaryButton));
    expect(semantics.label, 'TRY AGAIN');
    expect(semantics.flagsCollection.isButton, isTrue);
    await tester.tap(find.byType(SecondaryButton));
    expect(presses, 1);
  });
}

void _noop() {}
