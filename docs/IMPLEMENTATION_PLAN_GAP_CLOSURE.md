# MetaStrip — Gap Closure Implementation Plan

**Status:** In progress — Phase 0 complete; Phase 1 pending
**Version:** 1.1
**Created:** 2026-08-08
**Related plan:** [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)

---

## 1. Purpose and scope

This document defines the execution plan for the seven major capability gaps
identified in the current implementation plan:

1. Video metadata removal.
2. HEIC/HEIF support and removal.
3. Archive metadata removal.
4. BMP/TIFF removal.
5. Legacy Office (`.doc`, `.xls`, `.ppt`) removal.
6. Granular/selective removal.
7. Comprehensive PDF metadata cleanup.

The gaps must not be implemented as seven equivalent extension additions.
Their correctness, security, and platform risks differ substantially. New
extensions must only enter the remover registry after the relevant parser,
writer, validator, and test gates pass.

### Product safety principles

- Originals are never mutated.
- Every operation produces a clean copy or an explicit failure.
- Unsupported variants fail closed; they must not produce an unverified copy.
- A format is not described as “comprehensive” unless its supported metadata
  surfaces are structurally verified.
- Selective requests must never silently become full stripping.
- Native dependencies require Flutter/Android/iOS compatibility and license
  review before adoption.
- The app remains offline-only.

---

## 2. Current baseline and constraints

The existing implementation uses:

- Clean Architecture and feature-first organization.
- `MetadataRemoverDatasource` as the remover facade.
- `RemoverBloc` for queue validation, sequential processing, cancellation, and
  result reporting.
- Direct constructor injection; no service locator is planned.
- `FormatRegistry` as the authoritative capability registry, with
  `RemoverStrippableExtensions` retained as a compatibility facade.
- Format-specific strippers under
  `lib/features/remover/data/datasources/strippers/`.
- `runOnWorker()` for CPU-heavy byte operations.
- `core/processing/zip_repack.dart` with path traversal and archive-size guards.
- A global remover size cap (`AppConstants.maxRemoverFileSizeBytes`).
- Declarative per-format extraction/removal limits and processing strategies;
  runtime queue validation consumes the removal limit from the capability.

The current registered remover set contains 18 extensions:

```text
jpg, jpeg, png, pdf,
mp3, flac, ogg, opus, wav, aiff,
docx, xlsx, pptx, odt, ods, odp,
gif, webp
```

The current PDF implementation is best-effort Info dictionary cleanup. Video,
HEIC/HEIF, archive removal, BMP/TIFF removal, legacy Office removal, and full
selective-mode behavior are not yet complete.

---

## 3. Execution strategy and priority

The recommended order is:

```text
Phase 0  Capability registry and safety contracts
Phase 1  Selective removal for existing formats
Phase 2  BMP and TIFF subset removal
Phase 3  PDF structural metadata cleanup
Phase 4  ZIP-only archive cleanup
Phase 5  HEIF extraction POC and removal decision
Phase 6  Video technology spike and incremental implementation
Phase 7  Legacy Office decision gate
Phase 8  Selective UI, device validation, and release hardening
```

The first four phases provide the best balance of user value and technical
certainty. HEIF, video, and legacy Office require explicit proof-of-concept
decisions and should not be implemented by merely adding extensions to a
switch statement.

---

## 4. Phase 0 — Capability registry and safety contracts

**Priority:** P0
**Estimate:** Small to medium
**Dependencies:** None

**Status:** Complete (2026-08-08)

Implemented in `lib/core/format/`:

- Shared descriptors cover all 41 Viewer-accepted extensions.
- Removal remains exactly the existing 18-extension set.
- PNG and basic PDF Info cleanup are the only formats advertising selective
  capability; no new format was enabled.
- Lookup normalizes case, whitespace, and leading dots.
- Viewer and Remover gates query the shared registry.
- Concrete Viewer extraction and Remover route maps are contract-tested against
  the declarations in both directions.
- Removal queue and pre-processing validation consume the declared per-format
  removal limit.

