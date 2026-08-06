import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';

/// SharedPreferences-backed onboarding repository.
class SharedPreferencesOnboardingRepository implements OnboardingRepository {
  const SharedPreferencesOnboardingRepository(this._preferences);

  final KeyValueStorage _preferences;

  @override
  Future<void> completeOnboarding() async {
    await _preferences.setBool(
      AppConstants.keyOnboardingCompleted,
      value: true,
    );
  }

  @override
  Future<String?> getOutputFolderPath() async {
    return _preferences.getString(AppConstants.keyOutputFolderPath);
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    return _preferences.getBool(AppConstants.keyOnboardingCompleted) ?? false;
  }

  @override
  Future<void> resetOnboarding() async {
    await _preferences.remove(AppConstants.keyOnboardingCompleted);
    await _preferences.remove(AppConstants.keyOutputFolderPath);
  }

  @override
  Future<void> saveOutputFolderPath(String path) async {
    await _preferences.setString(
      AppConstants.keyOutputFolderPath,
      value: path,
    );
  }
}
