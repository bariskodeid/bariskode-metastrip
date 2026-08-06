import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/constants/supported_extensions.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

/// Manages the remover queue and sequential file processing.
///
/// Heavy byte-level stripping still runs on a worker isolate via the
/// datasource; this BLoC only orchestrates sequencing, progress, and cancel.
///
/// Cancel is a direct method call (not an event) so it can interrupt the
/// processing loop without waiting on the Bloc's sequential event queue.
class RemoverBloc extends Bloc<RemoverEvent, RemoverState> {
  RemoverBloc({
    required RemoverRepository repository,
    required OutputFolderRepository outputFolderRepository,
  })  : _repository = repository,
        _outputFolderRepository = outputFolderRepository,
        super(RemoverState.initial()) {
    on<RemoverFilesAdded>(_onFilesAdded);
    on<RemoverFileRemoved>(_onFileRemoved);
    on<RemoverClearRequested>(_onClearRequested);
    on<RemoverProcessingStarted>(_onProcessingStarted);
    on<RemoverResetRequested>(_onResetRequested);
  }

  final RemoverRepository _repository;
  final OutputFolderRepository _outputFolderRepository;
  bool _cancelRequested = false;

  /// Interrupts processing after the current file completes.
  /// Called directly from the UI to bypass the event queue.
  void requestCancel() => _cancelRequested = true;

  void _onFilesAdded(RemoverFilesAdded event, Emitter<RemoverState> emit) {
    final seen = state.files.map((f) => f.path).toSet();
    final newFiles = <FileItemEntity>[];
    var skipped = 0;
    for (final file in event.files) {
      if (!seen.add(file.path)) {
        skipped++;
        continue;
      }
      if (state.files.length + newFiles.length >=
          AppConstants.maxFilesPerSession) {
        skipped++;
        continue;
      }
      newFiles.add(file);
    }

    emit(
      state.copyWith(
        files: [...state.files, ...newFiles],
        errorMessage: skipped > 0
            ? '$skipped file(s) skipped: duplicate or over '
                '${AppConstants.maxFilesPerSession} limit.'
            : null,
        clearError: skipped == 0,
      ),
    );
  }

  void _onFileRemoved(RemoverFileRemoved event, Emitter<RemoverState> emit) {
    emit(
      state.copyWith(
        files: state.files.where((f) => f.path != event.path).toList(),
        clearError: true,
      ),
    );
  }

  void _onClearRequested(
    RemoverClearRequested event,
    Emitter<RemoverState> emit,
  ) {
    _cancelRequested = false;
    emit(RemoverState.initial());
  }

  Future<void> _onProcessingStarted(
    RemoverProcessingStarted event,
    Emitter<RemoverState> emit,
  ) async {
    if (state.files.isEmpty) return;
    final supportedFiles = state.files
        .where((file) => RemoverStrippableExtensions.contains(file.extension))
        .toList();
    if (supportedFiles.isEmpty) {
      emit(
        state.copyWith(
          status: RemoverStatus.failure,
          errorMessage: 'No supported files in the queue to process.',
          clearProgress: true,
        ),
      );
      return;
    }
    _cancelRequested = false;

    late final String outputDirectory;
    try {
      outputDirectory = await _outputFolderRepository.getValidOutputFolder();
    } catch (_) {
      emit(
        state.copyWith(
          status: RemoverStatus.failure,
          errorMessage: 'Choose a valid output folder before processing.',
          clearProgress: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: RemoverStatus.processing,
        results: const [],
        progress: ProcessingProgress(
          currentIndex: -1,
          totalFiles: supportedFiles.length,
          currentFile: supportedFiles.first.name,
        ),
        clearError: true,
      ),
    );

    final results = <ProcessingResultEntity>[];
    for (var i = 0; i < supportedFiles.length; i++) {
      if (_cancelRequested) break;
      final file = supportedFiles[i];
      emit(
        state.copyWith(
          progress: ProcessingProgress(
            currentIndex: i,
            totalFiles: supportedFiles.length,
            currentFile: file.name,
          ),
        ),
      );
      final result = await _repository.stripFile(
        file.path,
        outputDirectory: outputDirectory,
      );
      results.add(result);
      emit(state.copyWith(results: [...results]));
    }

    emit(
      state.copyWith(
        status: _cancelRequested
            ? RemoverStatus.cancelled
            : RemoverStatus.completed,
        clearProgress: true,
      ),
    );
  }

  void _onResetRequested(
    RemoverResetRequested event,
    Emitter<RemoverState> emit,
  ) {
    _cancelRequested = false;
    emit(RemoverState.initial());
  }
}