This phase does not claim that selective removal is production-wired end to
end. The existing label-based PNG/PDF datasource seam remains for compatibility
until Phase 1 introduces stable field IDs and an explicit policy object.

Phase 0 security hardening is complete for the registered ZIP-backed routes:

- Raw EOCD and central-directory preflight runs before `ZipDecoder` and rejects
  ZIP64/multi-disk input, encryption, unsupported compression, symlinks, unsafe
  or duplicate canonical paths, invalid local ranges/descriptors, excessive
  entry counts, and malformed records. Repack payload limits are applied by a
  separate policy, so Viewer metadata reads are not blocked by unrelated large
  entries that are never decompressed.
- Entry decompression uses a bounded output sink, followed by exact-size and
  CRC verification; understated DEFLATE streams stop at the configured cap.
- Viewer ZIP/OpenXML/ODF routes consume the same guarded decoding path.
- OOXML removal validates a bounded `[Content_Types].xml`, namespace, and the
  extension-specific Transitional or Strict main-part content type. It resolves
  metadata parts from bounded root package relationships, rejects external,
  duplicate, ambiguous, or missing targets, and removes corresponding
  relationship and content-type declarations from cleaned output.
- ODF removal requires an exact bounded `mimetype` as the first physical,
  uncompressed entry and preserves that rule in cleaned output.

Residual risk: the repacker is still in-memory. Its total decompressed-content
budget is now 32 MiB, materially reducing memory amplification, but device
stress testing and a future streaming repacker remain release-hardening work.

### Goals

Separate extraction capability from removal capability and make format support
machine-readable for routing, UI, validation, and documentation.

### Proposed capability model

Add a lightweight registry descriptor, for example:

```dart
enum SupportLevel {
  filesystemOnly,
  extractOnly,
  removeFull,
  removeSelective,
  experimental,
  unsupported,
}

enum ProcessingStrategy {
  inMemory,
  streaming,
  temporaryFile,
  platformAdapter,
}
```

Each format descriptor should define:

- extensions and MIME types;
- category (image, audio, document, archive, video);
- extraction capabilities;
- full/selective removal capabilities;
- supported removal modes;
- processing strategy;
- per-format input-size limit;
- output validator;
- known limitations;
- experimental status, if applicable.

The registry should contain descriptors and handler factories only. Parser and
stripper logic remains inside the owning feature.

### Proposed domain additions

Potential additions:

```text
lib/core/format/format_capability.dart
lib/core/format/format_registry.dart
lib/core/format/support_level.dart
lib/features/remover/domain/entities/strip_policy.dart
lib/features/remover/domain/entities/strip_report.dart
lib/features/remover/domain/entities/metadata_field_descriptor.dart
```

Migrate `selectiveLabels` gradually to stable field IDs. Display labels must
not be the domain contract.

Example field IDs:

```text
png.text.author
pdf.info.author
pdf.xmp.creator
audio.id3.artist
office.core.creator
image.exif.gpsLatitude
```

### Acceptance criteria

- Viewer and Remover query the same capability source.
- `RemoverBloc` rejects unsupported capabilities before processing.
- Selective requests cannot silently fall back to full strip.
- Existing tests remain green.
- Registry contract tests cover descriptor-to-handler consistency.

---

## 5. Phase 1 — Granular/selective removal

**Priority:** P0
**Estimate:** Medium to large
**Dependencies:** Phase 0

### Problem to solve

The current selective plumbing is partial. PNG and PDF support selected fields,
while other formats reject selective requests before processing. This behavior
must remain explicit and safe as stable field IDs replace display labels.

### Policy semantics

#### Supported cleanup

Remove all metadata covered by the format's supported stripper.

#### Selective

Remove only the selected stable field IDs. If a selected field is unsupported,
return a clear warning or failure according to the policy; never silently
remove additional fields.

#### Anonymize

Remove fields classified as identifying, such as GPS, creator, device,
software, timestamps, and identifiers. This mode remains unwired until every
format exposes a defined privacy mapping.

#### Preserve technical

Remove identifying metadata while preserving technical fields required for
rendering or playback. This also remains format-specific until explicitly
verified.

### Implementation order

