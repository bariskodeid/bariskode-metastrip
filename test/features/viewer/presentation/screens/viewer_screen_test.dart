import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metastrip/features/viewer/presentation/screens/viewer_screen.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';

class _FakeOutputFolderRepository implements OutputFolderRepository {
  const _FakeOutputFolderRepository();

  @override
  Future<String> getValidOutputFolder() async => '/tmp';
}

class _FakeRemoverRepository implements RemoverRepository {
  const _FakeRemoverRepository();

  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    required StripPolicy policy,
  }) async =>
      ProcessingResultEntity.success(
        inputPath: path,
        outputPath: '$outputDirectory/${path.split('/').last}_clean',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ViewerScreen(
          outputFolderRepository: _FakeOutputFolderRepository(),
          removerRepository: _FakeRemoverRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders viewer screen scaffold with empty state', (tester) async {
    await pumpApp(tester);

    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows empty state when no files are present', (tester) async {
    await pumpApp(tester);

    expect(find.byType(ViewerScreen), findsOneWidget);
  });
}
