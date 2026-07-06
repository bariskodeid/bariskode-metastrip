/// Repository interface for onboarding operations
abstract class OnboardingRepository {
  /// Check if onboarding has been completed
  Future<bool> isOnboardingCompleted();

  /// Mark onboarding as completed
  Future<void> completeOnboarding();

  /// Get saved output folder path
  Future<String?> getOutputFolderPath();

  /// Save output folder path
  Future<void> saveOutputFolderPath(String path);

  /// Reset onboarding state (for testing or reset app data)
  Future<void> resetOnboarding();
}
