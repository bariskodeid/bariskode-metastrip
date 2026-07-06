import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Use case to check if onboarding has been completed
class GetOnboardingStatus {
  final OnboardingRepository repository;

  GetOnboardingStatus(this.repository);

  Future<bool> call() async {
    return await repository.isOnboardingCompleted();
  }
}
