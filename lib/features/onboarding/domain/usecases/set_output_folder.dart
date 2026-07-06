import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Use case to save output folder path
class SetOutputFolder {
  final OnboardingRepository repository;

  SetOutputFolder(this.repository);

  Future<void> call(String path) async {
    await repository.saveOutputFolderPath(path);
  }
}
