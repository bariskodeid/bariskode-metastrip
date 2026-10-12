@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/zip_repack.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/odf_stripper.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/openxml_stripper.dart';

/// Host-side execution of the ZIP-family memory stress matrix (Z01-Z05, Z10)
/// from `docs/DEVICE_AND_STRESS_TEST_PLAN.md` section 4.
///
/// The device lanes additionally cover Z06-Z09 (entry-count sweep, sequential
/// batches, cancellation, low-memory pressure), which need a real device.
/// Fixtures here are generated in memory so no large binaries are committed.
void main() {
  group('Z01/Z02 aggregate boundary completes', () {
    test('docx at 32 MiB minus 1 byte strips, reparses, keeps original',
        () async {
      final input = _docxBytes(maxRepackTotalSize - 1);
      expect(_declaredAggregate(input), maxRepackTotalSize - 1);

      final run = await _runPipeline(input, 'boundary_minus_one.docx');

      expect(run.outputBytes, isNotNull);
      _expectDocxReparses(run.outputBytes!);
      expect(run.originalUnchanged, isTrue);
    });

    test('docx at exactly 32 MiB strips, reparses, keeps original', () async {
      final input = _docxBytes(maxRepackTotalSize);
      expect(_declaredAggregate(input), maxRepackTotalSize);

      final run = await _runPipeline(input, 'boundary_exact.docx');

      expect(run.outputBytes, isNotNull);
      _expectDocxReparses(run.outputBytes!);
      expect(run.originalUnchanged, isTrue);
    });

    test('odt at 32 MiB minus 1 byte strips, reparses, keeps original',
        () async {
      final input = _odtBytes(maxRepackTotalSize - 1);
      expect(_declaredAggregate(input), maxRepackTotalSize - 1);

      final run = await _runPipeline(input, 'boundary_minus_one.odt');

      expect(run.outputBytes, isNotNull);
      _expectOdtReparses(run.outputBytes!);
      expect(run.originalUnchanged, isTrue);
    });

    test('odt at exactly 32 MiB strips, reparses, keeps original', () async {
      final input = _odtBytes(maxRepackTotalSize);
      expect(_declaredAggregate(input), maxRepackTotalSize);

      final run = await _runPipeline(input, 'boundary_exact.odt');

      expect(run.outputBytes, isNotNull);
      _expectOdtReparses(run.outputBytes!);
      expect(run.originalUnchanged, isTrue);
    });

    test('zip container cleanup at exactly 32 MiB stays canonical', () async {
      final input = _zipBytes(maxRepackTotalSize);
      expect(_declaredAggregate(input), maxRepackTotalSize);

      final run = await _runPipeline(input, 'boundary_exact.zip');

      expect(run.outputBytes, isNotNull);
      validateCanonicalZipMetadata(run.outputBytes!);
      expect(rewriteZipMetadata(run.outputBytes!), run.outputBytes);
      expect(run.originalUnchanged, isTrue);
    });
  });

  group('Z03 above the aggregate boundary fails closed', () {
    test('docx at 32 MiB plus 1 byte installs no output', () async {
      final input = _docxBytes(maxRepackTotalSize + 1);
      expect(_declaredAggregate(input), maxRepackTotalSize + 1);

      final run = await _runPipeline(input, 'boundary_plus_one.docx');

      expect(run.error, _rejectedBecause('Archive too large to repack'));
      expect(run.installedNames, isEmpty);
      expect(run.originalUnchanged, isTrue);
    });

    test('odt at 32 MiB plus 1 byte installs no output', () async {
      final input = _odtBytes(maxRepackTotalSize + 1);
      expect(_declaredAggregate(input), maxRepackTotalSize + 1);

      final run = await _runPipeline(input, 'boundary_plus_one.odt');

      expect(run.error, _rejectedBecause('Archive too large to repack'));
      expect(run.installedNames, isEmpty);
      expect(run.originalUnchanged, isTrue);
    });
  });

  group('Z04 malformed declared sizes fail closed', () {
    test('central size that disagrees with the local header is rejected',
        () async {
      final payload = Uint8List(4096);
      final input = _rawDocx([
        _rawStored('word/media/payload.bin', payload)
            .withCentralUncompressedSize(maxRepackTotalSize),
      ]);

      final run = await _runPipeline(input, 'mismatched_sizes.docx');

      expect(run.error, _rejectedBecause('Invalid office document'));
      expect(run.installedNames, isEmpty);
      expect(run.originalUnchanged, isTrue);
    });

    test('overstated size above the cap is rejected before decompression',
        () async {
      final payload = Uint8List(4096);
      final input = _rawDocx([
        _rawDeflated(
          'word/media/payload.bin',
          payload,
          declaredUncompressedSize: maxRepackTotalSize + 1,
        ),
      ]);

      final run = await _runPipeline(input, 'overstated_size.docx');

      expect(run.error, _rejectedBecause('Archive too large to repack'));
      expect(run.installedNames, isEmpty);
      expect(run.originalUnchanged, isTrue);
    });

    test('understated size with oversized real content is rejected', () async {
      final input = _rawDocx([
        _rawDeflated(
          'word/media/payload.bin',
          Uint8List(maxRepackTotalSize + 1024 * 1024),
          declaredUncompressedSize: 1024,
        ),
      ]);

      final run = await _runPipeline(input, 'understated_size.docx');

      expect(
        run.error,
        _rejectedBecause('Decompressed archive entry exceeds size cap'),
      );
      expect(run.installedNames, isEmpty);
      expect(run.originalUnchanged, isTrue);
    });
  });

  group('Z05 high compression ratio is bounded', () {
    test('expansion below the cap completes and reparses', () async {
      final payload = Uint8List(1024 * 1024);
      final input = _rawDocx([_rawDeflated('word/media/payload.bin', payload)]);
      expect(input.length, lessThan(64 * 1024));
      expect(
        _declaredAggregate(input),
        greaterThanOrEqualTo(payload.length),
      );

      final run = await _runPipeline(input, 'ratio_below_cap.docx');

      expect(run.outputBytes, isNotNull);
      _expectDocxReparses(run.outputBytes!);
      expect(run.originalUnchanged, isTrue);
    });

    test('declared expansion above the cap is rejected without decompressing',
        () async {
      final payload = Uint8List(1024);
      final input = _rawDocx([
        _rawDeflated(
          'word/media/payload.bin',
          payload,
          declaredUncompressedSize: 64 * 1024 * 1024,
        ),
      ]);
      expect(input.length, lessThan(64 * 1024));

      final run = await _runPipeline(input, 'ratio_above_cap.docx');

      expect(run.error, _rejectedBecause('Archive too large to repack'));
      expect(run.installedNames, isEmpty);
      expect(run.originalUnchanged, isTrue);
    });
  });

  group('Z10 malformed structure fails closed', () {
    final cases = <String, ({Uint8List Function() build, String reason})>{
      'zip64 sentinel end record': (
        build: () =>
            _rawZip([_rawStored('a.txt', _ascii('payload'))], zip64: true),
        reason: 'Unsupported ZIP structure',
      ),
      'multi-disk end record': (
        build: () => _rawZip(
              [_rawStored('a.txt', _ascii('payload'))],
              diskNumber: 1,
              directoryDisk: 1,
            ),
        reason: 'Unsupported ZIP structure',
      ),
      'encrypted entry flag': (
        build: () => _rawZip([
              _rawStored('a.txt', _ascii('payload')).withFlags(0x1),
            ]),
        reason: 'Unsupported or unsafe zip entry',
      ),
      'duplicate normalized path': (
        build: () => _rawZip([
              _rawStored('a/b.txt', _ascii('one')),
              _rawStored('a//b.txt', _ascii('two')),
            ]),
        reason: 'Duplicate zip entry',
      ),
      'unsupported compression method': (
        build: () => _rawZip([
              _rawStored('a.txt', _ascii('payload')).withMethod(12),
            ]),
        reason: 'Unsupported or unsafe zip entry',
      ),
      'central crc that disagrees with the local header': (
        build: () => _rawZip([
              _rawStored('a.txt', _ascii('payload')).withCentralCrc(0xdeadbee),
            ]),
        reason: 'Invalid zip archive',
      ),
      'path traversal entry': (
        build: () => _rawZip([_rawStored('../escape.txt', _ascii('payload'))]),
        reason: 'Unsupported or unsafe zip entry',
      ),
    };

    for (final entry in cases.entries) {
      test('${entry.key} installs no output', () async {
        final run = await _runPipeline(entry.value.build(), 'malformed.zip');

        expect(run.error, _rejectedBecause(entry.value.reason));
        expect(run.installedNames, isEmpty);
        expect(run.originalUnchanged, isTrue);
      });
    }

    test('malformed structure delivered as docx installs no output', () async {
      final input = _rawZip(
        [_rawStored('a.txt', _ascii('payload')).withFlags(0x1)],
      );

      final run = await _runPipeline(input, 'malformed.docx');

      expect(run.error, _rejectedBecause('Invalid office document'));
      expect(run.installedNames, isEmpty);
      expect(run.originalUnchanged, isTrue);
    });
  });
}