1. Migrate PNG keyword selection to field IDs.
2. Migrate PDF Info-key selection to field IDs.
3. Add per-property XML removal for DOCX/XLSX/PPTX.
4. Add per-property removal for ODT/ODS/ODP.
5. Add MP3 frame-level removal.
6. Add FLAC/OGG/Opus comment-key removal.
7. Add WAV/AIFF field-level removal.

### Result reporting

Extend processing results to report:

- requested fields;
- removed fields;
- unsupported fields;
- preserved fields when relevant;
- warnings;
- output validation status;
- whether re-encoding occurred.

### Acceptance criteria

- Stable field IDs are used end-to-end.
- Selective policy is carried per file or explicitly per batch.
- Unsupported selected fields are visible to the user.
- Post-removal extraction verifies selected fields are absent.
- Widget, BLoC, repository, and stripper tests cover selective behavior.

---

## 6. Phase 2 — BMP and TIFF removal

**Priority:** P1
**Estimate:** Medium for BMP; medium-large for TIFF
**Dependencies:** Phase 0

### BMP

Implement a validated, preferably lossless rewrite for standard BMP files:

- preserve pixel payload;
- preserve dimensions and bit depth;
- remove understood profile/trailing metadata;
- reject unsupported compression/header variants;
- validate the output signature and header offsets.

Candidate file:

```text
lib/features/remover/data/datasources/strippers/bmp_stripper.dart
```

Do not claim complete BMP sanitization until trailing data and profile behavior
are covered by fixtures.

### TIFF

TIFF requires a dedicated parser/re-writer. Extraction support from the `exif`
package must not be assumed to provide safe writing.

Initial target:

- Classic TIFF;
- little- and big-endian files;
- EXIF and GPS IFDs;
- XMP and thumbnail handling where identified;
- multi-IFD files with tested offset rebuilding.

Initially reject or mark experimental:

- BigTIFF;
- unsupported compression/tile variants;
- vendor-specific structures not understood by the rewriter.

### Required POC corpus

- Both endian variants.
- Multi-page TIFF.
- EXIF/GPS/XMP/ICC/private tags.
- Embedded thumbnail.
- Compressed strips or tiles.
- BigTIFF detection.
- Truncated and malformed files.

### Acceptance criteria

- Output opens in at least two independent TIFF readers.
- Image dimensions and payload remain valid according to policy.
- Target metadata is absent after re-extraction.
- Unsupported variants fail closed.

---

## 7. Phase 3 — PDF structural metadata cleanup

**Priority:** P1
**Estimate:** Extra large
**Dependencies:** Phase 0 and a PDF technology spike

### Capability levels

Use precise product language:

1. **Basic metadata cleanup:** current Info dictionary behavior.
2. **Structural metadata cleanup:** Info, XMP, metadata streams, indirect
   objects, object streams, and xref structures within the supported parser
   scope.
3. **PDF sanitization:** additionally handles JavaScript, attachments,
   embedded files, annotations, forms, thumbnails, and other active/hidden
   content.

The first target should be Level 2. Level 3 should be a separate, destructive
feature with its own product and security review.

### Technology spike

Compare:

- pure-Dart structural parser/re-writer;
- maintained PDF library;
- native platform/library backend.

Evaluate license, Flutter compatibility, Android/iOS parity, binary size,
encrypted/signed document behavior, and round-trip fidelity.

### Required corpus

- PDF 1.3 xref tables.
- PDF 1.5 xref streams.
- Compressed object streams.
- Incremental updates.
- Literal, hex, and compressed XMP.
- Attachments and JavaScript.
- Encrypted and signed PDFs.
- Linearized PDFs.
- Files generated by Office, browsers, scanners, Adobe, and LibreOffice.
- Malformed but commonly tolerated PDFs.

### Acceptance criteria

- Output renders correctly.
- Page count, text, images, and layout remain valid.
- Target metadata is absent from the supported object graph.
- No dangling references or invalid xref data.
- Encrypted and signed PDFs have explicit reject/warning behavior.
- Documentation states exact coverage and limitations.

---

## 8. Phase 4 — ZIP-only archive cleanup

