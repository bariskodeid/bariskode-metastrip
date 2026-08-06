import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/app/app.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/shared_preferences_storage.dart';
import 'package:metastrip/core/storage/stored_output_folder_repository.dart';
import 'package:metastrip/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MetaStrip app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
      AppConstants.keyOutputFolderPath: '/output',
    });
    final preferences = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    final storage = SharedPreferencesStorage(preferences);
    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
          outputFolderValidator: (path) async => path,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('METASTRIP VIEWER'), findsOneWidget);
    expect(find.text('NO FILES LOADED'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'ADD FILES'), findsOneWidget);
  });

  testWidgets('first run renders onboarding after loading', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('storage failure renders retry action instead of onboarding',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    await tester.pumpWidget(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: _FailingOnboardingRepository(),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOCAL STORAGE UNAVAILABLE'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
  });
}

class _FailingOnboardingRepository implements OnboardingRepository {
  @override
  Future<void> completeOnboarding() async {}

  @override
  Future<String?> getOutputFolderPath() => Future.error(StateError('failed'));

  @override
  Future<bool> isOnboardingCompleted() => Future.error(StateError('failed'));

  @override
  Future<void> resetOnboarding() async {}

  @override
  Future<void> saveOutputFolderPath(String path) async {}
}
