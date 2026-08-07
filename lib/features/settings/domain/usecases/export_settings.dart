import 'dart:convert';
import 'dart:io';

import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';

/// Exports settings to a JSON file at [exportPath].
class ExportSettings {
  ExportSettings(this._repository);

  final SettingsRepository _repository;

  Future<File> call(String exportPath) async {
    final settings = await _repository.getSettings();
    final portableSettings = settings.toJson();
    final storage = portableSettings['storage']! as Map<String, dynamic>;
    storage.remove('outputFolderPath');
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(portableSettings);
    final file = File(exportPath);
    return file.writeAsString(jsonString);
  }
}
