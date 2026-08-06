import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';

/// Resolves and validates the output folder persisted during onboarding.
class StoredOutputFolderRepository implements OutputFolderRepository {
  const StoredOutputFolderRepository(this._storage);

  final KeyValueStorage _storage;

  @override
  Future<String> getValidOutputFolder() async {
    final path = _storage.getString(AppConstants.keyOutputFolderPath) ?? '';
    return validateOutputFolder(path);
  }
}
