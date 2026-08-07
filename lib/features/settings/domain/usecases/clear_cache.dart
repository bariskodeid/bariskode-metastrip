import 'package:metastrip/core/storage/key_value_storage.dart';

/// Clears temporary cache files and returns bytes cleared.
class ClearCache {
  ClearCache(KeyValueStorage _);

  Future<int> call() async {
    // Phase 5: Stub implementation returns 0.
    // Full cache clearing (temp files, thumbnails) can be implemented
    // in Phase 6 when cache directories are actively used.
    return 0;
  }
}
