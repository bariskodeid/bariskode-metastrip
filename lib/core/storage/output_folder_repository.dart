/// Resolves the folder used for all clean output copies.
abstract interface class OutputFolderRepository {
  /// Returns an existing, writable folder or throws a typed exception.
  Future<String> getValidOutputFolder();
}