**Priority:** P1
**Estimate:** Medium to large
**Dependencies:** Phase 0; existing ZIP guards

### Initial scope

Support archive-container cleanup only:

- archive comment;
- supported central-directory metadata;
- supported timestamps/extra fields;
- payload entries preserved byte-for-byte when possible.

Recursive cleanup of metadata inside archive members is a separate later scope.
It requires a global decompression budget, nested archive depth, per-member
capabilities, and transactional failure semantics.

### APK policy

APK repacking invalidates APK signatures and may make the result
non-installable. APK must not be added to the general remover registry.

If APK support is ever pursued, it requires a separate rebuild/resign feature,
keystore UX, signing tests, and security review.

### EPUB policy

Treat EPUB separately from generic ZIP. Preserve the required `mimetype`
entry ordering, compression, and package structure.

### Acceptance criteria

- ZIP output reopens successfully.
- Entry names, count, CRC, and safe paths are valid.
- Bomb and traversal limits remain enforced.
- Target archive metadata is removed.
- Recursive member metadata is not claimed as removed unless separately tested.

---

## 9. Phase 5 — HEIC/HEIF extraction and removal decision

**Priority:** P2
**Estimate:** Large to extra large
**Dependencies:** Phase 0; container POC

### Work sequence

1. Identify HEIF brands and container structure.
2. Add conservative extraction for EXIF, XMP, ICC, primary image, and
   auxiliary items.
3. Implement a bounded ISO BMFF/HEIF box parser.
4. Prototype removal without decoding pixel data.
5. Rebuild item offsets and references.
6. Validate output on Android and iOS.
7. Add only proven variants to the remover registry.

### Backend decision

Choose pure Dart or native/library implementation only after evaluating:

- no-reencode support;
- malformed-box handling;
- item reference correctness;
- platform parity;
- license and maintenance;
- binary size.

### Acceptance criteria

- EXIF/XMP target items are removed.
- `iloc`, item references, and offsets remain valid.
- Image payload is preserved in no-reencode mode.
- Output opens on Android and iOS.
- Unsupported HEIF variants are explicit failures.

If the POC fails, HEIC/HEIF remains extract-only or filesystem-only.

---

## 10. Phase 6 — Video technology spike and incremental support

**Priority:** P2
**Estimate:** Extra large
**Dependencies:** Phase 0; backend decision

Video support must be split by container family:

| Family | Initial target | Status rule |
|---|---|---|
| ISO BMFF | MP4/MOV/M4V/3GP | First implementation candidate |
| EBML | MKV/WebM | Separate spike and validator |
| RIFF | AVI | Separate handler |
| FLV | FLV | Separate handler |
| ASF | WMV | Deferred until backend is proven |

### MP4/MOV spike

Verify:

- metadata atoms in `moov`, `udta`, `meta`, `ilst`, and `uuid`;
- chapters and attachments;
- fragmented MP4;
- `stco` and `co64` offset handling;
- audio, video, subtitle, and cover-art preservation;
- duration, rotation, and codec preservation.

### Backend constraints

Do not add the retired `ffmpeg_kit_flutter_full_gpl` solely because it appears
in historical pseudocode. Any native backend must pass build, license, ABI,
Android/iOS, and maintenance checks.

Do not combine stream-copy with filters that require re-encoding. If re-encoding
is ever necessary, report it explicitly and add fidelity tests.

### Acceptance criteria

- Output is playable on supported Android and iOS versions.
- Stream count, codec, duration, and payload remain valid according to policy.
- Target metadata is verified absent.
- Malformed, fragmented, or unsupported inputs fail closed.
- Processing uses streaming/temp files or a strict size cap rather than
  unbounded `readAsBytes()`.

Only extensions that pass these criteria may enter the remover registry.

---

## 11. Phase 7 — Legacy Office decision gate

**Priority:** P3
**Estimate:** Large to extra large
**Dependencies:** Available CFB/OLE2 backend

Legacy `.doc`, `.xls`, and `.ppt` files use OLE2/Compound File Binary Format,
not Open XML.

### Requirements before implementation

A candidate library/backend must be:

