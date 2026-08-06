import 'package:equatable/equatable.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

abstract class RemoverEvent extends Equatable {
  const RemoverEvent();

  @override
  List<Object?> get props => [];
}

/// Files handed off from the Viewer or picked directly in the Remover.
class RemoverFilesAdded extends RemoverEvent {
  const RemoverFilesAdded(this.files);

  final List<FileItemEntity> files;

  @override
  List<Object?> get props => [files];
}

class RemoverFileRemoved extends RemoverEvent {
  const RemoverFileRemoved(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

class RemoverClearRequested extends RemoverEvent {
  const RemoverClearRequested();
}

/// Begins sequential processing of the queued files.
class RemoverProcessingStarted extends RemoverEvent {
  const RemoverProcessingStarted();
}

/// Returns the BLoC to idle so a fresh batch can be queued.
class RemoverResetRequested extends RemoverEvent {
  const RemoverResetRequested();
}
