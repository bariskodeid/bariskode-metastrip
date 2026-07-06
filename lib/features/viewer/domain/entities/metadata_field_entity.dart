import 'package:equatable/equatable.dart';

class MetadataFieldEntity extends Equatable {
  const MetadataFieldEntity({
    required this.section,
    required this.label,
    required this.value,
    this.isPrivacySensitive = false,
  });

  final String section;
  final String label;
  final String value;
  final bool isPrivacySensitive;

  @override
  List<Object?> get props => [section, label, value, isPrivacySensitive];
}
