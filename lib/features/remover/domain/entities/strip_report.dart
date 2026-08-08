import 'package:equatable/equatable.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

/// Verification level for the cleanup facts in a [StripReport].
enum StripVerificationOutcome {
  verified,
  attemptedUnverified,
  notAttempted,
}

/// Cleanup facts that do not contain metadata values.
class StripReport extends Equatable {
  StripReport({
    Set<MetadataFieldId> requestedFieldIds = const <MetadataFieldId>{},
    Set<MetadataFieldId> removedFieldIds = const <MetadataFieldId>{},
    Set<MetadataFieldId> alreadyAbsentFieldIds = const <MetadataFieldId>{},
    Set<MetadataFieldId> unsupportedFieldIds = const <MetadataFieldId>{},
    List<String> warnings = const <String>[],
    StripVerificationOutcome? verificationOutcome,
    this.outputValidated = false,
    this.reencoded = false,
  })  : requestedFieldIds = Set.unmodifiable(requestedFieldIds),
        removedFieldIds = Set.unmodifiable(removedFieldIds),
        alreadyAbsentFieldIds = Set.unmodifiable(alreadyAbsentFieldIds),
        unsupportedFieldIds = Set.unmodifiable(unsupportedFieldIds),
        warnings = List.unmodifiable(warnings),
        verificationOutcome = verificationOutcome ??
            (outputValidated
                ? StripVerificationOutcome.verified
                : StripVerificationOutcome.notAttempted) {
    if (outputValidated !=
        (this.verificationOutcome == StripVerificationOutcome.verified)) {
      throw ArgumentError(
        'outputValidated must be true exactly when verification is verified',
      );
    }
  }

  final Set<MetadataFieldId> requestedFieldIds;
  final Set<MetadataFieldId> removedFieldIds;
  final Set<MetadataFieldId> alreadyAbsentFieldIds;
  final Set<MetadataFieldId> unsupportedFieldIds;
  final List<String> warnings;
  final StripVerificationOutcome verificationOutcome;

  /// Whether the locally persisted output artifact was read back and valid.
  ///
  /// This is false for SAF output until device read-back support is available.
  final bool outputValidated;
  final bool reencoded;

  /// Snapshots report collections for data-layer results built at runtime.
  factory StripReport.snapshot({
    Iterable<MetadataFieldId> requestedFieldIds = const [],
    Iterable<MetadataFieldId> removedFieldIds = const [],
    Iterable<MetadataFieldId> alreadyAbsentFieldIds = const [],
    Iterable<MetadataFieldId> unsupportedFieldIds = const [],
    Iterable<String> warnings = const [],
    StripVerificationOutcome? verificationOutcome,
    bool outputValidated = false,
    bool reencoded = false,
  }) {
    return StripReport(
      requestedFieldIds: Set.of(requestedFieldIds),
      removedFieldIds: Set.of(removedFieldIds),
      alreadyAbsentFieldIds: Set.of(alreadyAbsentFieldIds),
      unsupportedFieldIds: Set.of(unsupportedFieldIds),
      warnings: List.of(warnings),
      verificationOutcome: verificationOutcome,
      outputValidated: outputValidated,
      reencoded: reencoded,
    );
  }

  @override
  List<Object?> get props => [
        requestedFieldIds,
        removedFieldIds,
        alreadyAbsentFieldIds,
        unsupportedFieldIds,
        warnings,
        verificationOutcome,
        outputValidated,
        reencoded,
      ];
}
