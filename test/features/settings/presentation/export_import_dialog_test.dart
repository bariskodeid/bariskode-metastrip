import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/output_folder_picker.dart';
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
import 'package:metastrip/features/settings/presentation/screens/settings_screen.dart';
import 'package:metastrip/features/settings/presentation/widgets/export_import_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsCubit> _cubit(String? folder) async {
  SharedPreferences.setMockInitialValues({
    if (folder != null) AppConstants.keyOutputFolderPath: folder,
  });
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
  return cubit;
}

Future<void> _pumpSettings(
  WidgetTester tester,
  SettingsCubit cubit,
  DirectoryPicker? picker,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: picker == null
            ? const SettingsScreen()
            : SettingsScreen(directoryPicker: picker),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _dialog({
  String? outputFolder,
  DateTime Function()? clock,
  Future<bool> Function(String)? onExport,
  OpenFileFn? openFileFn,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ExportImportDialog(
        outputFolder: outputFolder,
        clock: clock ?? DateTime.now,
        onExport: onExport ?? (_) async => true,
        onImport: (_) async => true,
        openFileFn: openFileFn ?? openFile,
      ),
    ),
  );
}

void main() {
  testWidgets(
      'Settings choose folder uses the injected picker and saves its '
      'result', (tester) async {
    final cubit = await _cubit(null);
    addTearDown(cubit.close);
    await cubit.load();
    await _pumpSettings(tester, cubit, ({onError}) async => '/picked/folder');

    await tester.tap(find.text('CHOOSE FOLDER'));
    await tester.pumpAndSettle();

    expect(cubit.state.settings!.storage.outputFolderPath, '/picked/folder');
  });

  testWidgets(
      'picker exception shows an error snackbar and keeps the old '
      'folder', (tester) async {
    final cubit = await _cubit('/old/folder');
    addTearDown(cubit.close);
    await cubit.load();
    await _pumpSettings(tester, cubit, ({onError}) async => throw StateError('boom'));

    await tester.tap(find.text('CHOOSE FOLDER'));
    await tester.pumpAndSettle();

    expect(find.text('Folder selection failed'), findsOneWidget);
    expect(cubit.state.settings!.storage.outputFolderPath, '/old/folder');
  });

  testWidgets(
      'default picker failure on an unsupported platform surfaces the '
      'error snackbar and keeps the old folder', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final cubit = await _cubit('/old/folder');
      addTearDown(cubit.close);
      await cubit.load();
      await _pumpSettings(tester, cubit, null);

      await tester.tap(find.text('CHOOSE FOLDER'));
      await tester.pumpAndSettle();

      expect(find.text('Folder selection failed'), findsOneWidget);
      expect(cubit.state.settings!.storage.outputFolderPath, '/old/folder');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'picker reporting through onError shows the error snackbar',
      (tester) async {
    final cubit = await _cubit('/old/folder');
    addTearDown(cubit.close);
    await cubit.load();
    await _pumpSettings(tester, cubit, ({onError}) async {
      onError?.call(StateError('saf'));
      return null;
    });

    await tester.tap(find.text('CHOOSE FOLDER'));
    await tester.pumpAndSettle();

    expect(find.text('Folder selection failed'), findsOneWidget);
    expect(cubit.state.settings!.storage.outputFolderPath, '/old/folder');
  });

  testWidgets('export writes json into the output folder', (tester) async {
    final dir = Directory.systemTemp.createTempSync('export_dialog_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.pumpWidget(
      _dialog(
        outputFolder: dir.path,
        clock: () => DateTime(2026, 10, 12, 13, 5, 9),
        onExport: (path) async {
          File(path).writeAsStringSync('{"processing":{"jpegQuality":88}}');
          return true;
        },
      ),
    );

    await tester.tap(find.text('Export Settings'));
    await tester.pump();

    final file = File('${dir.path}/metastrip-settings-20261012-130509.json');
    expect(file.existsSync(), isTrue);
    expect(
      (jsonDecode(file.readAsStringSync()) as Map)['processing'],
      {'jpegQuality': 88},
    );
    expect(find.text('Saved metastrip-settings-20261012-130509.json'),
        findsOneWidget);
  });

  testWidgets('export without an output folder shows Export failed',
      (tester) async {
    await tester.pumpWidget(_dialog());

    await tester.tap(find.text('Export Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Export failed'), findsOneWidget);
  });

  testWidgets('import type group declares public.json UTI', (tester) async {
    List<XTypeGroup>? groups;
    await tester.pumpWidget(
      _dialog(
        openFileFn: ({acceptedTypeGroups = const <XTypeGroup>[]}) async {
          groups = acceptedTypeGroups;
          return null;
        },
      ),
    );

    await tester.tap(find.text('Import Settings'));
    await tester.pumpAndSettle();

    expect(groups, hasLength(1));
    expect(groups!.single.extensions, ['json']);
    expect(groups!.single.uniformTypeIdentifiers, ['public.json']);
    expect(groups!.single.mimeTypes, ['application/json']);
  });

  testWidgets('import failure shows Import failed', (tester) async {
    await tester.pumpWidget(
      _dialog(
        openFileFn: ({acceptedTypeGroups = const <XTypeGroup>[]}) async =>
            throw StateError('x'),
      ),
    );

    await tester.tap(find.text('Import Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Import failed'), findsOneWidget);
  });
}
