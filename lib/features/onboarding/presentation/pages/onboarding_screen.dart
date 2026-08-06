import 'dart:io' show Platform;

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';
import 'package:metastrip/shared/widgets/secondary_button.dart';
import 'package:saf/saf.dart';

/// First-run onboarding wizard.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingStateEntity>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        final index = state.currentSlideIndex;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Expanded(child: _OnboardingSlide(index: index)),
                  _ProgressDots(index: index),
                  if (state.persistenceError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.persistenceError!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      if (index > 0)
                        Expanded(
                          child: SecondaryButton(
                            label: 'BACK',
                            onPressed: cubit.previousSlide,
                          ),
                        ),
                      if (index > 0) const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          label: index == OnboardingCubit.lastSlideIndex
                              ? 'DONE'
                              : 'NEXT',
                          onPressed: index == OnboardingCubit.lastSlideIndex
                              ? _canComplete(state)
                                  ? cubit.complete
                                  : null
                              : cubit.nextSlide,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _canComplete(OnboardingStateEntity state) {
    return state.outputFolderPath != null &&
        state.outputFolderPath!.trim().isNotEmpty &&
        state.permissionsStatus.isNotEmpty;
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      0 => const _BasicSlide(
          icon: Icons.shield_outlined,
          title: AppConstants.appName,
          body:
              '${AppConstants.appTagline}\n\nView and remove hidden metadata offline.',
        ),
      1 => const _BasicSlide(
          icon: Icons.search_outlined,
          title: 'VIEW METADATA',
          body: 'Inspect EXIF, document properties, media tags, timestamps, '
              'and GPS traces.',
        ),
      2 => const _BasicSlide(
          icon: Icons.cleaning_services_outlined,
          title: 'REMOVE SAFELY',
          body:
              'Create clean output copies. Originals stay untouched by default.',
        ),
      3 => const _FolderSlide(),
      _ => const _PermissionSlide(),
    };
  }
}

class _BasicSlide extends StatelessWidget {
  const _BasicSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 96, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.xl),
        Text(title.toUpperCase(), style: theme.textTheme.displayLarge),
        const SizedBox(height: AppSpacing.md),
        Text(
          body,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FolderSlide extends StatelessWidget {
  const _FolderSlide();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingStateEntity>(
      builder: (context, state) {
        final path = state.outputFolderPath;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BasicSlide(
              icon: Icons.folder_outlined,
              title: 'OUTPUT FOLDER',
              body: path ?? 'Choose where cleaned files will be saved.',
            ),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              label: 'CHOOSE FOLDER',
              onPressed: () async {
                String? directory;
                if (Platform.isAndroid) {
                  final result = await Saf().pickDirectory();
                  directory = result?.uri;
                } else {
                  directory = await fs.getDirectoryPath();
                }
                if (directory != null &&
                    directory.trim().isNotEmpty &&
                    context.mounted) {
                  await context
                      .read<OnboardingCubit>()
                      .setOutputFolder(directory);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _PermissionSlide extends StatelessWidget {
  const _PermissionSlide();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingStateEntity>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        final permissions = state.permissionsStatus;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _BasicSlide(
              icon: Icons.lock_open_outlined,
              title: 'PRIVACY FIRST',
              body: 'MetaStrip uses the system picker and avoids broad media '
                  'permissions for the Viewer MVP.',
            ),
            const SizedBox(height: AppSpacing.lg),
            ...permissions.entries.map(
              (entry) => ListTile(
                leading: Icon(
                  entry.value ? Icons.check_circle : Icons.error_outline,
                ),
                title: Text(entry.key),
                trailing: Text(entry.value ? 'OK' : 'PENDING'),
              ),
            ),
            SecondaryButton(
              label: 'I UNDERSTAND',
              onPressed: () async {
                await cubit.requestPermissions();
                await cubit.complete();
              },
            ),
          ],
        );
      },
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        OnboardingCubit.lastSlideIndex + 1,
        (dotIndex) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: dotIndex == index ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color:
                dotIndex == index ? primary : primary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}
