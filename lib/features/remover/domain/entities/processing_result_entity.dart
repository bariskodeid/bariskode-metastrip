import 'package:equatable/equatable.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';

/// Outcome of stripping metadata from a single file.
class ProcessingResultEntity extends Equatable {
  const ProcessingResultEntity({
    required this.inputPath,
    required this.success,
    this.outputPath,
    this.error,
    this.bytesWritten = 0,
    this.report,
  });

  final String inputPath;
  final bool success;
  final String? outputPath;
  final String? error;
  final int bytesWritten;
  final StripReport? report;

  factory ProcessingResultEntity.success({
    required String inputPath,
    required String outputPath,
    int bytesWritten = 0,
    StripReport? report,
  }) =>
      ProcessingResultEntity(
        inputPath: inputPath,
        success: true,
        outputPath: outputPath,
        bytesWritten: bytesWritten,
        report: report,
      );

  factory ProcessingResultEntity.failure({
    required String inputPath,
    required String error,
  }) =>
      ProcessingResultEntity(
        inputPath: inputPath,
        success: false,
        error: error,
      );

  @override
  List<Object?> get props =>
      [inputPath, success, outputPath, error, bytesWritten, report];
}
