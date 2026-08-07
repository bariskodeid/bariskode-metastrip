import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/settings/presentation/screens/theme_picker_screen.dart';
import 'package:metastrip/features/settings/presentation/widgets/concurrent_files_slider.dart';
import 'package:metastrip/features/settings/presentation/widgets/jpeg_quality_slider.dart';
import 'package:metastrip/features/settings/presentation/widgets/naming_template_field.dart';

void main() {
  testWidgets('JPEG slider persists once when a drag ends', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JpegQualitySlider(value: 90, onChanged: values.add),
        ),
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();

    expect(values, hasLength(1));
  });

  testWidgets('concurrent slider persists once when a drag ends',
      (tester) async {
    final values = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConcurrentFilesSlider(value: 4, onChanged: values.add),
        ),
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();

    expect(values, hasLength(1));
  });

  testWidgets('naming field persists once on submit', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NamingTemplateField(
            initialValue: '{name}_clean',
            onChanged: values.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '{name}_private');
    expect(values, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(values, ['{name}_private']);
  });

  testWidgets('naming field persists once on focus loss', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              NamingTemplateField(
                initialValue: '{name}_clean',
                onChanged: values.add,
              ),
              const TextField(key: Key('other-field')),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '{name}_private');
    await tester.tap(find.byKey(const Key('other-field')));
    await tester.pump();

    expect(values, ['{name}_private']);
  });

  test('custom theme draft is complete and preserves existing colors', () {
    final colors = resolveCustomThemeColors(
      'custom',
      const {'accentPrimary': 0xFF123456},
    );

    expect(colors, hasLength(16));
    expect(colors['accentPrimary']?.toARGB32(), 0xFF123456);
  });
}
