import 'package:equatable/equatable.dart';

/// Basic selected-file representation for the Viewer MVP.
class FileItemEntity extends Equatable {
  const FileItemEntity({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.addedAt,
    this.isMarkedForRemoval = false,
  });

  final String path;
  final String name;
  final String extension;
  final int sizeBytes;
  final DateTime addedAt;
  final bool isMarkedForRemoval;

  FileItemEntity copyWith({bool? isMarkedForRemoval}) {
    return FileItemEntity(
      path: path,
      name: name,
      extension: extension,
      sizeBytes: sizeBytes,
      addedAt: addedAt,
      isMarkedForRemoval: isMarkedForRemoval ?? this.isMarkedForRemoval,
    );
  }

  @override
  List<Object?> get props => [
        path,
        name,
        extension,
        sizeBytes,
        addedAt,
        isMarkedForRemoval,
      ];
}
