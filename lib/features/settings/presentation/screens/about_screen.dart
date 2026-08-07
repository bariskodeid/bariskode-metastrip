import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';

/// About screen with app info and links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
              onPressed: () => _launchUrl('https://github.com/'),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'REPORT ISSUE',
              icon: Icons.bug_report_outlined,
              onPressed: () => _launchUrl('https://github.com/issues'),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'PRIVACY POLICY',
              icon: Icons.privacy_tip_outlined,
              onPressed: () => _launchUrl('https://github.com/privacy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
