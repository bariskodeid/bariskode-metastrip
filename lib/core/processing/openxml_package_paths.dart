import 'package:metastrip/core/processing/zip_repack.dart';

/// Namespace of OPC `_rels` relationship parts.
const openXmlRelationshipsNamespace =
    'http://schemas.openxmlformats.org/package/2006/relationships';

/// Relationship `Type` URIs for package property parts, mapped to
/// `core`, `extended` or `custom`.
const openXmlPropertyRelationshipKinds = {
  'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties':
      'core',
  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties':
      'extended',
  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties':
      'custom',
  'http://purl.oclc.org/ooxml/package/relationships/metadata/core-properties':
      'core',
  'http://purl.oclc.org/ooxml/officeDocument/relationships/extended-properties':
      'extended',
  'http://purl.oclc.org/ooxml/officeDocument/relationships/custom-properties':
      'custom',
};

/// Resolves a relationship or part-name [target] to a normalized, root-relative
/// package path.
///
/// Returns `null` for empty, backslash, query, fragment, encoded-separator,
/// absolute-URI or root-escaping (`..`) targets.
String? resolveOpenXmlPackageTarget(String target) {
  if (target.isEmpty ||
      target.contains('\\') ||
      target.contains('?') ||
      target.contains('#') ||
      RegExp('%(?:2f|5c)', caseSensitive: false).hasMatch(target)) {
    return null;
  }
  final uri = Uri.tryParse(target);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final segments = <String>[];
  for (final segment in target.replaceFirst(RegExp('^/+'), '').split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) return null;
      segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  final path = normalizeEntryPath(segments.join('/'));
  return path.isEmpty ? null : path;
}
