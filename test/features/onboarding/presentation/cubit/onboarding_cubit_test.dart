import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/onboarding/domain/entities/onboarding_state_entity.dart';
import 'package:metastrip/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:metastrip/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:metastrip/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  blocTest<OnboardingCubit, OnboardingStateEntity>(
    'load after reset starts at slide 0 with no permissions and no error',
    build: () => OnboardingCubit(
      _FakeOnboardingRepository(),
      validator: _validFolder,
    ),
    seed: () => OnboardingStateEntity.initial().copyWith(
      currentSlideIndex: 3,
      permissionsStatus: const {'System picker scoped access': true},
      persistenceError: 'stale error',
      isCompleted: true,
      status: OnboardingStatus.ready,
    ),
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      OnboardingStateEntity.initial().copyWith(
        status: OnboardingStatus.ready,
      ),
    ],
  );

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

  Future<OnboardingCubit> pumpFolderSlide(
    WidgetTester tester,
    OnboardingScreen screen, {
    String? initialFolder,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = OnboardingCubit(
      _FakeOnboardingRepository(),
      validator: _validFolder,
    );
    addTearDown(cubit.close);
    if (initialFolder != null) await cubit.setOutputFolder(initialFolder);
    cubit.setSlide(3);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: screen),
      ),
    );
    return cubit;
  }

  testWidgets(
      'default picker failure on an unsupported platform shows a snackbar',
      (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final cubit = await pumpFolderSlide(tester, const OnboardingScreen());

      await tester.tap(find.text('CHOOSE FOLDER'));
      await tester.pumpAndSettle();

      expect(find.text('Folder selection failed'), findsOneWidget);
      expect(cubit.state.outputFolderPath, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('iOS container path changes between launches', () {
    late Directory temp;
    late String stalePath;
    late String freshPath;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('metastrip_ios_launch_');
      addTearDown(() => temp.delete(recursive: true));
      // First launch saved this path; the update moved the container.
      stalePath = '${temp.path}/old-uuid/Documents/MetaStrip';
      freshPath = '${temp.path}/new-uuid/Documents/MetaStrip';
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance =
          _FakePathProvider('${temp.path}/new-uuid/Documents');
      addTearDown(() => PathProviderPlatform.instance = previous);
    });

    test('iOS load re-derives the folder and stays completed', () async {
      final repository = _FakeOnboardingRepository(
        completed: true,
        outputFolder: stalePath,
      );
      final cubit = OnboardingCubit(repository);
      addTearDown(cubit.close);
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await cubit.load();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(cubit.state.isCompleted, isTrue);
      expect(cubit.state.outputFolderPath, freshPath);
      expect(cubit.state.persistenceError, isNull);
      expect(repository.savedPath, freshPath);
      expect(await Directory(freshPath).exists(), isTrue);
    });

    test('non-iOS load still requires choosing a folder again', () async {
      final repository = _FakeOnboardingRepository(
        completed: true,
        outputFolder: stalePath,
      );
      final cubit = OnboardingCubit(repository);
      addTearDown(cubit.close);
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await cubit.load();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(cubit.state.isCompleted, isFalse);
      expect(cubit.state.outputFolderPath, stalePath);
      expect(cubit.state.persistenceError, contains('valid'));
      expect(repository.savedPath, isNull);
    });
  });

  testWidgets('iOS folder slide re-fills a stale saved folder', (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakeOnboardingRepository(
        outputFolder: '/old-uuid/Documents/MetaStrip',
      );
      final cubit = OnboardingCubit(
        repository,
        validator: (path) async {
          if (path.startsWith('/old-uuid')) throw StateError('stale');
          return path;
        },
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.outputFolderPath, '/old-uuid/Documents/MetaStrip');
      cubit.setSlide(3);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: OnboardingScreen(
              directoryPicker: ({onError}) async =>
                  '/new-uuid/Documents/MetaStrip',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.outputFolderPath, '/new-uuid/Documents/MetaStrip');
      expect(repository.savedPath, '/new-uuid/Documents/MetaStrip');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS folder slide keeps a valid saved folder', (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var picks = 0;
      final cubit = await pumpFolderSlide(
        tester,
        OnboardingScreen(
          directoryPicker: ({onError}) async {
            picks++;
            return '/docs/MetaStrip';
          },
        ),
        initialFolder: '/docs/MetaStrip',
      );
      await tester.pumpAndSettle();

      expect(picks, 0);
      expect(cubit.state.outputFolderPath, '/docs/MetaStrip');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS folder slide shows the Files location and auto-fills it',
      (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final cubit = await pumpFolderSlide(
        tester,
        OnboardingScreen(
          directoryPicker: ({onError}) async => '/docs/MetaStrip',
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.outputFolderPath, '/docs/MetaStrip');
      expect(
        find.text('Saved to Files \u203a On My iPhone \u203a MetaStrip'),
        findsOneWidget,
      );
      expect(find.text('Folder selection failed'), findsNothing);

      cubit.nextSlide();
      await cubit.requestPermissions();
      await tester.pumpAndSettle();
      final done = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('DONE'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(done.onPressed, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS auto-fill failure shows a snackbar and leaves no folder',
      (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final cubit = await pumpFolderSlide(
        tester,
        OnboardingScreen(
          directoryPicker: ({onError}) async {
            onError?.call(StateError('no documents'));
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Folder selection failed'), findsOneWidget);
      expect(cubit.state.outputFolderPath, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('changing output folder releases the previous SAF grant', () async {
    final released = <String>[];
    final cubit = OnboardingCubit(
      _FakeOnboardingRepository(),
      validator: _validFolder,
      safGrantReleaser: (uri) async => released.add(uri),
    );
    addTearDown(cubit.close);

    await cubit.setOutputFolder('content://tree/old');
    expect(released, isEmpty);
    await cubit.setOutputFolder('content://tree/old');
    expect(released, isEmpty);
    await cubit.setOutputFolder('content://tree/new');

    expect(released, ['content://tree/old']);
    expect(cubit.state.outputFolderPath, 'content://tree/new');
  });

  testWidgets('thrown picker exception shows a snackbar', (tester) async {
    final cubit = await pumpFolderSlide(
      tester,
      OnboardingScreen(
        directoryPicker: ({onError}) async => throw StateError('boom'),
      ),
    );

    await tester.tap(find.text('CHOOSE FOLDER'));
    await tester.pumpAndSettle();

    expect(find.text('Folder selection failed'), findsOneWidget);
    expect(cubit.state.outputFolderPath, isNull);
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

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String? documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
