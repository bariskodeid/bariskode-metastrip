import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:metastrip/core/constants/app_constants.dart';

/// Upper bound for the accumulated declared uncompressed size of the entries
/// in a zip archive that [repackZipWithoutEntries] is willing to re-encode.
///
/// The limit is checked against the sizes declared in the zip headers, so a
/// zip bomb can be rejected without decompressing anything. The same cap also
/// bounds the accumulated real content once entries are decompressed, catching
/// archives that understate their sizes.
const int maxRepackTotalSize = 256 * 1024 * 1024; // 256 MB

/// Upper bound for the number of entries in a zip archive that
/// [repackZipWithoutEntries] is willing to re-encode.
const int maxRepackEntryCount = 2000;

/// Upper bound for the decompressed size of a single entry, applied both to
/// the declared header size and to the real content after decompression.
const int maxRepackEntrySize = AppConstants.maxZipEntryDecompressBytes;

/// Separators accepted when classifying entry names (zip spec uses `/`, but
/// hostile archives can smuggle `\`).
final RegExp _pathSeparators = RegExp(r'[/\\]');

/// A single-letter Windows drive prefix such as `C:`.
final RegExp _drivePrefix = RegExp(r'^[A-Za-z]:');

/// Re-encodes [bytes] as a zip archive without the entries whose normalized
/// names match a path in [skipPaths].
///
/// Matching is case-sensitive and uses the same normalized-suffix rule as the
/// viewer extractors: an entry is removed when its [normalizeEntryPath] result
/// equals one of the [skipPaths] entries or ends with `/` plus that path. This
/// guarantees that every entry whose metadata the viewer can display (even at
/// a non-root location such as `a/docProps/core.xml`) is also stripped.
///
/// Security guards:
/// - Entries whose names are empty, absolute (`/`, `\` or a drive prefix like
///   `C:`) or contain a `..` path segment are dropped instead of being copied
///   to the output; a malicious entry never causes a throw, it is simply
///   omitted.
/// - An archive whose declared uncompressed size totals more than
///   [maxRepackTotalSize] or that holds more than [maxRepackEntryCount]
///   entries is rejected with a [FormatException] before any entry content is
///   decompressed, defending against zip bombs.
/// - Per-entry protection caps the decompressed size at [maxRepackEntrySize]:
///   the declared header size is checked first (so a bomb entry is rejected
///   without decompression) and the real content is re-checked after
///   decompression for archives that understate their sizes. The accumulated
///   real content also cannot exceed [maxRepackTotalSize].
///
/// Kept entries keep their content verbatim and their `isFile`/directory
/// flags, but the container is re-encoded: the result is a valid zip with the
/// same contents, not a byte-identical copy of [bytes].
///
/// Throws [FormatException] when [bytes] is not a valid zip archive, when the
/// archive is too large to repack, or when every entry is filtered out.
Uint8List repackZipWithoutEntries(
  Uint8List bytes, {
  required Set<String> skipPaths,
}) {
  final Archive source;
  try {
    source = ZipDecoder().decodeBytes(bytes, verify: false);
  } catch (_) {
    throw const FormatException('Invalid zip archive');
  }
  _guardAgainstZipBomb(source);

  final output = Archive();
  var keptCount = 0;
  var totalActualSize = 0;
  for (final entry in source.files) {
    final name = normalizeEntryPath(entry.name);
    if (!_isSafeEntryName(name)) continue;
    if (_matchesAnySkipPath(skipPaths, name)) continue;
    final rebuilt = _rebuildEntry(entry);
    if (rebuilt.isFile) {
      totalActualSize += (rebuilt.content as List<int>).length;
      if (totalActualSize > maxRepackTotalSize) {
        throw const FormatException('Archive too large to repack');
      }
    }
    output.addFile(rebuilt);
    keptCount++;
  }
  if (keptCount == 0) {
    throw const FormatException('Archive has no entries');
  }

  return Uint8List.fromList(ZipEncoder().encode(output)!);
}

/// Returns whether [bytes] is a zip archive that contains an entry whose
/// normalized name matches [entryPath].
///
/// Matching follows the viewer extractor rule: an entry counts as containing
/// [entryPath] when its normalized name equals [entryPath] or ends with
/// `/` plus [entryPath], so metadata hidden at a non-root location (for
/// example `a/docProps/core.xml`) is still detected. Only the headers are
/// inspected; entry content is never decompressed. Throws [FormatException]
/// when [bytes] is not a valid zip archive.
bool zipArchiveContainsEntry(Uint8List bytes, String entryPath) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    for (final file in archive.files) {
      if (_matchesEntryPath(normalizeEntryPath(file.name), entryPath)) {
        return true;
      }
    }
    return false;
  } catch (_) {
    throw const FormatException('Invalid zip archive');
  }
}

