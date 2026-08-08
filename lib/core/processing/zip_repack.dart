import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Upper bound for the accumulated declared uncompressed size of the entries
/// in a zip archive that [repackZipWithoutEntries] is willing to re-encode.
///
/// The limit is checked against the sizes declared in the zip headers, so a
/// zip bomb can be rejected without decompressing anything. The same cap also
/// bounds the accumulated real content once entries are decompressed, catching
/// archives that understate their sizes.
const int maxRepackTotalSize = 32 * 1024 * 1024; // 32 MB

/// Upper bound for the number of entries in a zip archive that
/// [repackZipWithoutEntries] is willing to re-encode.
const int maxRepackEntryCount = 2000;

/// Upper bound for the decompressed size of a single entry, applied both to
/// the declared header size and to the real content after decompression.
const int maxRepackEntrySize = maxRepackTotalSize;

/// Small package descriptor entries are parsed before their payload is read.
const int maxPackageDescriptorSize = 256 * 1024;

/// Central-directory metadata needed by format-specific package validators.
class ZipPreflightEntry {
  const ZipPreflightEntry({
    required this.name,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.localExtraLength,
  });

  final String name;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final int localExtraLength;
}

/// Separators accepted when classifying entry names (zip spec uses `/`, but
/// hostile archives can smuggle `\`).
final RegExp _pathSeparators = RegExp(r'[/\\]');

/// A single-letter Windows drive prefix such as `C:`.
final RegExp _drivePrefix = RegExp(r'^[A-Za-z]:');

/// Re-encodes [bytes] as a zip archive without the entries whose normalized
/// names match a path in [skipPaths].
///
/// Matching is case-sensitive. By default, an entry is removed when its
/// normalized path equals or ends with a path in [skipPaths]. When
/// [exactSkipPaths] is true, only exact normalized paths are removed.
/// [replacements] rebuilds exact normalized paths with supplied bytes, and
/// [storedFirstPath] moves one retained entry first and stores it uncompressed.
///
/// Security guards:
/// - Entries whose names are empty, absolute (`/`, `\` or a drive prefix like
///   `C:`), contain a `..` path segment, or collide after normalization cause
///   the archive to be rejected before payload decoding.
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
  String? storedFirstPath,
  Map<String, Uint8List> replacements = const {},
  bool exactSkipPaths = false,
}) {
  final descriptors = preflightZip(bytes);
  _validateRepackPolicy(descriptors);
  final source = decodeGuardedZip(bytes);

  final output = Archive();
  var keptCount = 0;
  var totalActualSize = 0;
  final entries = source.files.toList();
  if (storedFirstPath != null) {
    entries.sort((first, second) {
      final firstMatch = normalizeEntryPath(first.name) == storedFirstPath;
      final secondMatch = normalizeEntryPath(second.name) == storedFirstPath;
      return firstMatch == secondMatch ? 0 : (firstMatch ? -1 : 1);
    });
  }
  for (final entry in entries) {
    final name = normalizeEntryPath(entry.name);
    if (!_isSafeEntryName(name)) continue;
    if (exactSkipPaths
        ? skipPaths.contains(name)
        : _matchesAnySkipPath(skipPaths, name)) {
      continue;
    }
    final replacement = replacements[name];
    final rebuilt = replacement == null
        ? _rebuildEntry(entry)
        : ArchiveFile(name, replacement.length, replacement);
    if (normalizeEntryPath(rebuilt.name) == storedFirstPath) {
      rebuilt.compress = false;
    }
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

/// Decodes [bytes] after structural ZIP validation.
Archive decodeGuardedZip(Uint8List bytes) {
  preflightZip(bytes);
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes, verify: false);
  } catch (_) {
    throw const FormatException('Invalid zip archive');
  }
  return archive;
}

