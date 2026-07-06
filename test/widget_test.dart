import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:metastrip/main.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MetaStrip app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingCompleted: true,
    });
    final preferences = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MetaStripApp(
        onboardingRepository:
            SharedPreferencesOnboardingRepository(preferences),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('METASTRIP VIEWER'), findsOneWidget);
    expect(find.text('NO FILES LOADED'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'ADD FILES'), findsOneWidget);
  });
}