/// Rejects archives whose declared uncompressed size or entry count exceeds
/// the repack limits, before any content is decompressed.
void _guardAgainstZipBomb(Archive archive) {
  var totalDeclaredSize = 0;
  for (final entry in archive.files) {
    totalDeclaredSize += entry.size;
  }
  if (totalDeclaredSize > maxRepackTotalSize ||
      archive.files.length > maxRepackEntryCount) {
    throw const FormatException('Archive too large to repack');
  }
}

/// Returns whether [name] can be copied into an output archive safely.
///
/// Empty names, absolute paths (`/`, `\`, `C:`) and paths containing a `..`
/// segment could escape the container on extraction and are rejected.
bool _isSafeEntryName(String name) {
  if (name.isEmpty) return false;
  if (name.startsWith('/') || name.startsWith('\\')) return false;
  if (_drivePrefix.hasMatch(name)) return false;
  return !name.split(_pathSeparators).contains('..');
}

/// Normalizes a zip entry path into the canonical form shared by the viewer
/// extractors and the remover strippers.
///
/// Hostile or careless packers can write entry names with mixed separators
/// (`docProps\core.xml`), repeated slashes (`docProps//core.xml`) and dot
/// segments (`a/./docProps/core.xml`, `././docProps/core.xml`). Both sides of
/// the metadata pipeline must agree on the same canonical text so that every
/// entry whose metadata the viewer displays is also one the stripper removes.
///
/// The result:
/// - uses only `/` separators (`\` is converted),
/// - collapses repeated slashes into a single `/`,
/// - drops every `.` path segment (`./`, `a/./b`, `././`),
/// - never begins with `./`.
///
/// `..` segments are deliberately left untouched; path traversal is handled by
/// [_isSafeEntryName], which rejects such entries instead of resolving them.
String normalizeEntryPath(String name) {
  var normalized = name.replaceAll('\\', '/');
  normalized = normalized.replaceAll(RegExp(r'/+'), '/');
  final kept = <String>[];
  for (final segment in normalized.split('/')) {
    if (segment == '.') continue;
    kept.add(segment);
  }
  normalized = kept.join('/');
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}

/// Returns whether the normalized entry name [normalizedName] matches one of
/// the canonical paths in [skipPaths].
///
/// An entry matches when its name equals a skip path or ends with `/` plus a
/// skip path, mirroring the `_findEntry` suffix lookup of the viewer
/// extractors. The skip paths themselves are canonical targets and are not
/// normalized again.
bool _matchesAnySkipPath(Set<String> skipPaths, String normalizedName) {
  if (skipPaths.contains(normalizedName)) return true;
  return skipPaths.any((path) => normalizedName.endsWith('/$path'));
}

/// Returns whether the normalized entry name [normalizedName] matches the
/// canonical lookup target [entryPath].
///
/// Matching is exact or by `/`-suffixed suffix, the same rule used by the
/// viewer extractors' `_findEntry`.
bool _matchesEntryPath(String normalizedName, String entryPath) {
  if (normalizedName == entryPath) return true;
  return normalizedName.endsWith('/$entryPath');
}

/// Rebuilds [entry] as a fresh, in-memory [ArchiveFile].
///
/// Decompresses lazy entries via [ArchiveFile.content] so the rebuilt file
/// carries the real bytes; directory flags, modification time and Unix mode
/// are preserved. Declared sizes are discarded in favor of the actual content
/// length so the re-encoded headers stay consistent.
ArchiveFile _rebuildEntry(ArchiveFile entry) {
  if (!entry.isFile) {
    return ArchiveFile(entry.name, 0, null)..isFile = false;
  }
  if (entry.size > maxRepackEntrySize) {
    throw const FormatException('Archive too large to repack');
  }
  final List<int> content;
  try {
    content = entry.content as List<int>;
  } catch (_) {
    throw const FormatException('Invalid zip entry');
  }
  if (content.length > maxRepackEntrySize) {
    throw const FormatException('Archive too large to repack');
  }
  final rebuilt = ArchiveFile(entry.name, 0, content)..isFile = true;
  rebuilt.lastModTime = entry.lastModTime;
  rebuilt.mode = entry.mode;
  return rebuilt;
}
