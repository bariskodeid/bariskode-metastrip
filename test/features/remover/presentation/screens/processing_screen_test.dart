import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/remover/presentation/screens/processing_screen.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

class _UnusedRemoverRepository implements RemoverRepository {
  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    required StripPolicy policy,
  }) {
    throw StateError('stripFile must not be called');
  }
}

class _FakeOutputFolderRepository implements OutputFolderRepository {
  @override
  Future<String> getValidOutputFolder() async => '/out';
}

/// Starts mid-batch so the screen's own start event is ignored, and records
/// every cancel request before forwarding it.
class _SpyRemoverBloc extends RemoverBloc {
  _SpyRemoverBloc()
      : super(
          validateInputs: false,
          repository: _UnusedRemoverRepository(),
          outputFolderRepository: _FakeOutputFolderRepository(),
          initialState: RemoverState(
            files: [
              FileItemEntity(
                path: '/tmp/a.jpg',
                name: 'a.jpg',
                extension: 'jpg',
                sizeBytes: 100,
                addedAt: DateTime(2026, 1, 1),
              ),
            ],
            status: RemoverStatus.processing,
          ),
        );

  int cancelRequests = 0;

  @override
  void requestCancel() {
    cancelRequests++;
    super.requestCancel();
  }
}

void main() {
  testWidgets(
      'system back on ProcessingScreen requests cancel instead of '
      'popping', (tester) async {
    final bloc = _SpyRemoverBloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<RemoverBloc>.value(
                  value: bloc,
                  child: const ProcessingScreen(),
                ),
              ),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(ProcessingScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ProcessingScreen), findsOneWidget);
    expect(bloc.cancelRequests, 1);
    expect(bloc.state.status, RemoverStatus.processing);
  });
}
