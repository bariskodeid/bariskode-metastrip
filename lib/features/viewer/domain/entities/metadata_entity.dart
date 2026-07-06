import 'package:equatable/equatable.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

class MetadataEntity extends Equatable {
  const MetadataEntity({required this.fields});

  final List<MetadataFieldEntity> fields;

  Map<String, List<MetadataFieldEntity>> get fieldsBySection {
    final grouped = <String, List<MetadataFieldEntity>>{};
    for (final field in fields) {
      grouped.putIfAbsent(field.section, () => []).add(field);
    }
    return grouped;
  }

  @override
  List<Object?> get props => [fields];
}