- actively maintained;
- compatible with current Flutter Android/iOS toolchains;
- distributable under an acceptable license;
- capable of reading and writing CFB streams;
- capable of handling SummaryInformation and custom properties;
- tested with macros, embedded objects, encryption, and malformed files.

### Prohibited shortcuts

- Extension renaming.
- ZIP repacking.
- Naive string deletion.
- Silent conversion to DOCX/PDF.

### Decision

Until the requirements are met:

- Viewer may remain filesystem-only or extract-only.
- Remover must reject the format clearly.
- No legacy Office extension enters the remover registry.

---

## 12. Cross-format architecture changes

Likely additions:

```text
lib/core/format/format_capability.dart
lib/core/format/format_registry.dart
lib/core/format/support_level.dart

lib/features/remover/domain/entities/strip_policy.dart
lib/features/remover/domain/entities/strip_report.dart
lib/features/remover/domain/entities/metadata_field_descriptor.dart

lib/features/remover/data/datasources/strippers/bmp_stripper.dart
lib/features/remover/data/datasources/strippers/tiff_stripper.dart
lib/features/remover/data/datasources/strippers/zip_stripper.dart
lib/features/remover/data/datasources/strippers/heif_stripper.dart
lib/features/remover/data/datasources/strippers/video_stripper.dart
lib/features/remover/data/datasources/strippers/pdf_structural_stripper.dart
```

Keep `MetadataRemoverDatasource` as the facade and preserve direct constructor
injection. Do not introduce `get_it` or `go_router` for this work.

For large files and complex containers, extend the processing strategy to
support temporary-file or streaming workflows rather than increasing the
global remover size limit.

---

## 13. Security and performance requirements

### Binary parser safety

- Bounds-check every read.
- Use checked arithmetic for offsets and sizes.
- Enforce nesting, entry, object, and box limits.
- Reject invalid offsets, cyclic references, and ambiguous structures.
- Keep heavy processing isolated.
- Do not log raw paths, metadata values, or bytes.

### Archive safety

- Preserve path traversal protection.
- Enforce per-entry and aggregate declared/actual size caps.
- Add nested archive depth and expansion-ratio limits for recursive mode.
- Fail closed on uncertain archive structure.

### Output safety

- Write to a temporary clean-copy path.
- Validate/reparse output before installation.
- Preserve collision-safe naming.
- Never overwrite the original.
- Clean temporary files on all failure paths.

### Performance

- Keep in-memory processing for small bounded formats.
- Use streaming/temp files for large video, PDF, and recursive archive jobs.
- Keep processing sequential until memory and cancellation behavior are measured.
- Benchmark at 1 MB, 10 MB, 50 MB, 100 MB, and the largest supported fixture.

---

## 14. Test strategy

### Unit tests

Each new stripper requires:

- valid minimal fixture;
- real-world fixture;
- metadata-free fixture;
- malformed/truncated fixture;
- unsupported variant fixture;
- boundary-size fixture;
- selective-policy fixture;
- output reparse test;
- original-preservation test.

### Corpus tests

Verify:

- format signature;
- dimensions, duration, page count, and stream count;
- payload fidelity according to policy;
- metadata before/after;
- output size and expansion ratio;
- parser round-trip;
- external reader/playability where applicable.

### Fuzz/property tests

Prioritize PDF, TIFF, HEIF, ISO BMFF, EBML, CFB/OLE2, and ZIP. Inputs must
include truncation, invalid lengths, integer overflow, deep nesting, cyclic
references, duplicate fields, and huge declared sizes.

### Integration and widget tests

Extend the existing registry, repository, BLoC, and filesystem-backed flow
tests. Add UI coverage for capability status, selective fields, unsupported
warnings, signed APK warnings, PDF limitations, processing reports, and
cancellation.

### Device tests

Run on real Android and iOS environments for:

- SAF/file picker behavior;
- HEIC/HEIF openability;
- video playback;
- large files;
- temp-file access;
- foreground/background lifecycle;
- external output opening.

---

## 15. Acceptance criteria by gap

### Video

