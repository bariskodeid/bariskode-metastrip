import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/theme/app_colors.dart';
import 'package:metastrip/core/theme/app_theme.dart';
import 'package:metastrip/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:metastrip/features/viewer/presentation/screens/viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();

  runApp(
    MetaStripApp(
      onboardingRepository: SharedPreferencesOnboardingRepository(preferences),
    ),
  );
}

class MetaStripApp extends StatelessWidget {
  const MetaStripApp({
    required this.onboardingRepository,
    super.key,
  });

  final SharedPreferencesOnboardingRepository onboardingRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(AppColorScheme.darkIndustrial),
      home: BlocProvider(
        create: (_) => OnboardingCubit(onboardingRepository)..load(),
        child: const AppEntryPoint(),
      ),
    );
  }
}

class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingStateEntity>(
      builder: (context, state) {
        if (state.isCompleted) {
          return const ViewerScreen();
        }

        return const OnboardingScreen();
      },
    );
  }
}
