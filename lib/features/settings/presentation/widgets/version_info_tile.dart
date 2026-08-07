import 'package:flutter/material.dart';
import 'package:metastrip/core/constants/app_constants.dart';

/// Displays app version and build number.
class VersionInfoTile extends StatelessWidget {
  const VersionInfoTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.info_outline),
      title: const Text('Version'),
      subtitle: Text(
        '${AppConstants.appVersion}+${AppConstants.appBuildNumber}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
