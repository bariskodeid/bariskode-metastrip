import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/constants/supported_extensions.dart';
import 'package:metastrip/core/utils/file_utils.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/presentation/cubit/viewer_state.dart';

class ViewerCubit extends Cubit<ViewerState> {
  ViewerCubit() : super(ViewerState.initial());

  Future<void> pickFiles() async {
    emit(state.copyWith(isPicking: true, clearError: true));

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: SupportedExtensions.values,
        withData: false,
      );

      if (result == null) {
        emit(state.copyWith(isPicking: false));
        return;
      }

      addPlatformFiles(result.files);
      emit(state.copyWith(isPicking: false));
    } catch (_) {
      emit(
        state.copyWith(
          isPicking: false,
          errorMessage: 'Unable to pick files. Check permissions and retry.',
        ),
      );
    }
  }

  void addPlatformFiles(List<PlatformFile> platformFiles) {
    final seenPaths = state.files.map((file) => file.path).toSet();
    final selected = <FileItemEntity>[];
    var skippedCount = 0;

    for (final file in platformFiles) {
      final path = file.path;
      if (path == null || !seenPaths.add(path)) {
        skippedCount++;
        continue;
      }

      final extension = FileUtils.extension(path);
      if (!SupportedExtensions.contains(extension) ||
          file.size > AppConstants.maxFileSizeBytes) {
        skippedCount++;
        continue;
      }

      selected.add(
        FileItemEntity(
          path: path,
          name: FileUtils.fileName(path),
          extension: extension,
          sizeBytes: file.size,
          addedAt: DateTime.now(),
        ),
      );
    }

    final allFiles = [...state.files, ...selected];
    final nextFiles =
        allFiles.take(AppConstants.maxFilesPerSession).toList(growable: false);
    final droppedCount = allFiles.length - nextFiles.length;
    final totalSkipped = skippedCount + droppedCount;

    emit(
      state.copyWith(
        files: nextFiles,
        errorMessage: totalSkipped > 0
            ? '$totalSkipped file(s) were skipped: duplicate, unsupported, too large, or over limit.'
            : null,
      ),
    );
  }

  void removeFile(String path) {
    emit(
      state.copyWith(
        files: state.files.where((file) => file.path != path).toList(),
        clearError: true,
      ),
    );
  }

  void clear() {
    emit(state.copyWith(files: [], clearError: true));
  }

  void toggleMarkedForRemoval(String path) {
    emit(
      state.copyWith(
        files: state.files
            .map(
              (file) => file.path == path
                  ? file.copyWith(
                      isMarkedForRemoval: !file.isMarkedForRemoval,
                    )
                  : file,
            )
            .toList(),
        clearError: true,
      ),
    );
  }

  void markAllVisibleForRemoval() {
    final visiblePaths = state.visibleFiles.map((file) => file.path).toSet();
    emit(
      state.copyWith(
        files: state.files
            .map(
              (file) => visiblePaths.contains(file.path)
                  ? file.copyWith(isMarkedForRemoval: true)
                  : file,
            )
            .toList(),
        clearError: true,
      ),
    );
  }

  void clearMarkedForRemoval() {
    emit(
      state.copyWith(
        files: state.files
            .map((file) => file.copyWith(isMarkedForRemoval: false))
            .toList(),
        clearError: true,
      ),
    );
  }

  void setSortMode(ViewerSortMode sortMode) {
    emit(state.copyWith(sortMode: sortMode, clearError: true));
  }

  void setFilterQuery(String query) {
    emit(state.copyWith(filterQuery: query, clearError: true));
  }
}
