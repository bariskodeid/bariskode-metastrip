import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';

void main() {
  test('persists onboarding state through storage abstraction', () async {
    final storage = _MemoryStorage();
    final repository = SharedPreferencesOnboardingRepository(storage);

    expect(await repository.isOnboardingCompleted(), isFalse);
    await repository.saveOutputFolderPath('/output');
    await repository.completeOnboarding();

    expect(await repository.isOnboardingCompleted(), isTrue);
    expect(await repository.getOutputFolderPath(), '/output');
    expect(storage.values[AppConstants.keyOnboardingCompleted], isTrue);
  });

  test('reset removes onboarding and output folder values', () async {
    final storage = _MemoryStorage();
    final repository = SharedPreferencesOnboardingRepository(storage);
    await repository.completeOnboarding();
    await repository.saveOutputFolderPath('/output');

    await repository.resetOnboarding();

    expect(await repository.isOnboardingCompleted(), isFalse);
    expect(await repository.getOutputFolderPath(), isNull);
  });
}

class _MemoryStorage implements KeyValueStorage {
  final Map<String, Object> values = {};

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setBool(String key, {required bool value}) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, {required String value}) async {
    values[key] = value;
  }
}
