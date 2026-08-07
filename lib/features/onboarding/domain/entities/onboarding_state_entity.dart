import 'package:equatable/equatable.dart';

enum OnboardingStatus { loading, ready, failure }

/// Entity representing onboarding state
class OnboardingStateEntity extends Equatable {
  const OnboardingStateEntity({
    required this.currentSlideIndex,
    required this.permissionsStatus,
    required this.isCompleted,
    required this.status,
    this.outputFolderPath,
    this.persistenceError,
  });

  final int currentSlideIndex;
  final String? outputFolderPath;
  final Map<String, bool> permissionsStatus;
  final bool isCompleted;
  final OnboardingStatus status;
  final String? persistenceError;

  /// Initial state
  factory OnboardingStateEntity.initial() {
    return const OnboardingStateEntity(
      currentSlideIndex: 0,
      outputFolderPath: null,
      permissionsStatus: {},
      isCompleted: false,
      status: OnboardingStatus.loading,
    );
  }

  /// Copy with method
  OnboardingStateEntity copyWith({
    int? currentSlideIndex,
    String? outputFolderPath,
    Map<String, bool>? permissionsStatus,
    bool? isCompleted,
    OnboardingStatus? status,
    String? persistenceError,
    bool clearPersistenceError = false,
    bool clearOutputFolderPath = false,
  }) {
    return OnboardingStateEntity(
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      outputFolderPath: clearOutputFolderPath
          ? null
          : outputFolderPath ?? this.outputFolderPath,
      permissionsStatus: permissionsStatus ?? this.permissionsStatus,
      isCompleted: isCompleted ?? this.isCompleted,
      status: status ?? this.status,
      persistenceError: clearPersistenceError
          ? null
          : persistenceError ?? this.persistenceError,
    );
  }

  @override
  List<Object?> get props => [
        currentSlideIndex,
        outputFolderPath,
        permissionsStatus,
        isCompleted,
        status,
        persistenceError,
      ];
}
