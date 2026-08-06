import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Validates that a folder exists and is writable.
typedef OutputFolderValidator = Future<String> Function(String path);

/// Controls onboarding slide navigation, permissions, persistence.
class OnboardingCubit extends Cubit<OnboardingStateEntity> {
  OnboardingCubit(this._repository, {OutputFolderValidator? validator})
      : _validator = validator ?? validateOutputFolder,
        super(OnboardingStateEntity.initial());

  static const int lastSlideIndex = 4;

  final OnboardingRepository _repository;
  final OutputFolderValidator _validator;

  Future<void> load() async {
    emit(state.copyWith(status: OnboardingStatus.loading));
    try {
      final isCompleted = await _repository.isOnboardingCompleted();
      final folderPath = await _repository.getOutputFolderPath();

      var completed = isCompleted;
      var persistenceError = state.persistenceError;
      if (completed) {
        try {
          if (folderPath == null) throw StateError('missing folder');
          await _validator(folderPath);
        } catch (_) {
          completed = false;
          persistenceError =
              'Choose a valid, writable output folder to finish setup.';
        }
      }

      emit(
        state.copyWith(
          isCompleted: completed,
          outputFolderPath: folderPath,
          persistenceError: persistenceError,
          status: OnboardingStatus.ready,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: OnboardingStatus.failure));
    }
  }

  void nextSlide() {
    if (state.currentSlideIndex < lastSlideIndex) {
      emit(state.copyWith(currentSlideIndex: state.currentSlideIndex + 1));
    }
  }

  void previousSlide() {
    if (state.currentSlideIndex > 0) {
      emit(state.copyWith(currentSlideIndex: state.currentSlideIndex - 1));
    }
  }

  void setSlide(int index) {
    if (index < 0 || index > lastSlideIndex) {
      return;
    }

    emit(state.copyWith(currentSlideIndex: index));
  }

  Future<void> setOutputFolder(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return;
    }

    try {
      await _validator(normalizedPath);
      await _repository.saveOutputFolderPath(normalizedPath);
      emit(
        state.copyWith(
          outputFolderPath: normalizedPath,
          clearPersistenceError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          persistenceError: 'Could not save the output folder. Try again.',
        ),
      );
    }
  }

  Future<void> requestPermissions() async {
    emit(
      state.copyWith(
        permissionsStatus: const {
          'System picker scoped access': true,
          'No broad media permission': true,
        },
      ),
    );
  }

  Future<void> complete() async {
    final folderPath = state.outputFolderPath;
    if (folderPath == null) {
      emit(
        state.copyWith(
          isCompleted: false,
          persistenceError:
              'Choose a valid, writable output folder to finish setup.',
        ),
      );
      return;
    }

    try {
      await _validator(folderPath);
      await _repository.completeOnboarding();
      emit(state.copyWith(isCompleted: true, clearPersistenceError: true));
    } catch (_) {
      emit(
        state.copyWith(
          isCompleted: false,
          persistenceError: 'Could not finish setup. Try again.',
        ),
      );
    }
  }
}
