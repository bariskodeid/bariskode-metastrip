/// Failure while reading or writing local application storage.
class StorageException implements Exception {
  const StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}

/// Failure caused by a missing or unusable configured output folder.
class OutputFolderException implements Exception {
  const OutputFolderException(this.message);

  final String message;

  @override
  String toString() => 'OutputFolderException: $message';
}
