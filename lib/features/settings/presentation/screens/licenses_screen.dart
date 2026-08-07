import 'package:flutter/material.dart';

/// Licenses screen using Flutter's built-in license page.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LicensePage(
      applicationName: 'MetaStrip',
      applicationVersion: '1.0.0+1',
    );
  }
}
