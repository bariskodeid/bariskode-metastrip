import 'package:equatable/equatable.dart';
import 'package:metastrip/features/settings/domain/entities/settings_entity.dart';

enum SettingsStatus { initial, loading, loaded, saving, error }

/// State for SettingsCubit.
class SettingsState extends Equatable {
  const SettingsState({
    required this.settings,
    required this.status,
    this.errorMessage,
    this.cacheSizeBytes = 0,
  });

  factory SettingsState.initial() => const SettingsState(
        settings: null,
        status: SettingsStatus.initial,
      );

  final SettingsEntity? settings;
  final SettingsStatus status;
  final String? errorMessage;
  final int cacheSizeBytes;

  SettingsState copyWith({
    SettingsEntity? settings,
    SettingsStatus? status,
    String? errorMessage,
    bool clearError = false,
    int? cacheSizeBytes,
  }) => SettingsState(
        settings: settings ?? this.settings,
        status: status ?? this.status,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      );

  @override
  List<Object?> get props => [settings, status, errorMessage, cacheSizeBytes];
}