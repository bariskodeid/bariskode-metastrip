import 'package:equatable/equatable.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

class MetadataFieldEntity extends Equatable {
  const MetadataFieldEntity({
    required this.section,
    required this.label,
    required this.value,
    this.id,
    this.isPrivacySensitive = false,
  });

  final String section;
  final String label;
  final String value;
  final MetadataFieldId? id;
  final bool isPrivacySensitive;

  @override
  List<Object?> get props => [section, label, value, id, isPrivacySensitive];
}
