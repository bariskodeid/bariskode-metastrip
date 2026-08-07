import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/repositories/settings_repository.dart';
import 'package:metastrip/features/settings/domain/validation/settings_validation.dart';

/// Imports settings from a JSON file.
class ImportSettings {
  ImportSettings(
    this._repository, {
    required KeyValueStorage storage,
    OutputFolderValidator? validator,
  })  : _storage = storage,
        _validator = validator ?? validateOutputFolder;

  final SettingsRepository _repository;
  final KeyValueStorage _storage;
  final OutputFolderValidator _validator;

  /// Settings exports are small; reject unexpectedly large inputs before read.
  static const maxImportFileSizeBytes = 1024 * 1024;
  static const maxNamingTemplateLength = 256;
  static const maxCustomColorEntries = 16;

  Future<SettingsEntity> call(File importFile) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in importFile.openRead(
      0,
      maxImportFileSizeBytes + 1,
    )) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.length > maxImportFileSizeBytes) {
      throw const FormatException('Settings file is too large');
    }
    final jsonString = utf8.decode(bytes);
    final map = json.decode(jsonString) as Map<String, dynamic>;
    _validateSchema(map);
    final imported = SettingsEntity.fromJson(map);
    _validate(imported);

    final previous = await _repository.getSettings();
    final previousOutputFolder =
        _storage.getString(AppConstants.keyOutputFolderPath);
    final outputFolder =
        previousOutputFolder ?? previous.storage.outputFolderPath;
    if (outputFolder == null || outputFolder.trim().isEmpty) {
      throw const FormatException('Output folder is required');
    }
    await _validator(outputFolder);

    final settings = imported.copyWith(
      storage: imported.storage.copyWith(outputFolderPath: outputFolder),
    );
    try {
      await _repository.saveSettings(settings);
      await _storage.setString(
        AppConstants.keyOutputFolderPath,
        value: outputFolder,
      );
    } catch (_) {
      await _rollback(previous, previousOutputFolder);
      rethrow;
    }
    return settings;
  }

  void _validate(SettingsEntity settings) {
    if (settings.processing.jpegQuality < 70 ||
        settings.processing.jpegQuality > 100) {
      throw const FormatException('JPEG quality must be between 70 and 100');
    }
    if (settings.processing.concurrentFiles < 1 ||
        settings.processing.concurrentFiles > 8) {
      throw const FormatException('Concurrent files must be between 1 and 8');
    }
    if (settings.storage.folderStructure != 'flat' &&
        settings.storage.folderStructure != 'nested') {
      throw const FormatException('Invalid folder structure');
    }
    final namingTemplate = settings.storage.namingTemplate.trim();
    if (namingTemplate.isEmpty) {
      throw const FormatException('Naming template is required');
    }
    if (namingTemplate.length > maxNamingTemplateLength) {
      throw const FormatException('Naming template is too long');
    }
    if (!isValidSettingsTheme(
      settings.theme.themeName,
      settings.theme.customColors,
    )) {
      throw const FormatException('Invalid theme');
    }
  }

  void _validateSchema(Map<String, dynamic> json) {
    final theme = json['theme'];
    final storage = json['storage'];
    final processing = json['processing'];
    if (theme is! Map<String, dynamic> ||
        theme['themeName'] is! String ||
        (theme.containsKey('customColors') &&
            theme['customColors'] is! Map<String, dynamic>) ||
        storage is! Map<String, dynamic> ||
        storage['namingTemplate'] is! String ||
        storage['folderStructure'] is! String ||
        storage['keepOriginal'] is! bool ||
        (storage.containsKey('outputFolderPath') &&
            storage['outputFolderPath'] is! String) ||
        processing is! Map<String, dynamic> ||
        processing['jpegQuality'] is! int ||
        processing['concurrentFiles'] is! int ||
        processing['autoConfirm'] is! bool) {
      throw const FormatException('Incomplete settings file');
    }
  }

  Future<void> _rollback(
    SettingsEntity previous,
    String? previousOutputFolder,
  ) async {
    try {
      await _repository.saveSettings(previous);
      if (previousOutputFolder == null) {
        await _storage.remove(AppConstants.keyOutputFolderPath);
      } else {
        await _storage.setString(
          AppConstants.keyOutputFolderPath,
          value: previousOutputFolder,
        );
      }
    } catch (_) {
      // Preserve the original import error when rollback cannot complete.
    }
  }
}