/// Validates the ZIP structure and security policy without reading any entry
/// payload. This must run before [ZipDecoder] to prevent decompression work.
List<ZipPreflightEntry> preflightZip(Uint8List bytes) {
  final eocd = _findEocd(bytes);
  final disk = _u16(bytes, eocd + 4);
  final directoryDisk = _u16(bytes, eocd + 6);
  final diskCount = _u16(bytes, eocd + 8);
  final entryCount = _u16(bytes, eocd + 10);
  final directorySize = _u32(bytes, eocd + 12);
  final directoryOffset = _u32(bytes, eocd + 16);
  if (disk != 0 ||
      directoryDisk != 0 ||
      diskCount != entryCount ||
      diskCount == 0xffff ||
      directorySize == 0xffffffff ||
      directoryOffset == 0xffffffff) {
    throw const FormatException('Unsupported ZIP structure');
  }
  if (entryCount > maxRepackEntryCount ||
      directoryOffset > bytes.length ||
      directorySize > bytes.length - directoryOffset ||
      directoryOffset + directorySize > eocd) {
    throw const FormatException('Archive too large to repack');
  }

  final entries = <ZipPreflightEntry>[];
  final localRanges = <({int start, int end})>[];
  final normalizedNames = <String>{};
  var cursor = directoryOffset;
  for (var i = 0; i < entryCount; i++) {
    if (cursor + 46 > eocd || _u32(bytes, cursor) != 0x02014b50) {
      throw const FormatException('Invalid zip archive');
    }
    final madeBy = _u16(bytes, cursor + 4);
    final flags = _u16(bytes, cursor + 8);
    final method = _u16(bytes, cursor + 10);
    final crc32 = _u32(bytes, cursor + 16);
    final compressed = _u32(bytes, cursor + 20);
    final uncompressed = _u32(bytes, cursor + 24);
    final nameLength = _u16(bytes, cursor + 28);
    final extraLength = _u16(bytes, cursor + 30);
    final commentLength = _u16(bytes, cursor + 32);
    final startDisk = _u16(bytes, cursor + 34);
    final attributes = _u32(bytes, cursor + 38);
    final localOffset = _u32(bytes, cursor + 42);
    final recordLength = 46 + nameLength + extraLength + commentLength;
    if (recordLength > eocd - cursor) {
      throw const FormatException('Invalid zip archive');
    }
    final nameBytes = bytes.sublist(cursor + 46, cursor + 46 + nameLength);
    final String name;
    try {
      name = ((flags & 0x800) != 0)
          ? utf8.decode(nameBytes, allowMalformed: false)
          : String.fromCharCodes(nameBytes);
    } catch (_) {
      throw const FormatException('Invalid zip archive');
    }
    final normalizedName = normalizeEntryPath(name);
    if (!normalizedNames.add(normalizedName)) {
      throw const FormatException('Duplicate zip entry');
    }
    if (startDisk != 0 ||
        (flags & 0x1) != 0 ||
        method != 0 && method != 8 ||
        method == 0 && compressed != uncompressed ||
        compressed == 0xffffffff ||
        uncompressed == 0xffffffff ||
        localOffset == 0xffffffff ||
        _isUnixSymlink(madeBy, attributes) ||
        !_isSafeEntryName(normalizedName)) {
      throw const FormatException('Unsupported or unsafe zip entry');
    }
    final local = _validateLocalHeader(
      bytes,
      localOffset,
      nameBytes,
      flags,
      method,
      crc32,
      compressed,
      uncompressed,
      directoryOffset,
    );
    localRanges.add((start: local.start, end: local.end));
    entries.add(ZipPreflightEntry(
      name: name,
      compressionMethod: method,
      compressedSize: compressed,
      uncompressedSize: uncompressed,
      localHeaderOffset: localOffset,
      localExtraLength: local.extraLength,
    ));
    cursor += recordLength;
  }
  if (cursor != directoryOffset + directorySize) {
    throw const FormatException('Invalid zip archive');
  }
  localRanges.sort((first, second) => first.start.compareTo(second.start));
  for (var i = 1; i < localRanges.length; i++) {
    if (localRanges[i].start < localRanges[i - 1].end) {
      throw const FormatException('Invalid zip archive');
    }
  }
  return entries;
}

int _findEocd(Uint8List bytes) {
  final start = bytes.length > 65557 ? bytes.length - 65557 : 0;
  for (var i = bytes.length - 22; i >= start; i--) {
    if (_u32(bytes, i) != 0x06054b50) continue;
    final commentLength = _u16(bytes, i + 20);
    if (i + 22 + commentLength == bytes.length) return i;
  }
  throw const FormatException('Invalid zip archive');
}

bool _isUnixSymlink(int madeBy, int attributes) =>
    madeBy >> 8 == 3 && (attributes >> 16) & 0xf000 == 0xa000;

