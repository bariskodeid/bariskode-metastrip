import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/storage/output_folder_picker.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';
import 'package:metastrip/core/storage/saf_grant_release.dart';
import 'package:metastrip/core/storage/stored_output_folder_repository.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Validates that a folder exists and is writable.
typedef OutputFolderValidator = Future<String> Function(String path);

/// Controls onboarding slide navigation, permissions, persistence.
class OnboardingCubit extends Cubit<OnboardingStateEntity> {
  OnboardingCubit(
    this._repository, {
    OutputFolderValidator? validator,
    SafGrantReleaser? safGrantReleaser,
    StaleOutputFolderResolver? staleOutputFolderResolver,
  })  : _validator = validator ?? validateOutputFolder,
        _releaseSafGrant = safGrantReleaser ?? releaseSafGrant,
        _resolveStaleFolder =
            staleOutputFolderResolver ?? resolveStaleIosOutputFolder,
        super(OnboardingStateEntity.initial());

  static const int lastSlideIndex = 4;

  final OnboardingRepository _repository;
  final OutputFolderValidator _validator;
  final SafGrantReleaser _releaseSafGrant;
  final StaleOutputFolderResolver _resolveStaleFolder;

  /// Loads the onboarding state and validates the saved output folder.
  ///
  /// A completed onboarding whose folder no longer validates is reopened,
  /// unless the folder is a stale iOS app-container path that can be
  /// re-derived (see [resolveStaleIosOutputFolder]); the fresh folder is then
  /// saved and onboarding stays completed.
  Future<void> load() async {
    emit(state.copyWith(status: OnboardingStatus.loading));
    try {
      final isCompleted = await _repository.isOnboardingCompleted();
      var folderPath = await _repository.getOutputFolderPath();

      var completed = isCompleted;
      String? persistenceError;
      if (completed) {
        try {
          if (folderPath == null) throw StateError('missing folder');
          await _validator(folderPath);
        } catch (_) {
          final repaired = await _repairStaleFolder(folderPath);
          if (repaired != null) {
            folderPath = repaired;
          } else {
            completed = false;
            persistenceError =
                'Choose a valid, writable output folder to finish setup.';
          }
        }
      }

      if (completed) {
        emit(
          state.copyWith(
            isCompleted: true,
            outputFolderPath: folderPath,
            clearOutputFolderPath: folderPath == null,
            persistenceError: persistenceError,
            status: OnboardingStatus.ready,
          ),
        );
      } else {
        // Not completed (first run or after a reset): start from a clean
        // slate so no stale slide, permissions or error survive.
        emit(
          OnboardingStateEntity.initial().copyWith(
            outputFolderPath: folderPath,
            persistenceError: persistenceError,
            status: OnboardingStatus.ready,
          ),
        );
      }
    } catch (_) {
      emit(state.copyWith(status: OnboardingStatus.failure));
    }
  }

  /// Re-derives, validates and saves a stale [stored] folder, or returns null.
  Future<String?> _repairStaleFolder(String? stored) async {
    try {
      final fresh = await _resolveStaleFolder(stored);
      if (fresh == null) return null;
      await _validator(fresh);
      await _repository.saveOutputFolderPath(fresh);
      return fresh;
    } catch (_) {
      return null;
    }
  }

  /// Whether the current output folder is set and passes validation.
  Future<bool> hasValidOutputFolder() async {
    final path = state.outputFolderPath;
    if (path == null) return false;
    try {
      await _validator(path);
      return true;
    } catch (_) {
      return false;
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
      final previousPath = state.outputFolderPath;
      await _repository.saveOutputFolderPath(normalizedPath);
      await releaseReplacedSafGrant(
        previousPath,
        normalizedPath,
        _releaseSafGrant,
      );
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
