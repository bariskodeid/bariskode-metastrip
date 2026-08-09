import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

FileItemEntity _file(
  String name, {
  String ext = 'jpg',
  int sizeBytes = 100,
}) {
  return FileItemEntity(
    path: '/tmp/$name',
    name: name,
    extension: ext,
    sizeBytes: sizeBytes,
    addedAt: DateTime(2026, 1, 1),
  );
}

class _FakeRemoverRepository implements RemoverRepository {
  _FakeRemoverRepository({this.shouldFail = false});

  final bool shouldFail;
  final List<String> processedPaths = [];
  String? lastOutputDirectory;
  StripPolicy? lastPolicy;

  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    required StripPolicy policy,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    processedPaths.add(path);
    lastOutputDirectory = outputDirectory;
    lastPolicy = policy;
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

class _FakeOutputFolderRepository implements OutputFolderRepository {
  _FakeOutputFolderRepository({this.path = '/out'});

  String? path;

  @override
  Future<String> getValidOutputFolder() async {
    if (path == null) throw StateError('invalid output folder');
    return path!;
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
    test('RemoverFilesAdded snapshots and protects input collections', () {
      final file = _file('image.png', ext: 'png');
      final files = <FileItemEntity>[file];
      final policy = StripPolicy.selective(
        fieldIds: {MetadataFieldId.pngText('Author')},
      );
      final policies = <String, StripPolicy>{file.path: policy};

      final event = RemoverFilesAdded(files, policiesByPath: policies);
      files.clear();
      policies.clear();

      expect(event.files, [file]);
      expect(event.policiesByPath, {file.path: policy});
      expect(() => event.files.clear(), throwsUnsupportedError);
      expect(() => event.policiesByPath.clear(), throwsUnsupportedError);
    });

    test('RemoverState constructor and copyWith snapshot collections', () {
      final file = _file('image.png', ext: 'png');
      const policy = StripPolicy.supportedCleanup();
      final result = ProcessingResultEntity.success(
        inputPath: file.path,
        outputPath: '${file.path}.clean',
      );
      final files = <FileItemEntity>[file];
      final policies = <String, StripPolicy>{file.path: policy};
      final results = <ProcessingResultEntity>[result];

      final state = RemoverState(
        files: files,
        status: RemoverStatus.completed,
        policiesByPath: policies,
        results: results,
      );
      files.clear();
      policies.clear();
      results.clear();

      expect(state.files, [file]);
      expect(state.policiesByPath, {file.path: policy});
      expect(state.results, [result]);
      expect(() => state.files.clear(), throwsUnsupportedError);
      expect(() => state.policiesByPath.clear(), throwsUnsupportedError);
      expect(() => state.results.clear(), throwsUnsupportedError);

      final nextFiles = <FileItemEntity>[file];
      final nextPolicies = <String, StripPolicy>{file.path: policy};
      final nextResults = <ProcessingResultEntity>[result];
      final copied = state.copyWith(
        files: nextFiles,
        policiesByPath: nextPolicies,
        results: nextResults,
      );
      nextFiles.clear();
      nextPolicies.clear();
      nextResults.clear();
      expect(copied.files, [file]);
      expect(copied.policiesByPath, {file.path: policy});
      expect(copied.results, [result]);
    });

    test('adds files and dedups by path', () async {
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: _FakeRemoverRepository(),
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(
        RemoverFilesAdded([_file('a.jpg'), _file('a.jpg'), _file('b.png')]),
      );
      final state = await _waitFor(bloc, (s) => s.files.length == 2);

      expect(state.files, hasLength(2));
      bloc.close();
    });

    test('materializes default policies for every accepted file', () async {
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: _FakeRemoverRepository(),
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      final files = [_file('a.jpg'), _file('b.png')];

      bloc.add(RemoverFilesAdded(files));
      final state = await _waitFor(bloc, (s) => s.files.length == 2);

      expect(state.policiesByPath.keys, {'/tmp/a.jpg', '/tmp/b.png'});
      expect(
        state.policiesByPath.values.map((policy) => policy.mode),
        everyElement(StripPolicyMode.supportedCleanup),
      );
      await bloc.close();
    });

    test('duplicate insertion preserves the already queued policy', () async {
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: _FakeRemoverRepository(),
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      final file = _file('image.png', ext: 'png');
      final firstPolicy = StripPolicy.selective(
        fieldIds: {MetadataFieldId.pngText('Author')},
      );
      final duplicatePolicy = StripPolicy.selective(
        fieldIds: {MetadataFieldId.pngText('Title')},
      );
      bloc.add(
        RemoverFilesAdded(
          [file],
          policiesByPath: {file.path: firstPolicy},
        ),
      );
      await _waitFor(bloc, (s) => s.files.length == 1);

      bloc.add(
        RemoverFilesAdded(
          [file],
          policiesByPath: {file.path: duplicatePolicy},
        ),
      );
      final state = await _waitFor(bloc, (s) => s.errorMessage != null);

      expect(state.policiesByPath[file.path], same(firstPolicy));
      await bloc.close();
    });

    test('enforces session file cap', () async {
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: _FakeRemoverRepository(),
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
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

    test('rejects oversized supported files', () async {
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: _FakeRemoverRepository(),
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(
        RemoverFilesAdded([
          _file(
            'large.jpg',
            sizeBytes: AppConstants.maxRemoverFileSizeBytes + 1,
          ),
          _file('small.jpg'),
        ]),
      );
      final state = await _waitFor(bloc, (s) => s.errorMessage != null);

      expect(state.files.map((file) => file.name), ['small.jpg']);
      expect(state.errorMessage, contains('too large'));
      bloc.close();
    });

    test('removes a single file from the queue', () async {
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: _FakeRemoverRepository(),
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(RemoverFilesAdded([_file('a.jpg'), _file('b.png')]));
      await _waitFor(bloc, (s) => s.files.length == 2);

      bloc.add(const RemoverFileRemoved('/tmp/a.jpg'));
      final state = await _waitFor(bloc, (s) => s.files.length == 1);

      expect(state.files.single.name, 'b.png');
      expect(state.policiesByPath, isNot(contains('/tmp/a.jpg')));
      expect(state.policiesByPath, contains('/tmp/b.png'));
      bloc.close();
    });

    test('clear resets to idle', () async {
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: _FakeRemoverRepository(),
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(RemoverFilesAdded([_file('a.jpg')]));
      await _waitFor(bloc, (s) => s.files.isNotEmpty);

      bloc.add(const RemoverClearRequested());
      final state = await _waitFor(bloc, (s) => s.files.isEmpty);

      expect(state.files, isEmpty);
      expect(state.status, RemoverStatus.idle);
      expect(state.policiesByPath, isEmpty);
      bloc.close();
    });

    test('missing policy is a per-file failure and is never defaulted',
        () async {
      final repository = _FakeRemoverRepository();
      final file = _file('a.jpg');
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repository,
        outputFolderRepository: _FakeOutputFolderRepository(),
        initialState: RemoverState(
          files: [file],
          status: RemoverStatus.idle,
        ),
      );

      bloc.add(const RemoverProcessingStarted());
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.completed);

      expect(state.results.single.success, isFalse);
      expect(state.results.single.error,
          'Cleanup policy is missing for this file');
      expect(repository.processedPaths, isEmpty);
      await bloc.close();
    });

    test('processes files sequentially and reaches completed', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(RemoverFilesAdded([_file('a.jpg'), _file('b.png')]));
      await _waitFor(bloc, (s) => s.files.length == 2);

      bloc.add(const RemoverProcessingStarted());
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

    test('accepts exact selective Office IDs and rejects presentation-only IDs',
        () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
        initialState: RemoverState(
          status: RemoverStatus.idle,
          files: [_file('document.docx', ext: 'docx')],
          policiesByPath: {
            '/tmp/document.docx': StripPolicy.selective(
              fieldIds: const {MetadataFieldId.openXmlTitle},
            ),
          },
        ),
      );
      bloc.add(const RemoverProcessingStarted());
      final accepted = await _waitFor(
        bloc,
        (state) => state.status == RemoverStatus.completed,
      );
      expect(accepted.results.single.success, isTrue);

      final rejected = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
        initialState: RemoverState(
          status: RemoverStatus.idle,
          files: [_file('document.docx', ext: 'docx')],
          policiesByPath: {
            '/tmp/document.docx': StripPolicy.selective(
              fieldIds: const {MetadataFieldId.openXmlSlides},
            ),
          },
        ),
      );
      rejected.add(const RemoverProcessingStarted());
      final failed = await _waitFor(
        rejected,
        (state) => state.status == RemoverStatus.completed,
      );
      expect(failed.results.single.error,
          'Selected metadata fields do not match this file type');
      await bloc.close();
      await rejected.close();
    });

