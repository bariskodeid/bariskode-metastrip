import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/core/theme/app_colors.dart';
import 'package:metastrip/core/theme/app_theme.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_state.dart';
import 'package:metastrip/features/viewer/presentation/screens/viewer_screen.dart';
import 'package:metastrip/shared/widgets/status_panel.dart';

/// Root dependencies composed during application bootstrap.
class AppDependencies {
  AppDependencies({
    required this.onboardingRepository,
    required this.outputFolderRepository,
    required this.removerRepository,
    this.outputFolderValidator,
  });

  final OnboardingRepository onboardingRepository;
  final OutputFolderRepository outputFolderRepository;
  final RemoverRepository removerRepository;
  final OutputFolderValidator? outputFolderValidator;
}

/// MetaStrip application root.
class MetaStripApp extends StatelessWidget {
  const MetaStripApp({
    required this.dependencies,
    required this.settingsCubit,
    super.key,
  });

  final AppDependencies dependencies;
  final SettingsCubit settingsCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: BlocProvider<OnboardingCubit>(
        create: (_) => OnboardingCubit(
          dependencies.onboardingRepository,
          validator: dependencies.outputFolderValidator,
        )..load(),
        child: BlocListener<OnboardingCubit, OnboardingStateEntity>(
          listenWhen: (previous, current) =>
              current.status == OnboardingStatus.ready &&
              (previous.status != OnboardingStatus.ready ||
                  previous.outputFolderPath != current.outputFolderPath),
          listener: (context, state) => context
              .read<SettingsCubit>()
              .synchronizeOutputFolder(state.outputFolderPath),
          child: BlocBuilder<SettingsCubit, SettingsState>(
            buildWhen: (previous, current) =>
                previous.settings?.theme != current.settings?.theme,
            builder: (context, state) {
              final themeSettings = state.settings?.theme;
              final theme = AppColorScheme.fromName(
                themeSettings?.themeName ?? AppConstants.defaultTheme,
                customColors: themeSettings?.customColors,
              );
              return MaterialApp(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(theme),
                home: AppEntryPoint(dependencies: dependencies),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Selects the first screen only after persisted startup state is resolved.
class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingStateEntity>(
      builder: (context, state) {
        return switch (state.status) {
          OnboardingStatus.loading => const _StartupLoadingScreen(),
          OnboardingStatus.failure => _StartupFailureScreen(
              onRetry: context.read<OnboardingCubit>().load,
            ),
          OnboardingStatus.ready => state.isCompleted
              ? ViewerScreen(
                  outputFolderRepository: dependencies.outputFolderRepository,
                  removerRepository: dependencies.removerRepository,
                )
              : const OnboardingScreen(),
        };
      },
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Loading MetaStrip',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: StatusPanel(
            icon: Icons.storage_outlined,
            title: 'LOCAL STORAGE UNAVAILABLE',
            message: 'MetaStrip could not safely read its local settings.',
            actionLabel: 'TRY AGAIN',
            onAction: onRetry,
          ),
        ),
      ),
    );
  }
}
