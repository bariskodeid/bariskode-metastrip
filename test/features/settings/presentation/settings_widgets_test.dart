import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/shared_preferences_storage.dart';
import 'package:metastrip/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:metastrip/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:metastrip/features/settings/domain/usecases/clear_cache.dart';
import 'package:metastrip/features/settings/domain/usecases/export_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/get_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/import_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/reset_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/save_settings.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:metastrip/features/settings/presentation/screens/theme_picker_screen.dart';
import 'package:metastrip/features/settings/presentation/widgets/concurrent_files_slider.dart';
import 'package:metastrip/features/settings/presentation/widgets/jpeg_quality_slider.dart';
import 'package:metastrip/features/settings/presentation/widgets/naming_template_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('theme picker does not overflow on a narrow screen',
      (tester) async {
    // Reproduce the narrow device size that previously overflowed.
    tester.view
      ..physicalSize = const Size(320, 480)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);
    final repository =
        SettingsRepositoryImpl(SettingsLocalDataSourceImpl(storage));
    final cubit = SettingsCubit(
      getSettings: GetSettings(repository),
      saveSettings: SaveSettings(repository),
      resetSettings: ResetSettings(repository),
      exportSettings: ExportSettings(repository),
      importSettings: ImportSettings(repository, storage: storage),
      clearCache: ClearCache(storage),
      storage: storage,
      validator: (path) async => path,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BlocProvider.value(
            value: cubit,
            child: const ThemePickerScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);
    expect(find.text('SECONDARY'), findsOneWidget);
    expect(find.text('Custom Theme'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
