import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

enum StripPolicyMode { supportedCleanup, selective }

/// Explicit cleanup intent passed through the remover pipeline.
class StripPolicy extends Equatable {
  const StripPolicy.supportedCleanup()
      : mode = StripPolicyMode.supportedCleanup,
        _selectedFieldIds = const <MetadataFieldId>{};

  StripPolicy.selective({required Set<MetadataFieldId> fieldIds})
      : mode = StripPolicyMode.selective,
        _selectedFieldIds = Set.unmodifiable(fieldIds) {
    if (fieldIds.isEmpty) {
      throw ArgumentError.value(fieldIds, 'fieldIds', 'Must not be empty');
    }
  }

  final StripPolicyMode mode;
  final Set<MetadataFieldId> _selectedFieldIds;

  Set<MetadataFieldId> get selectedFieldIds =>
      UnmodifiableSetView(_selectedFieldIds);

  @override
  List<Object?> get props => [mode, _selectedFieldIds];
}
