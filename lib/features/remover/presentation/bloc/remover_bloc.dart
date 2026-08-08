import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/format/format_registry.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:path/path.dart' as p;

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
    bool validateInputs = true,
    RemoverState? initialState,
  })  : _repository = repository,
        _outputFolderRepository = outputFolderRepository,
        _validateInputs = validateInputs,
        super(initialState ?? RemoverState.initial()) {
    on<RemoverFilesAdded>(_onFilesAdded);
    on<RemoverFileRemoved>(_onFileRemoved);
    on<RemoverClearRequested>(_onClearRequested);
    on<RemoverProcessingStarted>(_onProcessingStarted);
    on<RemoverResetRequested>(_onResetRequested);
  }

  final RemoverRepository _repository;
  final OutputFolderRepository _outputFolderRepository;
  final bool _validateInputs;
  bool _cancelRequested = false;

  /// Interrupts processing after the current file completes.
  /// Called directly from the UI to bypass the event queue.
  void requestCancel() => _cancelRequested = true;

  void _onFilesAdded(RemoverFilesAdded event, Emitter<RemoverState> emit) {
    final seen = state.files.map((f) => f.path).toSet();
    final newFiles = <FileItemEntity>[];
    final policiesByPath = Map<String, StripPolicy>.of(state.policiesByPath);
    var skipped = 0;
    for (final file in event.files) {
      final capability = FormatRegistry.standard.lookup(file.extension);
      final removalLimit = capability?.removalSizeLimitBytes;
      if (capability?.supportsFullRemoval == true &&
          removalLimit != null &&
          file.sizeBytes > removalLimit) {
        skipped++;
        continue;
      }
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
      policiesByPath[file.path] = event.policiesByPath[file.path] ??
          const StripPolicy.supportedCleanup();
    }

    emit(
      state.copyWith(
        files: [...state.files, ...newFiles],
        policiesByPath: policiesByPath,
        errorMessage: skipped > 0
            ? '$skipped file(s) skipped: too large, duplicate, or over '
                '${AppConstants.maxFilesPerSession} limit.'
            : null,
        clearError: skipped == 0,
      ),
    );
  }

  void _onFileRemoved(RemoverFileRemoved event, Emitter<RemoverState> emit) {
    final policiesByPath = Map<String, StripPolicy>.of(state.policiesByPath)
      ..remove(event.path);
    emit(
      state.copyWith(
        files: state.files.where((f) => f.path != event.path).toList(),
        policiesByPath: policiesByPath,
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
        .where(
            (file) => FormatRegistry.standard.supportsRemoval(file.extension))
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
      final validationError =
          _validateInputs ? await _validateInput(file) : null;
      final policy = state.policiesByPath[file.path];
      final policyError = policy == null
          ? 'Cleanup policy is missing for this file'
          : _validatePolicy(file, policy);
      if (validationError != null || policyError != null) {
        results.add(
          ProcessingResultEntity.failure(
            inputPath: file.path,
            error: validationError ?? policyError!,
          ),
        );
        emit(state.copyWith(results: [...results]));
        continue;
      }
      final result = await _repository.stripFile(
        file.path,
        outputDirectory: outputDirectory,
        policy: policy!,
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

  Future<String?> _validateInput(FileItemEntity file) async {
    final pathExtension = FormatRegistry.normalizeExtension(
      p.extension(file.path),
    );
    final itemExtension = FormatRegistry.normalizeExtension(file.extension);
    if (pathExtension != itemExtension ||
        !FormatRegistry.standard.supportsRemoval(pathExtension)) {
      return 'Input file extension changed or is unsupported';
    }
    try {
      final stat = await File(file.path).stat();
      if (stat.type != FileSystemEntityType.file) {
        return 'Input file is missing or not a regular file';
      }
      final limit =
          FormatRegistry.standard.lookup(pathExtension)?.removalSizeLimitBytes;
      if (limit == null || stat.size > limit) {
        return 'Input file is too large for cleanup';
      }
    } on Object {
      return 'Input file is missing or unreadable';
    }
    return null;
  }

  String? _validatePolicy(FileItemEntity file, StripPolicy policy) {
    if (policy.mode != StripPolicyMode.selective) return null;
    final extension = FormatRegistry.normalizeExtension(file.extension);
    if (FormatRegistry.standard.lookup(extension)?.supportsSelectiveRemoval !=
        true) {
      return 'Selective cleanup is unavailable for this file type';
    }
    final matchesFormat = switch (extension) {
      'png' => policy.selectedFieldIds.every((id) => id.isPngText),
      'pdf' => policy.selectedFieldIds.every((id) => id.isPdfInfo),
      _ => false,
    };
    return matchesFormat
        ? null
        : 'Selected metadata fields do not match this file type';
  }

  void _onResetRequested(
    RemoverResetRequested event,
    Emitter<RemoverState> emit,
  ) {
    _cancelRequested = false;
    emit(RemoverState.initial());
  }
}
