import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/core/storage/output_folder_picker.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';

/// Re-derives a stale stored output folder, or returns `null` when it cannot.
typedef StaleOutputFolderResolver = Future<String?> Function(String? stored);

/// Resolves and validates the output folder persisted during onboarding.
///
/// When the stored folder fails validation and [_resolveStale] can re-derive
/// it (the iOS app container moved after an update or restore), the fresh
/// folder is validated, persisted and returned instead.
class StoredOutputFolderRepository implements OutputFolderRepository {
  const StoredOutputFolderRepository(
    this._storage, {
    OutputFolderValidator validator = validateOutputFolder,
    StaleOutputFolderResolver resolveStale = resolveStaleIosOutputFolder,
  })  : _validator = validator,
        _resolveStale = resolveStale;

  final KeyValueStorage _storage;
  final OutputFolderValidator _validator;
  final StaleOutputFolderResolver _resolveStale;

  @override
  Future<String> getValidOutputFolder() async {
    final path = _storage.getString(AppConstants.keyOutputFolderPath) ?? '';
    try {
      return await _validator(path);
    } catch (error, stackTrace) {
      final fresh = await _resolveStale(path);
      if (fresh == null) Error.throwWithStackTrace(error, stackTrace);
      final valid = await _validator(fresh);
      await _storage.setString(AppConstants.keyOutputFolderPath, value: valid);
      return valid;
    }
  }
}
