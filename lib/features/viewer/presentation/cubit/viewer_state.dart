import 'package:equatable/equatable.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

enum ViewerSortMode { name, size, type, addedNewest }

class ViewerState extends Equatable {
  const ViewerState({
    required this.files,
    required this.isPicking,
    this.sortMode = ViewerSortMode.addedNewest,
    this.filterQuery = '',
    this.errorMessage,
  });

  factory ViewerState.initial() {
    return const ViewerState(files: [], isPicking: false);
  }

  final List<FileItemEntity> files;
  final bool isPicking;
  final ViewerSortMode sortMode;
  final String filterQuery;
  final String? errorMessage;

  int get markedCount => files.where((file) => file.isMarkedForRemoval).length;

  List<FileItemEntity> get visibleFiles {
    final query = filterQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? [...files]
        : files
            .where(
              (file) =>
                  file.name.toLowerCase().contains(query) ||
                  file.extension.toLowerCase().contains(query),
            )
            .toList();

    return filtered
      ..sort(
        (a, b) => switch (sortMode) {
          ViewerSortMode.name => a.name.compareTo(b.name),
          ViewerSortMode.size => b.sizeBytes.compareTo(a.sizeBytes),
          ViewerSortMode.type => a.extension.compareTo(b.extension),
          ViewerSortMode.addedNewest => b.addedAt.compareTo(a.addedAt),
        },
      );
  }

  ViewerState copyWith({
    List<FileItemEntity>? files,
    bool? isPicking,
    ViewerSortMode? sortMode,
    String? filterQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ViewerState(
      files: files ?? this.files,
      isPicking: isPicking ?? this.isPicking,
      sortMode: sortMode ?? this.sortMode,
      filterQuery: filterQuery ?? this.filterQuery,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [files, isPicking, sortMode, filterQuery, errorMessage];
}