({int start, int end, int extraLength}) _validateLocalHeader(
  Uint8List bytes,
  int offset,
  List<int> nameBytes,
  int centralFlags,
  int centralMethod,
  int centralCrc32,
  int compressed,
  int uncompressed,
  int directoryOffset,
) {
  if (offset < 0 ||
      offset + 30 > bytes.length ||
      _u32(bytes, offset) != 0x04034b50) {
    throw const FormatException('Invalid zip archive');
  }
  final flags = _u16(bytes, offset + 6);
  final method = _u16(bytes, offset + 8);
  final nameLength = _u16(bytes, offset + 26);
  final extraLength = _u16(bytes, offset + 28);
  final dataStart = offset + 30 + nameLength + extraLength;
  if (flags != centralFlags ||
      method != centralMethod ||
      dataStart > directoryOffset ||
      compressed > directoryOffset - dataStart ||
      !_equalBytes(
        bytes.sublist(offset + 30, offset + 30 + nameLength),
        nameBytes,
      )) {
    throw const FormatException('Invalid zip archive');
  }
  var recordEnd = dataStart + compressed;
  if ((flags & 0x8) == 0) {
    if (_u32(bytes, offset + 14) != centralCrc32 ||
        _u32(bytes, offset + 18) != compressed ||
        _u32(bytes, offset + 22) != uncompressed) {
      throw const FormatException('Invalid zip archive');
    }
  } else {
    final hasSignature = recordEnd + 4 <= directoryOffset &&
        _u32(bytes, recordEnd) == 0x08074b50;
    final descriptor = recordEnd + (hasSignature ? 4 : 0);
    if (descriptor + 12 > directoryOffset ||
        _u32(bytes, descriptor) != centralCrc32 ||
        _u32(bytes, descriptor + 4) != compressed ||
        _u32(bytes, descriptor + 8) != uncompressed) {
      throw const FormatException('Invalid zip archive');
    }
    recordEnd = descriptor + 12;
  }
  return (start: offset, end: recordEnd, extraLength: extraLength);
}

bool _equalBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

int _u16(List<int> bytes, int offset) {
  if (offset < 0 || offset + 2 > bytes.length) {
    throw const FormatException('Invalid zip archive');
  }
  return bytes[offset] | bytes[offset + 1] << 8;
}

int _u32(List<int> bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    throw const FormatException('Invalid zip archive');
  }
  return bytes[offset] |
      bytes[offset + 1] << 8 |
      bytes[offset + 2] << 16 |
      bytes[offset + 3] << 24;
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
    final archive = decodeGuardedZip(bytes);
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

/// Applies the in-memory repacker's payload budget before decompression.
void _validateRepackPolicy(List<ZipPreflightEntry> entries) {
  var totalDeclaredSize = 0;
  for (final entry in entries) {
    if (entry.uncompressedSize > maxRepackEntrySize ||
        totalDeclaredSize > maxRepackTotalSize - entry.uncompressedSize) {
      throw const FormatException('Archive too large to repack');
    }
    totalDeclaredSize += entry.uncompressedSize;
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
  final content = decodeZipEntrySafely(entry, maxBytes: maxRepackEntrySize);
  if (content == null) {
    throw const FormatException('Archive too large to repack');
  }
  final rebuilt = ArchiveFile(entry.name, 0, content)..isFile = true;
  rebuilt.lastModTime = entry.lastModTime;
  rebuilt.mode = entry.mode;
  rebuilt.compress = entry.compress;
  return rebuilt;
}

/// Decompresses an entry with a hard output cap before materializing its bytes.
Uint8List? decodeZipEntrySafely(
  ArchiveFile entry, {
  required int maxBytes,
}) {
  if (entry.size > maxBytes) return null;
  final output = _BoundedOutputStream(maxBytes);
  try {
    entry.clear();
    entry.decompress(output);
    final content = Uint8List.fromList(output.getBytes());
    if (content.length != entry.size ||
        entry.crc32 != null && getCrc32(content) != entry.crc32) {
      throw const FormatException('Invalid zip entry');
    }
    return content;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Invalid zip entry');
  }
}

class _BoundedOutputStream extends OutputStream {
  _BoundedOutputStream(this.maxBytes) : super(size: 1024);

  final int maxBytes;

  void _check(int additionalBytes) {
    if (additionalBytes < 0 || length > maxBytes - additionalBytes) {
      throw const FormatException(
          'Decompressed archive entry exceeds size cap');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, [int? len]) {
    _check(len ?? bytes.length);
    super.writeBytes(bytes, len);
  }

  @override
  void writeInputStream(InputStreamBase stream) {
    _check(stream.length);
    super.writeInputStream(stream);
  }
}
