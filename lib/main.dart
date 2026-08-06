import 'package:flutter/material.dart';
import 'package:metastrip/app/app.dart';
import 'package:metastrip/core/storage/shared_preferences_storage.dart';
import 'package:metastrip/core/storage/stored_output_folder_repository.dart';
import 'package:metastrip/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
}

Future<void> _bootstrap() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    runApp(
      MetaStripApp(
        dependencies: AppDependencies(
          onboardingRepository: SharedPreferencesOnboardingRepository(storage),
          outputFolderRepository: StoredOutputFolderRepository(storage),
          removerRepository: RemoverRepositoryImpl(),
        ),
      ),
    );
  } catch (_) {
    runApp(const _BootstrapFailureApp(onRetry: _bootstrap));
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('LOCAL STORAGE UNAVAILABLE'),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: onRetry, child: const Text('TRY AGAIN')),
            ],
          ),
        ),
      ),
    );
  }
}
