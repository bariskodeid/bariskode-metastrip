import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/viewer/presentation/cubit/viewer_cubit.dart';
import 'package:metastrip/features/viewer/presentation/cubit/viewer_state.dart';

void main() {
  group('ViewerCubit', () {
    test('adds supported files', () {
      final cubit = ViewerCubit();

      cubit.addPlatformFiles([
        PlatformFile(name: 'photo.jpg', size: 1200, path: r'C:\tmp\photo.jpg'),
      ]);

      expect(cubit.state.files, hasLength(1));
      expect(cubit.state.files.single.name, 'photo.jpg');
      expect(cubit.state.files.single.extension, 'jpg');
      expect(cubit.state.errorMessage, isNull);
    });

    test('skips duplicate files', () {
      final cubit = ViewerCubit();
      final file = PlatformFile(
        name: 'doc.pdf',
        size: 1200,
        path: r'C:\tmp\doc.pdf',
      );

      cubit.addPlatformFiles([file, file]);

      expect(cubit.state.files, hasLength(1));
      expect(cubit.state.errorMessage, contains('1 file(s) were skipped'));
    });

    test('skips unsupported and oversized files', () {
      final cubit = ViewerCubit();

      cubit.addPlatformFiles([
        PlatformFile(name: 'app.exe', size: 12, path: r'C:\tmp\app.exe'),
        PlatformFile(
          name: 'huge.mp4',
          size: AppConstants.maxFileSizeBytes + 1,
          path: r'C:\tmp\huge.mp4',
        ),
      ]);

      expect(cubit.state.files, isEmpty);
      expect(cubit.state.errorMessage, contains('2 file(s) were skipped'));
    });

    test('enforces session file cap', () {
      final cubit = ViewerCubit();

      cubit.addPlatformFiles(
        List.generate(
          AppConstants.maxFilesPerSession + 2,
          (index) => PlatformFile(
            name: 'file$index.jpg',
            size: 100,
            path: r'C:\tmp\file' '$index.jpg',
          ),
        ),
      );

      expect(cubit.state.files, hasLength(AppConstants.maxFilesPerSession));
      expect(cubit.state.errorMessage, contains('2 file(s) were skipped'));
    });

    test('remove and clear update state', () {
      final cubit = ViewerCubit()
        ..addPlatformFiles([
          PlatformFile(name: 'a.jpg', size: 100, path: r'C:\tmp\a.jpg'),
          PlatformFile(name: 'b.png', size: 100, path: r'C:\tmp\b.png'),
        ]);

      cubit.removeFile(r'C:\tmp\a.jpg');
      expect(cubit.state.files.single.name, 'b.png');

      cubit.clear();
      expect(cubit.state.files, isEmpty);
    });

    test('sorts and filters visible files', () {
      final cubit = ViewerCubit()
        ..addPlatformFiles([
          PlatformFile(name: 'b.png', size: 300, path: r'C:\tmp\b.png'),
          PlatformFile(name: 'a.jpg', size: 100, path: r'C:\tmp\a.jpg'),
          PlatformFile(name: 'c.pdf', size: 200, path: r'C:\tmp\c.pdf'),
        ]);

      cubit.setSortMode(ViewerSortMode.name);
      expect(cubit.state.visibleFiles.map((file) => file.name), [
        'a.jpg',
        'b.png',
        'c.pdf',
      ]);

      cubit.setSortMode(ViewerSortMode.size);
      expect(cubit.state.visibleFiles.first.name, 'b.png');

      cubit.setFilterQuery('pdf');
      expect(cubit.state.visibleFiles.single.name, 'c.pdf');
    });

    test('marks files for remover handoff', () {
      final cubit = ViewerCubit()
        ..addPlatformFiles([
          PlatformFile(name: 'a.jpg', size: 100, path: r'C:\tmp\a.jpg'),
          PlatformFile(name: 'b.png', size: 100, path: r'C:\tmp\b.png'),
        ]);

      cubit.toggleMarkedForRemoval(r'C:\tmp\a.jpg');
      expect(cubit.state.markedCount, 1);

      cubit.markAllVisibleForRemoval();
      expect(cubit.state.markedCount, 2);

      cubit.clearMarkedForRemoval();
      expect(cubit.state.markedCount, 0);
    });
  });
}
