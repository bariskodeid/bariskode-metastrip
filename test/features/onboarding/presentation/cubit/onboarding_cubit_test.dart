import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/features/onboarding/presentation/pages/onboarding_screen.dart';

void main() {
  test('load resolves completed startup', () async {
    final cubit = OnboardingCubit(
      _FakeOnboardingRepository(completed: true, outputFolder: '/output'),
      validator: _validFolder,
    );

    await cubit.load();

    expect(cubit.state.status, OnboardingStatus.ready);
    expect(cubit.state.isCompleted, isTrue);
    expect(cubit.state.outputFolderPath, '/output');
    await cubit.close();
  });

  test('load resolves first run separately from failure', () async {
    final cubit = OnboardingCubit(_FakeOnboardingRepository());

    await cubit.load();

    expect(cubit.state.status, OnboardingStatus.ready);
    expect(cubit.state.isCompleted, isFalse);
    await cubit.close();
  });

  test('load clears an output folder removed from storage', () async {
    final repository = _FakeOnboardingRepository(outputFolder: '/old');
    final cubit = OnboardingCubit(repository, validator: _validFolder);
    await cubit.load();
    expect(cubit.state.outputFolderPath, '/old');
    repository.outputFolder = null;

    await cubit.load();

    expect(cubit.state.outputFolderPath, isNull);
    await cubit.close();
  });

  test('load exposes retryable storage failure', () async {
    final repository = _FakeOnboardingRepository(shouldFail: true);
    final cubit = OnboardingCubit(repository);

    await cubit.load();

    expect(cubit.state.status, OnboardingStatus.failure);
    repository.shouldFail = false;
    await cubit.load();
    expect(cubit.state.status, OnboardingStatus.ready);
    await cubit.close();
  });

  test('output folder save failure is actionable and keeps old value',
      () async {
    final repository = _FakeOnboardingRepository(shouldFailSave: true);
    final cubit = OnboardingCubit(repository);

    await cubit.setOutputFolder('/output');

    expect(cubit.state.outputFolderPath, isNull);
    expect(cubit.state.persistenceError, contains('output folder'));
    await cubit.close();
  });

  test('invalid output folder is not saved', () async {
    final repository = _FakeOnboardingRepository();
    final cubit = OnboardingCubit(repository, validator: _invalidFolder);

    await cubit.setOutputFolder('/missing');

    expect(cubit.state.outputFolderPath, isNull);
    expect(cubit.state.persistenceError, contains('output folder'));
    expect(repository.savedPath, isNull);
    await cubit.close();
  });

  test('completion validates the selected output folder', () async {
    final repository = _FakeOnboardingRepository();
    final cubit = OnboardingCubit(repository, validator: _invalidFolder);
    await cubit.requestPermissions();

    await cubit.complete();

    expect(cubit.state.isCompleted, isFalse);
    expect(cubit.state.persistenceError, contains('valid'));
    expect(repository.completed, isFalse);
    await cubit.close();
  });

  test('completion failure does not mark onboarding completed', () async {
    final repository = _FakeOnboardingRepository(shouldFailComplete: true);
    final cubit = OnboardingCubit(repository);

    await cubit.complete();

    expect(cubit.state.isCompleted, isFalse);
    expect(cubit.state.persistenceError, contains('finish setup'));
    await cubit.close();
  });

  testWidgets('completion failure remains on onboarding and shows retry text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = OnboardingCubit(
      _FakeOnboardingRepository(shouldFailComplete: true),
      validator: _validFolder,
    );
    await cubit.setOutputFolder('/output');
    await cubit.requestPermissions();
    cubit.setSlide(OnboardingCubit.lastSlideIndex);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const OnboardingScreen(),
        ),
      ),
    );
    await tester.tap(find.text('DONE'));
    await tester.pump();

    expect(find.text('Could not finish setup. Try again.'), findsOneWidget);
    expect(cubit.state.isCompleted, isFalse);
    await cubit.close();
  });
}

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository({
    this.completed = false,
    this.outputFolder,
    this.shouldFail = false,
    this.shouldFailSave = false,
    this.shouldFailComplete = false,
  });

  bool completed;
  String? outputFolder;
  bool shouldFail;
  final bool shouldFailSave;
  final bool shouldFailComplete;
  String? savedPath;

  @override
  Future<void> completeOnboarding() async {
    if (shouldFailComplete) throw StateError('storage unavailable');
    completed = true;
  }

  @override
  Future<String?> getOutputFolderPath() async {
    if (shouldFail) throw StateError('storage unavailable');
    return outputFolder;
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    if (shouldFail) throw StateError('storage unavailable');
    return completed;
  }

  @override
  Future<void> resetOnboarding() async {}

  @override
  Future<void> saveOutputFolderPath(String path) async {
    if (shouldFailSave) throw StateError('storage unavailable');
    savedPath = path;
  }
}

Future<String> _validFolder(String path) async => path;

Future<String> _invalidFolder(String path) async {
  throw StateError('invalid folder');
}
