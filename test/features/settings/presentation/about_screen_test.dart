import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metastrip/features/settings/presentation/screens/about_screen.dart';
import 'package:metastrip/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders about screen scaffold', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows app name and version', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Version ${AppConstants.appVersion}+${AppConstants.appBuildNumber}'), findsOneWidget);
  });

  testWidgets('shows offline-first notice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline-first metadata viewer & remover.'), findsOneWidget);
  });

  testWidgets('shows action buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('GITHUB REPOSITORY'), findsOneWidget);
    expect(find.text('REPORT ISSUE'), findsOneWidget);
    expect(find.text('PRIVACY POLICY'), findsOneWidget);
  });
}
