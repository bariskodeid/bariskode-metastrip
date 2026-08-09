import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

/// Standard namespaces used by selectively removable Open XML properties.
const openXmlCorePropertiesNamespace =
    'http://schemas.openxmlformats.org/package/2006/metadata/core-properties';
const openXmlDcNamespace = 'http://purl.org/dc/elements/1.1/';
const openXmlDctermsNamespace = 'http://purl.org/dc/terms/';
const openXmlExtendedPropertiesNamespace =
    'http://schemas.openxmlformats.org/officeDocument/2006/extended-properties';

/// Exact XML identity of an allowlisted Open XML property.
typedef OpenXmlPropertyDescriptor = ({
  String part,
  String localName,
  String namespace,
});

/// Exact property identities shared by Open XML extraction and removal.
const Map<MetadataFieldId, OpenXmlPropertyDescriptor>
    openXmlPropertyDescriptors = {
  MetadataFieldId.openXmlTitle: (
    part: 'core',
    localName: 'title',
    namespace: openXmlDcNamespace,
  ),
  MetadataFieldId.openXmlAuthor: (
    part: 'core',
    localName: 'creator',
    namespace: openXmlDcNamespace,
  ),
  MetadataFieldId.openXmlSubject: (
    part: 'core',
    localName: 'subject',
    namespace: openXmlDcNamespace,
  ),
  MetadataFieldId.openXmlKeywords: (
    part: 'core',
    localName: 'keywords',
    namespace: openXmlCorePropertiesNamespace,
  ),
  MetadataFieldId.openXmlDescription: (
    part: 'core',
    localName: 'description',
    namespace: openXmlDcNamespace,
  ),
  MetadataFieldId.openXmlCreated: (
    part: 'core',
    localName: 'created',
    namespace: openXmlDctermsNamespace,
  ),
  MetadataFieldId.openXmlModified: (
    part: 'core',
    localName: 'modified',
    namespace: openXmlDctermsNamespace,
  ),
  MetadataFieldId.openXmlLastModifiedBy: (
    part: 'core',
    localName: 'lastModifiedBy',
    namespace: openXmlCorePropertiesNamespace,
  ),
  MetadataFieldId.openXmlRevision: (
    part: 'core',
    localName: 'revision',
    namespace: openXmlCorePropertiesNamespace,
  ),
  MetadataFieldId.openXmlCategory: (
    part: 'core',
    localName: 'category',
    namespace: openXmlCorePropertiesNamespace,
  ),
  MetadataFieldId.openXmlContentStatus: (
    part: 'core',
    localName: 'contentStatus',
    namespace: openXmlCorePropertiesNamespace,
  ),
  MetadataFieldId.openXmlApplication: (
    part: 'app',
    localName: 'Application',
    namespace: openXmlExtendedPropertiesNamespace,
  ),
  MetadataFieldId.openXmlCompany: (
    part: 'app',
    localName: 'Company',
    namespace: openXmlExtendedPropertiesNamespace,
  ),
  MetadataFieldId.openXmlAppVersion: (
    part: 'app',
    localName: 'AppVersion',
    namespace: openXmlExtendedPropertiesNamespace,
  ),
  MetadataFieldId.openXmlTotalTime: (
    part: 'app',
    localName: 'TotalTime',
    namespace: openXmlExtendedPropertiesNamespace,
  ),
  MetadataFieldId.openXmlSlides: (
    part: 'app',
    localName: 'Slides',
    namespace: openXmlExtendedPropertiesNamespace,
  ),
};
