import 'package:equatable/equatable.dart';

/// Entity representing onboarding state
class OnboardingStateEntity extends Equatable {
  final int currentSlideIndex;
  final String? outputFolderPath;
  final Map<String, bool> permissionsStatus;
  final bool isCompleted;

  const OnboardingStateEntity({
    required this.currentSlideIndex,
    this.outputFolderPath,
    required this.permissionsStatus,
    required this.isCompleted,
  });

  /// Initial state
  factory OnboardingStateEntity.initial() {
    return const OnboardingStateEntity(
      currentSlideIndex: 0,
      outputFolderPath: null,
      permissionsStatus: {},
      isCompleted: false,
    );
  }

  /// Copy with method
  OnboardingStateEntity copyWith({
    int? currentSlideIndex,
    String? outputFolderPath,
    Map<String, bool>? permissionsStatus,
    bool? isCompleted,
  }) {
    return OnboardingStateEntity(
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      outputFolderPath: outputFolderPath ?? this.outputFolderPath,
      permissionsStatus: permissionsStatus ?? this.permissionsStatus,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        currentSlideIndex,
        outputFolderPath,
        permissionsStatus,
        isCompleted,
      ];
}
