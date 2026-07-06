import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Controls onboarding slide navigation, permissions, persistence.
class OnboardingCubit extends Cubit<OnboardingStateEntity> {
  OnboardingCubit(this._repository) : super(OnboardingStateEntity.initial());

  static const int lastSlideIndex = 4;

  final OnboardingRepository _repository;

  Future<void> load() async {
    try {
      final isCompleted = await _repository.isOnboardingCompleted();
      final folderPath = await _repository.getOutputFolderPath();

      emit(
        state.copyWith(
          isCompleted: isCompleted,
          outputFolderPath: folderPath,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isCompleted: false));
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
      await _repository.saveOutputFolderPath(normalizedPath);
      emit(state.copyWith(outputFolderPath: normalizedPath));
    } catch (_) {
      emit(state);
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
    try {
      await _repository.completeOnboarding();
      emit(state.copyWith(isCompleted: true));
    } catch (_) {
      emit(state);
    }
  }
}
