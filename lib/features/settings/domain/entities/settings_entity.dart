import 'package:equatable/equatable.dart';
import 'package:metastrip/core/constants/app_constants.dart';

/// Root settings entity containing all user-configurable settings.
class SettingsEntity extends Equatable {
  const SettingsEntity({
    required this.theme,
    required this.storage,
    required this.processing,
  });

  final ThemeSettingsEntity theme;
  final StorageSettingsEntity storage;
  final ProcessingSettingsEntity processing;

  factory SettingsEntity.defaults() => SettingsEntity(
        theme: ThemeSettingsEntity.defaults(),
        storage: StorageSettingsEntity.defaults(),
        processing: ProcessingSettingsEntity.defaults(),
      );

  SettingsEntity copyWith({
    ThemeSettingsEntity? theme,
    StorageSettingsEntity? storage,
    ProcessingSettingsEntity? processing,
  }) =>
      SettingsEntity(
        theme: theme ?? this.theme,
        storage: storage ?? this.storage,
        processing: processing ?? this.processing,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.toJson(),
        'storage': storage.toJson(),
        'processing': processing.toJson(),
      };

  factory SettingsEntity.fromJson(Map<String, dynamic> json) => SettingsEntity(
        theme: ThemeSettingsEntity.fromJson(
            json['theme'] as Map<String, dynamic>? ?? {}),
        storage: StorageSettingsEntity.fromJson(
            json['storage'] as Map<String, dynamic>? ?? {}),
        processing: ProcessingSettingsEntity.fromJson(
            json['processing'] as Map<String, dynamic>? ?? {}),
      );

  @override
  List<Object?> get props => [theme, storage, processing];
}

/// Theme-related settings (color theme selection).
class ThemeSettingsEntity extends Equatable {
  const ThemeSettingsEntity({
    required this.themeName,
    this.customColors,
  });

  /// Theme key from [AppColorScheme.allThemes] (e.g. 'Dark Industrial'),
  /// or 'custom' when using customColors.
  final String themeName;

  /// Custom color overrides when themeName is 'custom'.
  /// Map keys: backgroundPrimary, backgroundSecondary, backgroundTertiary,
  /// border, borderEmphasis, textPrimary, textSecondary, textTertiary,
  /// textInverse, accentPrimary, accentSecondary, accentSuccess,
  /// accentDanger, accentInfo, privacyWarning, overlay
  /// Values are ARGB ints (Color.value).
  final Map<String, int>? customColors;

  factory ThemeSettingsEntity.defaults() => const ThemeSettingsEntity(
        themeName: AppConstants.defaultTheme,
      );

  ThemeSettingsEntity copyWith({
    String? themeName,
    Map<String, int>? customColors,
    bool clearCustomColors = false,
  }) =>
      ThemeSettingsEntity(
        themeName: themeName ?? this.themeName,
        customColors:
            clearCustomColors ? null : customColors ?? this.customColors,
      );

  Map<String, dynamic> toJson() => {
        'themeName': themeName,
        if (customColors != null) 'customColors': customColors,
      };

  factory ThemeSettingsEntity.fromJson(Map<String, dynamic> json) =>
      ThemeSettingsEntity(
        themeName: json['themeName'] as String? ?? AppConstants.defaultTheme,
        customColors: (json['customColors'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ),
      );

  @override
  List<Object?> get props => [themeName, customColors];
}

/// Storage-related settings (output folder, naming, structure).
class StorageSettingsEntity extends Equatable {
  const StorageSettingsEntity({
    required this.namingTemplate,
    required this.folderStructure,
    required this.keepOriginal,
    this.outputFolderPath,
  });

  /// Output filename template. Placeholders: {name}, {ext}, {date}, {time}.
  /// Example: '{name}_clean' -> 'photo_clean.jpg'
  final String namingTemplate;

  /// Output folder structure: 'flat' (all files in one folder) or
  /// 'nested' (preserve original directory structure).
  final String folderStructure;

