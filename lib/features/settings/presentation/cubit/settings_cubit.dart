import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/key_value_storage.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';
import 'package:metastrip/features/settings/domain/usecases/clear_cache.dart';
import 'package:metastrip/features/settings/domain/usecases/export_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/get_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/import_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/reset_settings.dart';
import 'package:metastrip/features/settings/domain/usecases/save_settings.dart';
import 'package:metastrip/features/settings/domain/validation/settings_validation.dart';
import 'package:metastrip/features/settings/presentation/cubit/settings_state.dart';

/// Cubit managing settings state and persistence.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required GetSettings getSettings,
    required SaveSettings saveSettings,
    required ResetSettings resetSettings,
    required ExportSettings exportSettings,
    required ImportSettings importSettings,
    required ClearCache clearCache,
    required KeyValueStorage storage,
    OutputFolderValidator? validator,
  })  : _getSettings = getSettings,
        _saveSettings = saveSettings,
        _resetSettings = resetSettings,
        _exportSettings = exportSettings,
        _importSettings = importSettings,
        _clearCache = clearCache,
        _storage = storage,
        _validator = validator ?? validateOutputFolder,
        super(SettingsState.initial()) {
    load();
  }

  final GetSettings _getSettings;
  final SaveSettings _saveSettings;
  final ResetSettings _resetSettings;
  final ExportSettings _exportSettings;
  final ImportSettings _importSettings;
  final ClearCache _clearCache;
  final KeyValueStorage _storage;
  final OutputFolderValidator _validator;
  Future<void> _operationQueue = Future<void>.value();
  bool _resetBarrier = false;

  /// Loads settings from repository and computes cache size.
  Future<void> load() => _enqueue(_load);

  Future<void> _load() async {
    emit(state.copyWith(status: SettingsStatus.loading, clearError: true));
    try {
      final settings = await _getSettings();
      final cacheSize = await _clearCache();
      emit(state.copyWith(
        settings: settings,
        status: SettingsStatus.loaded,
        cacheSizeBytes: cacheSize,
      ));
    } catch (_) {
      emit(state.copyWith(
          status: SettingsStatus.error,
          errorMessage: 'Failed to load settings'));
    }
  }

  /// Updates theme selection.
  Future<void> updateTheme(
    String themeName, {
    Map<String, int>? customColors,
  }) {
    if (_resetBarrier) return Future<void>.value();
    if (!isValidSettingsTheme(themeName, customColors)) {
      return _rejectUpdate('Invalid theme');
    }
    return _mutate(
      (current) => current.copyWith(
        theme: current.theme.copyWith(
          themeName: themeName,
          customColors: customColors,
          clearCustomColors: themeName != 'custom',
        ),
      ),
    );
  }

  /// Updates output folder path after validation.
  Future<void> updateOutputFolder(String path) {
    if (_resetBarrier) return Future<void>.value();
    return _enqueue(() => _updateOutputFolder(path));
  }

  /// Mirrors an output folder already persisted by onboarding.
  void synchronizeOutputFolder(String? path) {
    if (_resetBarrier) return;
    final current = state.settings;
    if (current == null || current.storage.outputFolderPath == path) return;
    emit(
      state.copyWith(
        settings: current.copyWith(
          storage: current.storage.copyWith(
            outputFolderPath: path,
            clearOutputFolderPath: path == null,
          ),
        ),
      ),
    );
  }

  Future<void> _updateOutputFolder(String path) async {
    try {
      await _validator(path);
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Invalid folder'));
      return;
    }

    final previous = state.settings!;
    final previousOutputFolder =
        _storage.getString(AppConstants.keyOutputFolderPath);
    final updated = previous.copyWith(
      storage: previous.storage.copyWith(outputFolderPath: path),
    );
    emit(state.copyWith(status: SettingsStatus.saving, clearError: true));
    try {
      await _saveSettings(updated);
      await _storage.setString(AppConstants.keyOutputFolderPath, value: path);
      emit(state.copyWith(settings: updated, status: SettingsStatus.loaded));
    } catch (_) {
      try {
        await _saveSettings(previous);
        if (previousOutputFolder == null) {
          await _storage.remove(AppConstants.keyOutputFolderPath);
        } else {
          await _storage.setString(
            AppConstants.keyOutputFolderPath,
            value: previousOutputFolder,
          );
        }
      } catch (_) {
        // Preserve the original save failure when rollback cannot complete.
      }
      emit(state.copyWith(
        status: SettingsStatus.error,
        errorMessage: 'Failed to save output folder',
      ));
    }
  }

  /// Updates naming template.
  Future<void> updateNamingTemplate(String template) {
    if (_resetBarrier) return Future<void>.value();
    if (template.trim().isEmpty ||
        template.trim().length > ImportSettings.maxNamingTemplateLength) {
      return _rejectUpdate('Invalid naming template');
    }
    return _mutate(
      (current) => current.copyWith(
        storage: current.storage.copyWith(namingTemplate: template),
      ),
    );
  }

  /// Updates folder structure ('flat' or 'nested').
  Future<void> updateFolderStructure(String structure) {
    if (_resetBarrier) return Future<void>.value();
    if (structure != 'flat' && structure != 'nested') {
      return _rejectUpdate('Invalid folder structure');
    }
    return _mutate(
      (current) => current.copyWith(
        storage: current.storage.copyWith(folderStructure: structure),
      ),
    );
  }

  /// Preserves the clean-copy invariant for legacy callers.
  Future<void> updateKeepOriginal(bool value) {
    if (_resetBarrier || value) return Future<void>.value();
    return _rejectUpdate('Original files are always kept');
  }

  /// Updates JPEG quality (70-100).
  Future<void> updateJpegQuality(int quality) {
    if (_resetBarrier) return Future<void>.value();
    if (quality < 70 || quality > 100) {
      return _rejectUpdate('Invalid JPEG quality');
    }
    return _mutate(
      (current) => current.copyWith(
        processing: current.processing.copyWith(jpegQuality: quality),
      ),
    );
  }

  /// Updates concurrent files limit (1-8).
  Future<void> updateConcurrentFiles(int count) {
    if (_resetBarrier) return Future<void>.value();
    if (count < 1 || count > 8) {
      return _rejectUpdate('Invalid concurrent files limit');
    }
    return _mutate(
      (current) => current.copyWith(
        processing: current.processing.copyWith(concurrentFiles: count),
      ),
    );
  }

  /// Updates auto-confirm toggle.
  Future<void> updateAutoConfirm(bool value) => _resetBarrier
      ? Future<void>.value()
      : _mutate(
          (current) => current.copyWith(
            processing: current.processing.copyWith(autoConfirm: value),
          ),
        );

  Future<void> _mutate(
    SettingsEntity Function(SettingsEntity current) mutation,
  ) =>
      _enqueue(() => _saveNow(mutation(state.settings!)));

  Future<void> _rejectUpdate(String message) => _enqueue(() async {
        emit(state.copyWith(
          status: SettingsStatus.error,
          errorMessage: message,
        ));
      });

  Future<void> _saveNow(SettingsEntity settings) async {
    emit(state.copyWith(status: SettingsStatus.saving, clearError: true));
    try {
      await _saveSettings(settings);
      emit(state.copyWith(settings: settings, status: SettingsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
          status: SettingsStatus.error, errorMessage: 'Failed to save'));
    }
  }

  /// Clears temporary cache files.
  Future<void> clearCache() => _enqueue(_clearCacheNow);

  Future<void> _clearCacheNow() async {
    emit(state.copyWith(status: SettingsStatus.saving, clearError: true));
    try {
      final bytes = await _clearCache();
      emit(state.copyWith(
        status: SettingsStatus.loaded,
        cacheSizeBytes: 0,
        errorMessage: 'Cache cleared ($bytes bytes)',
      ));
    } catch (_) {
      emit(state.copyWith(
          status: SettingsStatus.error, errorMessage: 'Failed to clear cache'));
    }
  }

  /// Resets all settings and onboarding data.
  Future<bool> resetAllData() {
    if (_resetBarrier) return Future<bool>.value(false);
    _resetBarrier = true;
    return _enqueue(_resetAllDataNow);
  }

  Future<bool> _resetAllDataNow() async {
    emit(state.copyWith(status: SettingsStatus.saving, clearError: true));
    try {
      await _resetSettings();
      emit(state.copyWith(
        settings: SettingsEntity.defaults(),
        status: SettingsStatus.loaded,
        cacheSizeBytes: 0,
      ));
      // App restart to onboarding handled by caller
      return true;
    } catch (_) {
      emit(state.copyWith(
          status: SettingsStatus.error, errorMessage: 'Failed to reset'));
      return false;
    } finally {
      _resetBarrier = false;
    }
  }

  /// Exports settings to JSON file.
  Future<bool> exportSettings(String path) =>
      _enqueue(() => _exportSettingsNow(path));

  Future<bool> _exportSettingsNow(String path) async {
    try {
      await _exportSettings(path);
      emit(state.copyWith(errorMessage: 'Settings exported'));
      return true;
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Export failed'));
      return false;
    }
  }

  /// Imports settings from JSON file.
  Future<bool> importSettings(String path) {
    if (_resetBarrier) return Future<bool>.value(false);
    return _enqueue(() => _importSettingsNow(path));
  }

  Future<bool> _importSettingsNow(String path) async {
    emit(state.copyWith(status: SettingsStatus.saving, clearError: true));
    try {
      final settings = await _importSettings(File(path));
      emit(state.copyWith(settings: settings, status: SettingsStatus.loaded));
      return true;
    } catch (_) {
      emit(state.copyWith(
          status: SettingsStatus.error, errorMessage: 'Import failed'));
      return false;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return result;
  }
}