- [ ] Capability is defined per container family.
- [ ] MP4/MOV/M4V support is limited to a passing POC scope.
- [ ] Streams remain playable and structurally valid.
- [ ] Metadata removal is verified rather than inferred from write success.
- [ ] Unsupported containers fail explicitly.

### HEIC/HEIF

- [ ] HEIF brands and variants are detected.
- [ ] EXIF/XMP removal is verified for supported variants.
- [ ] Item references and offsets remain valid.
- [ ] Output opens on Android and iOS.
- [ ] Unsupported variants remain out of the remover registry.

### Archives

- [ ] ZIP container cleanup works without damaging entries.
- [ ] Bomb, traversal, and size protections remain active.
- [ ] Recursive member cleanup is not overclaimed.
- [ ] APK signed-state policy is explicit.
- [ ] EPUB preserves its required `mimetype` constraints if enabled.

### BMP/TIFF

- [ ] BMP output preserves pixel payload and remains readable.
- [ ] TIFF baseline variants pass round-trip tests.
- [ ] EXIF/GPS/XMP handling is defined.
- [ ] BigTIFF and unsupported variants fail closed.

### Legacy Office

- [ ] CFB/OLE2 is handled as a distinct format.
- [ ] Property-set removal is verified for supported documents.
- [ ] Macro, embedded-object, encrypted, and corrupt behavior is explicit.
- [ ] No extension enters the registry without a safe writer.

### Selective removal

- [ ] Stable field IDs are used.
- [ ] Policy is propagated per file.
- [ ] Unsupported fields produce clear warning/failure.
- [ ] No silent full-strip fallback exists.
- [ ] Removed/preserved/unsupported fields are reported.

### Comprehensive PDF

- [ ] Scope level is explicitly named.
- [ ] XMP and targeted metadata streams are handled at structural level.
- [ ] Object/xref behavior is tested.
- [ ] Incremental updates, encryption, and signatures have policy decisions.
- [ ] Claims match verified coverage.

---

## 16. Release gates

Before enabling any new format in production:

1. Capability and handler contract tests pass.
2. Valid, malformed, and unsupported fixtures pass.
3. Output can be reparsed and validated.
4. Target metadata is absent within the documented scope.
5. Original mutation tests pass.
6. Size and memory limits pass.
7. `flutter analyze` is clean.
8. Full `flutter test` passes.
9. Debug and release build gates pass when release credentials are available.
10. Android/iOS device validation passes for platform-sensitive formats.
11. Code review and security review approve the change.
12. Changelog, capability documentation, and user-facing limitations are
    updated.

---

## 17. Relative estimates

| Workstream | Estimate | Risk |
|---|---:|---|
| Capability registry and policy | S–M | Medium |
| Selective existing formats | M–L | Medium |
| BMP removal | M | Low–medium |
| TIFF subset | M–L | Medium–high |
| PDF structural cleanup | XL | Very high |
| ZIP-only cleanup | M | Medium |
| Recursive archive cleanup | L | High |
| HEIC/HEIF | L–XL | High |
| MP4/MOV video | XL | Very high |
| Other video containers | L–XL each | Very high |
| Legacy Office | L–XL | Very high |
| Selective UI and final integration | L | Medium–high |
| Device/security/release hardening | L | High |

These are relative planning estimates, not calendar commitments. The HEIF,
video, PDF, and Legacy Office estimates must be revised after their technology
spikes.

---

## 18. Open decisions requiring spikes

- Pure Dart versus native/library backend for HEIC/HEIF.
- Pure Dart ISO BMFF/EBML rewriter versus a maintained media backend.
- Safe CFB/OLE2 writer availability for legacy Office.
- Structural PDF parser capability for xref streams and object streams.
- Whether signed APK processing is rejected permanently or becomes a separate
  rebuild/resign feature.
- Selective-mode behavior for unsupported fields: fail closed versus warning.
- Streaming/temp-file architecture for large files and recursive archives.
- Exact product terminology for PDF Level 1, Level 2, and Level 3 cleanup.

Until these decisions are resolved, the affected extensions must remain
`experimental`, `extractOnly`, or `unsupported`; they must not be presented as
fully supported Remover formats.
