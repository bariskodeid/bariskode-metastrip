import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

FileItemEntity _file(String name, {String ext = 'jpg'}) {
  return FileItemEntity(
    path: '/tmp/$name',
    name: name,
    extension: ext,
    sizeBytes: 100,
    addedAt: DateTime(2026, 1, 1),
  );
}

class _FakeRemoverRepository implements RemoverRepository {
  _FakeRemoverRepository({this.shouldFail = false});

  final bool shouldFail;
  final List<String> processedPaths = [];
  String? lastOutputDirectory;

  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    String? outputDirectory,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    processedPaths.add(path);
    lastOutputDirectory = outputDirectory;
    if (shouldFail) {
      return ProcessingResultEntity.failure(
        inputPath: path,
        error: 'boom',
      );
    }
    return ProcessingResultEntity.success(
      inputPath: path,
      outputPath: '$path.clean',
      bytesWritten: 42,
    );
  }
}

/// Waits for the BLoC to emit a state matching [predicate].
Future<RemoverState> _waitFor(
  RemoverBloc bloc,
  bool Function(RemoverState) predicate,
) {
  return bloc.stream.firstWhere(predicate);
}

void main() {
  group('RemoverBloc', () {
    test('adds files and dedups by path', () async {
      final bloc = RemoverBloc(repository: _FakeRemoverRepository());
      bloc.add(
        RemoverFilesAdded([_file('a.jpg'), _file('a.jpg'), _file('b.png')]),
      );
      final state = await _waitFor(bloc, (s) => s.files.length == 2);

      expect(state.files, hasLength(2));
      bloc.close();
    });

    test('enforces session file cap', () async {
      final bloc = RemoverBloc(repository: _FakeRemoverRepository());
      final files = List.generate(
        AppConstants.maxFilesPerSession + 3,
        (i) => _file('file$i.jpg'),
      );
      bloc.add(RemoverFilesAdded(files));
      final state = await _waitFor(
        bloc,
        (s) => s.errorMessage != null,
      );

      expect(state.files, hasLength(AppConstants.maxFilesPerSession));
      expect(state.errorMessage, contains('skipped'));
      bloc.close();
    });

    test('removes a single file from the queue', () async {
      final bloc = RemoverBloc(repository: _FakeRemoverRepository());
      bloc.add(RemoverFilesAdded([_file('a.jpg'), _file('b.png')]));
      await _waitFor(bloc, (s) => s.files.length == 2);

      bloc.add(const RemoverFileRemoved('/tmp/a.jpg'));
      final state = await _waitFor(bloc, (s) => s.files.length == 1);

      expect(state.files.single.name, 'b.png');
      bloc.close();
    });

    test('clear resets to idle', () async {
      final bloc = RemoverBloc(repository: _FakeRemoverRepository());
      bloc.add(RemoverFilesAdded([_file('a.jpg')]));
      await _waitFor(bloc, (s) => s.files.isNotEmpty);

      bloc.add(const RemoverClearRequested());
      final state = await _waitFor(bloc, (s) => s.files.isEmpty);

      expect(state.files, isEmpty);
      expect(state.status, RemoverStatus.idle);
      bloc.close();
    });

    test('processes files sequentially and reaches completed', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(repository: repo);
      bloc.add(RemoverFilesAdded([_file('a.jpg'), _file('b.png')]));
      await _waitFor(bloc, (s) => s.files.length == 2);

      bloc.add(const RemoverProcessingStarted(outputDirectory: '/out'));
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.completed);

      expect(repo.processedPaths, ['/tmp/a.jpg', '/tmp/b.png']);
      expect(repo.lastOutputDirectory, '/out');
      expect(state.successCount, 2);
      expect(state.failureCount, 0);
      expect(state.totalBytesWritten, 84);
      expect(state.progress, isNull);
      bloc.close();
    });

    test('records failures without aborting the batch', () async {
      final repo = _FakeRemoverRepository(shouldFail: true);
      final bloc = RemoverBloc(repository: repo);
      bloc.add(RemoverFilesAdded([_file('a.jpg'), _file('b.png')]));
      await _waitFor(bloc, (s) => s.files.length == 2);

      bloc.add(const RemoverProcessingStarted());
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.completed);

      expect(state.successCount, 0);
      expect(state.failureCount, 2);
      bloc.close();
    });

    test('requestCancel stops processing and marks cancelled', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(repository: repo);
      bloc.add(RemoverFilesAdded([
        _file('a.jpg'),
        _file('b.png'),
        _file('c.pdf', ext: 'pdf'),
      ]));
      await _waitFor(bloc, (s) => s.files.length == 3);

      bloc.add(const RemoverProcessingStarted());
      // Cancel after the first file is processed.
      await _waitFor(bloc, (s) => s.results.isNotEmpty);
      bloc.requestCancel();
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.cancelled);

      expect(repo.processedPaths.length, lessThan(3));
      expect(state.status, RemoverStatus.cancelled);
      bloc.close();
    });

    test('reset returns to idle after completion', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(repository: repo);
      bloc.add(RemoverFilesAdded([_file('a.jpg')]));
      await _waitFor(bloc, (s) => s.files.length == 1);

      bloc.add(const RemoverProcessingStarted());
      await _waitFor(bloc, (s) => s.status == RemoverStatus.completed);

      bloc.add(const RemoverResetRequested());
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.idle);

      expect(state.status, RemoverStatus.idle);
      expect(state.files, isEmpty);
      bloc.close();
    });
  });
}
