import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
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

/// Mid-batch state, so the screen's own start event is ignored.
final _processingState = RemoverState(
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
);

/// Starts in [initialState] (mid-batch by default) and records every cancel
/// request before forwarding it.
class _SpyRemoverBloc extends RemoverBloc {
  _SpyRemoverBloc({RemoverState? initialState})
      : super(
          validateInputs: false,
          repository: _UnusedRemoverRepository(),
          outputFolderRepository: _FakeOutputFolderRepository(),
          initialState: initialState ?? _processingState,
        );

  int cancelRequests = 0;

  @override
  void requestCancel() {
    cancelRequests++;
    super.requestCancel();
  }
}

/// Pushes [ProcessingScreen] over a home route, backed by [bloc].
Future<void> _openScreen(WidgetTester tester, RemoverBloc bloc) async {
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
}

void main() {
  testWidgets(
      'system back on ProcessingScreen requests cancel instead of '
      'popping', (tester) async {
    final bloc = _SpyRemoverBloc();
    addTearDown(bloc.close);
    await _openScreen(tester, bloc);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ProcessingScreen), findsOneWidget);
    expect(bloc.cancelRequests, 1);
    expect(bloc.state.status, RemoverStatus.processing);
  });

  testWidgets('system back pops ProcessingScreen once not processing',
      (tester) async {
    final bloc = _SpyRemoverBloc();
    addTearDown(bloc.close);
    await _openScreen(tester, bloc);

    // Clear leaves the bloc idle, which the listener does not navigate on;
    // the screen must still let the user leave.
    bloc.add(const RemoverClearRequested());
    await tester.pumpAndSettle();
    expect(bloc.state, RemoverState.initial());
    expect(find.byType(ProcessingScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ProcessingScreen), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
    expect(bloc.cancelRequests, 0);
  });
}
