import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

/// Stable identities for the WAV `LIST INFO` fields supported by selective
/// cleanup. AIFF fields deliberately have no entries here.
typedef RiffInfoDescriptor = ({String code, String label});

const Map<MetadataFieldId, RiffInfoDescriptor> wavInfoDescriptors = {
  MetadataFieldId.wavInfoInam: (code: 'INAM', label: 'Title'),
  MetadataFieldId.wavInfoIcop: (code: 'ICOP', label: 'Copyright'),
  MetadataFieldId.wavInfoIcrd: (code: 'ICRD', label: 'Date'),
  MetadataFieldId.wavInfoIgnr: (code: 'IGNR', label: 'Genre'),
  MetadataFieldId.wavInfoIart: (code: 'IART', label: 'Artist'),
  MetadataFieldId.wavInfoIcmt: (code: 'ICMT', label: 'Comment'),
  MetadataFieldId.wavInfoIsft: (code: 'ISFT', label: 'Software'),
  MetadataFieldId.wavInfoIsbj: (code: 'ISBJ', label: 'Subject'),
  MetadataFieldId.wavInfoIeng: (code: 'IENG', label: 'Engineer'),
  MetadataFieldId.wavInfoIkey: (code: 'IKEY', label: 'Keywords'),
  // Intentional nonstandard spelling: the physical RIFF FourCC is `IRL `.
  // The extractor and legacy label API both use this product contract.
  MetadataFieldId.wavInfoIrl: (code: 'IRL ', label: 'URL'),
};
