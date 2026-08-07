import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/settings/presentation/screens/licenses_screen.dart';

void main() {
  testWidgets('licenses page has one built-in header', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LicensesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('LICENSES'), findsNothing);
    expect(find.text('Licenses'), findsOneWidget);
    expect(find.text('MetaStrip'), findsOneWidget);
    expect(find.text('1.0.0+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('licenses page can navigate back to settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('Settings')),
        onGenerateRoute: (settings) {
          if (settings.name == '/licenses') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const LicensesScreen(),
            );
          }
          return null;
        },
      ),
    );

    Navigator.of(tester.element(find.text('Settings'))).pushNamed('/licenses');
    await tester.pumpAndSettle();
    expect(find.text('Licenses'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(LicensePage), findsNothing);
  });
}