    test('accepts exact ODF IDs and rejects cross-format IDs', () async {
      final repo = _FakeRemoverRepository();
      final accepted = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
        initialState: RemoverState(
          status: RemoverStatus.idle,
          files: [_file('document.odt', ext: 'odt')],
          policiesByPath: {
            '/tmp/document.odt': StripPolicy.selective(
              fieldIds: const {MetadataFieldId.odfTitle},
            ),
          },
        ),
      )..add(const RemoverProcessingStarted());
      final acceptedState = await _waitFor(
        accepted,
        (state) => state.status == RemoverStatus.completed,
      );
      expect(acceptedState.results.single.success, isTrue);

      final rejected = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
        initialState: RemoverState(
          status: RemoverStatus.idle,
          files: [_file('document.odt', ext: 'odt')],
          policiesByPath: {
            '/tmp/document.odt': StripPolicy.selective(
              fieldIds: const {MetadataFieldId.openXmlTitle},
            ),
          },
        ),
      )..add(const RemoverProcessingStarted());
      final rejectedState = await _waitFor(
        rejected,
        (state) => state.status == RemoverStatus.completed,
      );
      expect(rejectedState.results.single.success, isFalse);
      await accepted.close();
      await rejected.close();
    });

    test(
        'processes registered formats including supported BMP and reports '
        'supported progress total', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(RemoverFilesAdded([
        _file('canonical.bmp', ext: 'bmp'),
        _file('photo.jpg'),
        _file('unsupported.mp4', ext: 'mp4'),
        _file('document.pdf', ext: 'pdf'),
      ]));
      await _waitFor(bloc, (s) => s.files.length == 4);

      bloc.add(const RemoverProcessingStarted());
      final processing = await _waitFor(
        bloc,
        (s) => s.progress?.totalFiles == 3,
      );
      expect(processing.progress?.currentFile, 'canonical.bmp');

      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.completed);
      expect(repo.processedPaths,
          ['/tmp/canonical.bmp', '/tmp/photo.jpg', '/tmp/document.pdf']);
      expect(state.results, hasLength(3));
      expect(state.successCount, 3);
      bloc.close();
    });

    test('only unsupported files fail clearly without processing', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(path: null),
      );
      bloc.add(RemoverFilesAdded([
        _file('audio.aac', ext: 'aac'),
        _file('movie.mp4', ext: 'mp4'),
      ]));
      await _waitFor(bloc, (s) => s.files.length == 2);

      bloc.add(const RemoverProcessingStarted());
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.failure);

      expect(state.errorMessage, 'No supported files in the queue to process.');
      expect(state.progress, isNull);
      expect(state.results, isEmpty);
      expect(repo.processedPaths, isEmpty);
      bloc.close();
    });

    test('records failures without aborting the batch', () async {
      final repo = _FakeRemoverRepository(shouldFail: true);
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(RemoverFilesAdded([_file('a.jpg'), _file('b.png')]));
      await _waitFor(bloc, (s) => s.files.length == 2);

      bloc.add(const RemoverProcessingStarted());
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.completed);

      expect(state.successCount, 0);
      expect(state.failureCount, 2);
      bloc.close();
    });

    test('invalid output folder stops before processing', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(path: null),
      );
      bloc.add(RemoverFilesAdded([_file('a.jpg')]));
      await _waitFor(bloc, (state) => state.files.isNotEmpty);

      bloc.add(const RemoverProcessingStarted());
      final state =
          await _waitFor(bloc, (s) => s.status == RemoverStatus.failure);

      expect(repo.processedPaths, isEmpty);
      expect(state.errorMessage, contains('valid output folder'));
      await bloc.close();
    });

    test('requestCancel stops processing and marks cancelled', () async {
      final repo = _FakeRemoverRepository();
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
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
      final bloc = RemoverBloc(
        validateInputs: false,
        repository: repo,
        outputFolderRepository: _FakeOutputFolderRepository(),
      );
      bloc.add(RemoverFilesAdded([_file('a.jpg')]));
      await _waitFor(bloc, (s) => s.files.length == 1);

      bloc.add(const RemoverProcessingStarted());
      await _waitFor(bloc, (s) => s.status == RemoverStatus.completed);

      bloc.add(const RemoverResetRequested());
      final state = await _waitFor(bloc, (s) => s.status == RemoverStatus.idle);

      expect(state.status, RemoverStatus.idle);
      expect(state.files, isEmpty);
      expect(state.policiesByPath, isEmpty);
      bloc.close();
    });
  });
}