  /// Whether to keep original files after processing (default: true).
  final bool keepOriginal;

  /// Persisted output folder path (SAF URI or filesystem path).
  final String? outputFolderPath;

  factory StorageSettingsEntity.defaults() => const StorageSettingsEntity(
        namingTemplate: AppConstants.defaultNamingTemplate,
        folderStructure: AppConstants.defaultFolderStructure,
        keepOriginal: AppConstants.defaultKeepOriginal,
      );

  StorageSettingsEntity copyWith({
    String? namingTemplate,
    String? folderStructure,
    bool? keepOriginal,
    String? outputFolderPath,
    bool clearOutputFolderPath = false,
  }) =>
      StorageSettingsEntity(
        namingTemplate: namingTemplate ?? this.namingTemplate,
        folderStructure: folderStructure ?? this.folderStructure,
        keepOriginal: true,
        outputFolderPath: clearOutputFolderPath
            ? null
            : outputFolderPath ?? this.outputFolderPath,
      );

  Map<String, dynamic> toJson() => {
        'namingTemplate': namingTemplate,
        'folderStructure': folderStructure,
        'keepOriginal': keepOriginal,
        if (outputFolderPath != null) 'outputFolderPath': outputFolderPath,
      };

  factory StorageSettingsEntity.fromJson(Map<String, dynamic> json) =>
      StorageSettingsEntity(
        namingTemplate: json['namingTemplate'] as String? ??
            AppConstants.defaultNamingTemplate,
        folderStructure: json['folderStructure'] as String? ??
            AppConstants.defaultFolderStructure,
        // Original deletion is unsupported. Keep accepting the legacy field,
        // but never hydrate an unsafe value into application state.
        keepOriginal: true,
        outputFolderPath: json['outputFolderPath'] as String?,
      );

  @override
  List<Object?> get props =>
      [namingTemplate, folderStructure, keepOriginal, outputFolderPath];
}

/// Processing-related settings (quality, concurrency, confirmations).
class ProcessingSettingsEntity extends Equatable {
  const ProcessingSettingsEntity({
    required this.jpegQuality,
    required this.concurrentFiles,
    required this.autoConfirm,
  });

  /// JPEG output quality when re-encoding (70-100). Only used if format
  /// requires re-encoding (e.g., WebP to JPEG fallback). Default 95.
  final int jpegQuality;

  /// Maximum number of files processed concurrently (1-8). Default 4.
  final int concurrentFiles;

  /// Skip per-file confirmation dialogs (default: false).
  final bool autoConfirm;

  factory ProcessingSettingsEntity.defaults() => const ProcessingSettingsEntity(
        jpegQuality: AppConstants.defaultJpegQuality,
        concurrentFiles: AppConstants.maxConcurrentFiles,
        autoConfirm: AppConstants.defaultAutoConfirm,
      );

  ProcessingSettingsEntity copyWith({
    int? jpegQuality,
    int? concurrentFiles,
    bool? autoConfirm,
  }) =>
      ProcessingSettingsEntity(
        jpegQuality: jpegQuality ?? this.jpegQuality,
        concurrentFiles: concurrentFiles ?? this.concurrentFiles,
        autoConfirm: autoConfirm ?? this.autoConfirm,
      );

  Map<String, dynamic> toJson() => {
        'jpegQuality': jpegQuality,
        'concurrentFiles': concurrentFiles,
        'autoConfirm': autoConfirm,
      };

  factory ProcessingSettingsEntity.fromJson(Map<String, dynamic> json) =>
      ProcessingSettingsEntity(
        jpegQuality:
            json['jpegQuality'] as int? ?? AppConstants.defaultJpegQuality,
        concurrentFiles:
            json['concurrentFiles'] as int? ?? AppConstants.maxConcurrentFiles,
        autoConfirm:
            json['autoConfirm'] as bool? ?? AppConstants.defaultAutoConfirm,
      );

  @override
  List<Object?> get props => [jpegQuality, concurrentFiles, autoConfirm];
}
