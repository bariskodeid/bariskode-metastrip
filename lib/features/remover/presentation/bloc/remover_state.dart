import 'package:equatable/equatable.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

enum RemoverStatus { idle, processing, completed, cancelled, failure }

/// Snapshot of progress for the currently processing batch.
class ProcessingProgress extends Equatable {
  const ProcessingProgress({
    required this.currentIndex,
    required this.totalFiles,
    required this.currentFile,
  });

  final int currentIndex;
  final int totalFiles;
  final String currentFile;

  /// Clamp to [0, 1]; `currentIndex` is -1 before the first file starts.
  double get percentage {
    if (totalFiles == 0) return 0;
    final raw = (currentIndex + 1) / totalFiles;
    return raw.clamp(0, 1).toDouble();
  }

  @override
  List<Object?> get props => [currentIndex, totalFiles, currentFile];
}

class RemoverState extends Equatable {
  RemoverState({
    required List<FileItemEntity> files,
    required this.status,
    Map<String, StripPolicy> policiesByPath = const <String, StripPolicy>{},
    this.progress,
    List<ProcessingResultEntity> results = const [],
    this.errorMessage,
  })  : files = List.unmodifiable(files),
        policiesByPath = Map.unmodifiable(policiesByPath),
        results = List.unmodifiable(results);

  factory RemoverState.initial() =>
      RemoverState(files: const [], status: RemoverStatus.idle);

  final List<FileItemEntity> files;
  final RemoverStatus status;
  final Map<String, StripPolicy> policiesByPath;
  final ProcessingProgress? progress;
  final List<ProcessingResultEntity> results;
  final String? errorMessage;

  int get successCount => results.where((r) => r.success).length;
  int get failureCount => results.where((r) => !r.success).length;
  int get totalBytesWritten =>
      results.fold(0, (sum, r) => sum + r.bytesWritten);

  RemoverState copyWith({
    List<FileItemEntity>? files,
    RemoverStatus? status,
    Map<String, StripPolicy>? policiesByPath,
    ProcessingProgress? progress,
    bool clearProgress = false,
    List<ProcessingResultEntity>? results,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RemoverState(
      files: files ?? this.files,
      status: status ?? this.status,
      policiesByPath: policiesByPath ?? this.policiesByPath,
      progress: clearProgress ? null : progress ?? this.progress,
      results: results ?? this.results,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        files,
        status,
        policiesByPath,
        progress,
        results,
        errorMessage,
      ];
}
