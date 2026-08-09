import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

/// Canonical namespaces used by the bounded ODF selective-removal scope.
const odfDcNamespace = 'http://purl.org/dc/elements/1.1/';
const odfMetaNamespace = 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0';

typedef OdfPropertyDescriptor = ({String localName, String namespace});

/// Exact identities for the ten properties already extracted by the Viewer.
/// Custom, user-defined, and other ODF metadata properties are intentionally
/// not represented here.
const Map<MetadataFieldId, OdfPropertyDescriptor> odfPropertyDescriptors = {
  MetadataFieldId.odfTitle: (localName: 'title', namespace: odfDcNamespace),
  MetadataFieldId.odfAuthor: (localName: 'creator', namespace: odfDcNamespace),
  MetadataFieldId.odfSubject: (
    localName: 'subject',
    namespace: odfDcNamespace,
  ),
  MetadataFieldId.odfDescription: (
    localName: 'description',
    namespace: odfDcNamespace,
  ),
  MetadataFieldId.odfKeywords: (
    localName: 'keyword',
    namespace: odfMetaNamespace,
  ),
  MetadataFieldId.odfGenerator: (
    localName: 'generator',
    namespace: odfMetaNamespace,
  ),
  MetadataFieldId.odfInitialCreator: (
    localName: 'initial-creator',
    namespace: odfMetaNamespace,
  ),
  MetadataFieldId.odfCreationDate: (
    localName: 'creation-date',
    namespace: odfMetaNamespace,
  ),
  MetadataFieldId.odfPrintDate: (
    localName: 'print-date',
    namespace: odfMetaNamespace,
  ),
  MetadataFieldId.odfModificationDate: (
    localName: 'modification-date',
    namespace: odfMetaNamespace,
  ),
};
