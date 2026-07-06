import 'package:equatable/equatable.dart';

/// Outcome of stripping metadata from a single file.
class ProcessingResultEntity extends Equatable {
  const ProcessingResultEntity({
    required this.inputPath,
    required this.success,
    this.outputPath,
    this.error,
    this.bytesWritten = 0,
  });

  final String inputPath;
  final bool success;
  final String? outputPath;
  final String? error;
  final int bytesWritten;

  factory ProcessingResultEntity.success({
    required String inputPath,
    required String outputPath,
    int bytesWritten = 0,
  }) =>
      ProcessingResultEntity(
        inputPath: inputPath,
        success: true,
        outputPath: outputPath,
        bytesWritten: bytesWritten,
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
      [inputPath, success, outputPath, error, bytesWritten];
}