/// Outcome of one clean-copy attempt against a throwaway output folder.
class _PipelineRun {
  const _PipelineRun({
    required this.installedNames,
    required this.originalUnchanged,
    this.outputBytes,
    this.error,
  });

  final List<String> installedNames;
  final bool originalUnchanged;
  final Uint8List? outputBytes;
  final Object? error;
}

Future<_PipelineRun> _runPipeline(Uint8List input, String fileName) async {
  final inputDir = await Directory.systemTemp.createTemp('metastrip_zin_');
  final outputDir = await Directory.systemTemp.createTemp('metastrip_zout_');
  addTearDown(() => inputDir.delete(recursive: true));
  addTearDown(() => outputDir.delete(recursive: true));
  final file = File('${inputDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(input, flush: true);

  Uint8List? outputBytes;
  Object? error;
  try {
    final output = await MetadataRemoverDatasource().stripMetadata(
      file.path,
      outputDirectory: outputDir.path,
    );
    outputBytes = await output.readAsBytes();
  } on Object catch (thrown) {
    error = thrown;
  }
  final installed = outputDir
      .listSync()
      .map((entity) => entity.uri.pathSegments.last)
      .where((name) => name.isNotEmpty)
      .toList();
  return _PipelineRun(
    installedNames: outputBytes == null ? installed : const [],
    originalUnchanged: _sameBytes(await file.readAsBytes(), input),
    outputBytes: outputBytes,
    error: error,
  );
}

void _expectDocxReparses(Uint8List bytes) {
  final names = decodeGuardedZip(bytes)
      .files
      .map((file) => normalizeEntryPath(file.name))
      .toSet();
  expect(names, contains('[Content_Types].xml'));
  expect(names, contains('word/document.xml'));
  expect(names, isNot(contains('docProps/core.xml')));
  // A second full strip validates the rebuilt package and finds no metadata.
  expect(identical(stripOpenXml(bytes), bytes), isTrue);
}

void _expectOdtReparses(Uint8List bytes) {
  final entries = preflightZip(bytes);
  final mimetype = entries.singleWhere((entry) => entry.name == 'mimetype');
  expect(mimetype.localHeaderOffset, 0);
  expect(mimetype.compressionMethod, 0);
  final names = entries.map((entry) => normalizeEntryPath(entry.name)).toSet();
  expect(names, contains('content.xml'));
  expect(names, isNot(contains('meta.xml')));
  // A second full strip validates the rebuilt package and finds no metadata.
  expect(identical(stripOdf(bytes, extension: 'odt'), bytes), isTrue);
}

Matcher _rejectedBecause(String message) => isA<FormatException>()
    .having((error) => error.message, 'message', message);

int _declaredAggregate(Uint8List bytes) => preflightZip(bytes)
    .fold(0, (sum, entry) => sum + entry.uncompressedSize);

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Uint8List _ascii(String text) => Uint8List.fromList(utf8.encode(text));

const _docxContentTypes =
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '</Types>';

const _coreXml = '<cp:coreProperties '
    'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    '<dc:creator>Jane</dc:creator>'
    '</cp:coreProperties>';

const _metaXml = '<office:document-meta '
    'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">'
    '<office:meta><meta:generator>MetaStrip</meta:generator></office:meta>'
    '</office:document-meta>';

const _odtMimetype = 'application/vnd.oasis.opendocument.text';

/// Builds a docx whose declared aggregate uncompressed size is [aggregate].
///
/// The bulk entry is stored, not deflated, so the fixture stays cheap to
/// build while still forcing the repacker to move 32 MiB of real content.
Uint8List _docxBytes(int aggregate) => _paddedArchive(
      aggregate,
      {
        '[Content_Types].xml': _ascii(_docxContentTypes),
        'word/document.xml': _ascii('<w:document/>'),
        'docProps/core.xml': _ascii(_coreXml),
      },
      'word/media/payload.bin',
    );

/// Builds an odt whose declared aggregate uncompressed size is [aggregate].
Uint8List _odtBytes(int aggregate) => _paddedArchive(
      aggregate,
      {
        'mimetype': _ascii(_odtMimetype),
        'content.xml': _ascii('<office:document-content/>'),
        'meta.xml': _ascii(_metaXml),
      },
      'Pictures/payload.bin',
      storedPaths: const {'mimetype'},
    );

/// Builds a generic zip whose declared aggregate size is [aggregate].
Uint8List _zipBytes(int aggregate) => _paddedArchive(
      aggregate,
      {'notes.txt': _ascii('hello')},
      'payload.bin',
    );

Uint8List _paddedArchive(
  int aggregate,
  Map<String, Uint8List> fixedEntries,
  String payloadPath, {
  Set<String> storedPaths = const {},
}) {
  final fixed = fixedEntries.values.fold(0, (sum, bytes) => sum + bytes.length);
  final payload = Uint8List(aggregate - fixed);
  final archive = Archive();
  for (final entry in fixedEntries.entries) {
    final file = ArchiveFile(entry.key, entry.value.length, entry.value);
    if (storedPaths.contains(entry.key)) file.compress = false;
    archive.addFile(file);
  }
  archive.addFile(
    ArchiveFile(payloadPath, payload.length, payload)..compress = false,
  );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// A zip record written byte by byte so headers can lie about their content.
class _RawEntry {
  const _RawEntry({
    required this.name,
    required this.data,
    required this.uncompressedSize,
    required this.crc,
    this.method = 0,
    this.flags = 0,
    this.centralUncompressedSize,
    this.centralCrc,
  });

  final String name;
  final Uint8List data;
  final int uncompressedSize;
  final int crc;
  final int method;
  final int flags;
  final int? centralUncompressedSize;
  final int? centralCrc;

  _RawEntry _copyWith({
    int? method,
    int? flags,
    int? centralUncompressedSize,
    int? centralCrc,
  }) =>
      _RawEntry(
        name: name,
        data: data,
        uncompressedSize: uncompressedSize,
        crc: crc,
        method: method ?? this.method,
        flags: flags ?? this.flags,
        centralUncompressedSize:
            centralUncompressedSize ?? this.centralUncompressedSize,
        centralCrc: centralCrc ?? this.centralCrc,
      );

  _RawEntry withMethod(int value) => _copyWith(method: value);

  _RawEntry withFlags(int value) => _copyWith(flags: value);

  _RawEntry withCentralUncompressedSize(int value) =>
      _copyWith(centralUncompressedSize: value);

  _RawEntry withCentralCrc(int value) => _copyWith(centralCrc: value);
}

_RawEntry _rawStored(String name, Uint8List content) => _RawEntry(
      name: name,
      data: content,
      uncompressedSize: content.length,
      crc: getCrc32(content),
    );

_RawEntry _rawDeflated(
  String name,
  Uint8List content, {
  int? declaredUncompressedSize,
}) {
  final deflated = Uint8List.fromList(
    ZLibCodec(raw: true, level: 9).encode(content),
  );
  return _RawEntry(
    name: name,
    data: deflated,
    uncompressedSize: declaredUncompressedSize ?? content.length,
    crc: getCrc32(content),
    method: 8,
  );
}

/// Wraps [payload] in the minimal valid docx package parts.
Uint8List _rawDocx(List<_RawEntry> payload) => _rawZip([
      _rawStored('[Content_Types].xml', _ascii(_docxContentTypes)),
      _rawStored('word/document.xml', _ascii('<w:document/>')),
      _rawStored('docProps/core.xml', _ascii(_coreXml)),
      ...payload,
    ]);

Uint8List _rawZip(
  List<_RawEntry> entries, {
  int diskNumber = 0,
  int directoryDisk = 0,
  bool zip64 = false,
}) {
  final local = BytesBuilder();
  final offsets = <int>[];
  for (final entry in entries) {
    offsets.add(local.length);
    final name = _ascii(entry.name);
    final header = Uint8List(30);
    final view = ByteData.view(header.buffer);
    view
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, entry.flags, Endian.little)
      ..setUint16(8, entry.method, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, 0x21, Endian.little)
      ..setUint32(14, entry.crc, Endian.little)
      ..setUint32(18, entry.data.length, Endian.little)
      ..setUint32(22, entry.uncompressedSize, Endian.little)
      ..setUint16(26, name.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    local
      ..add(header)
      ..add(name)
      ..add(entry.data);
  }

  final central = BytesBuilder();
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final name = _ascii(entry.name);
    final record = Uint8List(46);
    final view = ByteData.view(record.buffer);
    view
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, entry.flags, Endian.little)
      ..setUint16(10, entry.method, Endian.little)
      ..setUint16(12, 0, Endian.little)
      ..setUint16(14, 0x21, Endian.little)
      ..setUint32(16, entry.centralCrc ?? entry.crc, Endian.little)
      ..setUint32(20, entry.data.length, Endian.little)
      ..setUint32(
        24,
        entry.centralUncompressedSize ?? entry.uncompressedSize,
        Endian.little,
      )
      ..setUint16(28, name.length, Endian.little)
      ..setUint16(30, 0, Endian.little)
      ..setUint16(32, 0, Endian.little)
      ..setUint16(34, 0, Endian.little)
      ..setUint16(36, 0, Endian.little)
      ..setUint32(38, 0, Endian.little)
      ..setUint32(42, offsets[index], Endian.little);
    central
      ..add(record)
      ..add(name);
  }

  final localBytes = local.takeBytes();
  final centralBytes = central.takeBytes();
  final end = Uint8List(22);
  final view = ByteData.view(end.buffer);
  view
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(4, diskNumber, Endian.little)
    ..setUint16(6, directoryDisk, Endian.little)
    ..setUint16(8, zip64 ? 0xffff : entries.length, Endian.little)
    ..setUint16(10, zip64 ? 0xffff : entries.length, Endian.little)
    ..setUint32(12, zip64 ? 0xffffffff : centralBytes.length, Endian.little)
    ..setUint32(16, zip64 ? 0xffffffff : localBytes.length, Endian.little)
    ..setUint16(20, 0, Endian.little);

  return Uint8List.fromList([...localBytes, ...centralBytes, ...end]);
}
