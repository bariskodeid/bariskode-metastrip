import 'package:flutter/material.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';

class EmptyViewerState extends StatelessWidget {
  const EmptyViewerState({
    required this.onPickFiles,
    required this.isPicking,
    super.key,
  });

  final VoidCallback onPickFiles;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.file_open_outlined,
              size: 88,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('NO FILES LOADED', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add files to inspect basic info. Metadata extraction comes next.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Add Files',
              icon: Icons.add,
              isLoading: isPicking,
              onPressed: onPickFiles,
            ),
          ],
        ),
      ),
    );
  }
}
