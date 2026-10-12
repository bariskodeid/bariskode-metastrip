import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';

/// Opens [uri] externally; returns whether it was launched.
typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// About screen with app info and links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.urlLauncher = _launchExternally});

  static const repositoryUrl =
      'https://github.com/bariskodeid/bariskode-metastrip';
  static const issuesUrl = '$repositoryUrl/issues';
  static const privacyPolicyUrl = '$repositoryUrl/blob/main/PRIVACY-POLICY.md';

  /// Link opener; injectable for tests.
  final ExternalUrlLauncher urlLauncher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Version ${AppConstants.appVersion}+${AppConstants.appBuildNumber}',
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Offline-first metadata viewer & remover.'),
            const SizedBox(height: AppSpacing.xs),
            const Text('Your files. Your metadata. Your rules.'),
            const Spacer(),
            PrimaryButton(
              label: 'GITHUB REPOSITORY',
              icon: Icons.code_outlined,
              onPressed: () => _launchUrl(context, repositoryUrl),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'REPORT ISSUE',
              icon: Icons.bug_report_outlined,
              onPressed: () => _launchUrl(context, issuesUrl),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'PRIVACY POLICY',
              icon: Icons.privacy_tip_outlined,
              onPressed: () => _launchUrl(context, privacyPolicyUrl),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await urlLauncher(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }
}
