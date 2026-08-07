# Changelog

All notable changes to MetaStrip project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase 0: MVP Foundation — 90.9% (2026-07-31)
**Status:** Done (10/11 tasks; dev/prod flavors deliberately deferred)

- Flutter project init, Clean Architecture feature-first layout, git setup
- Theme system: 7 presets, typography, spacing, system font fallbacks
- Shared widgets: PrimaryButton, SecondaryButton, StatusPanel
- Storage abstraction: SharedPreferences wrapper, retryable bootstrap init
- Platform access: system picker + SAF; no broad storage/media permissions
- DI: direct constructor composition at root; router: MaterialApp/Navigator

### Phase 1: Onboarding — Done (2026-08-01)
**Status:** Complete

- 5-slide onboarding: Welcome, Viewer Feature, Remover Feature, Folder Setup, Permissions
- OnboardingCubit manages slide navigation + state persistence
- Output folder picker: `Saf().pickDirectory()` on Android, `file_selector` elsewhere
- SAF tree URI validation via `Saf().stat()` instead of dart:io probe
- "I UNDERSTAND" completes setup in one tap when valid folder is selected
- Onboarding state persisted via SharedPreferences through storage abstraction

### Phase 2: Metadata Engine — MVP Complete for Implemented Formats (2026-08-07)
**Status:** MVP complete for the registered extractor/remover formats; video and additional format work remain deferred.

#### Done
- Supported extension allowlist and MIME lookup
- JPEG/TIFF EXIF extraction: GPS, camera, lens, timestamps, privacy flags
- PNG tEXt + uncompressed iTXt extraction
- SHA-256 hash computation (opt-in, size-guarded)
- Privacy field detection for GPS, author, device info
- Audio extractors: ID3 (MP3), Vorbis Comments (FLAC/OGG/Opus), RIFF INFO (WAV/AIFF)
- PDF DocInfo + XMP extraction via pure-Dart parser (Info dictionary literal/hex
  + `<?xpacket...?>` region scan; no `syncfusion_flutter_pdf` dependency)
- Office extractors: DOCX/XLSX/PPTX core props + ODT/ODS/ODP ODF metadata
- Archive metadata parsing (ZIP listing + best-effort textual APK manifest
  package/version scanning; binary AXML parsing remains deferred)
- GIF, WebP, BMP extractors
- Isolate-worker extraction while the app is foregrounded (single
  `runOnWorker` call for parse + hash); OS background execution is not wired
- Remover format registry expanded to 18 extensions
  (`RemoverStrippableExtensions`): jpg/jpeg/png/pdf/mp3/flac/ogg/opus/
  wav/aiff/docx/xlsx/pptx/odt/ods/odp/gif/webp
- New strippers wired: ID3, Vorbis/FLAC, RIFF (WAV/AIFF), Office core props,
  ODF metadata, GIF comments, WebP EXIF/XMP
- Limited selective parameters for PNG tEXt/iTXt (per keyword) and PDF DocInfo
  (per Info key, 9 keys incl. `Trapped`); the broader Selective, Anonymize, and
  Preserve Technical modes are planned/unwired. Null/empty `selectiveLabels`
  uses the current supported-cleanup behavior.
- PDF removal rewritten with a linear byte scanner (no regex backtracking)
- Shared zip-entry path normalization (`normalizeEntryPath`): extractor viewer
  and remover stripper use the same exact-or-suffix matching, so a docx/odt
  with non-canonical entry paths (`a/docProps/core.xml`, `docProps//core.xml`,
  `docProps\core.xml`) is consistently stripped instead of silently leaking
- Remover UI copy updated to advertise the 18-format remover registry

#### Remaining
- Video (MP4/MKV/AVI/WebM/3GP/FLV/WMV): deferred. The originally planned
  `ffmpeg_kit_flutter_full_gpl` was retired upstream and breaks on
  Flutter ≥3.29; alternative is a pure-Dart MP4/Matroska metadata parser or
  deferring until a maintained library is chosen.
- HEIC/HEIF extraction: requires a HEIF container parser; pending.
- Selective stripping for audio (MP3 frame-level) and Vorbis (per-key):
  parameter plumbing shipped, stripper implementation pending.
- Archive removal (ZIP/APK metadata stripping): out of MVP strip scope; APK
  stripping would invalidate the signing block.
- Granular audio removal and per-property Office removal: deferred; current
  strippers use format-level cleanup behavior.

### Phase 3: Viewer UI — Done (2026-07-31)
**Status:** MVP complete

- ViewerCubit: file add, mark/unmark, sort (name/size/type/newest), filter
- Multi-file picker integration with dedup + extension filter
- File list items with extension badge + privacy warning
- Metadata detail screen: grouped accordion sections, selectable fields
- Copy field value to clipboard
- Mark visible / clear marks / send marked to Remover handoff
- Empty state widget

### Phase 4: Remover UI — Done (2026-08-06)
**Status:** MVP complete with security hardening

- RemoverBloc: sequential processing, queue cap, cancel, reset
- RemoverScreen: file queue with supported-cleanup status, process button; the
  broader mode selector remains planned/unwired
- ProcessingScreen: live progress bar + per-file status + cancel
- ResultScreen: 4-tile stats grid + per-file output list + Done
- **JPEG scrubber:** preserves APP0/JFIF and drops APP1/APP2/APP12/APP13/APP14/COM; EOI truncation
- **PNG scrubber:** drops text chunks + tIME + eXIf
- **PDF scrubber:** DocInfo blanking (best-effort)
- Output: collision-safe naming (`_clean`, `_clean_1`, etc.)
- SAF output writing for `content://` URIs via `Saf().writeFileBytes()`
- Error sanitization (strips filesystem paths from messages)
- Android package fix: `MainActivity.kt` → `com.bariskode.metastrip`

### Security & Correctness Hardening (2026-08-07)
**Status:** Done

- Decompression-bomb guard for zip-backed extractors (OpenXML/ODF/ZIP): shared
  `decodeArchiveFileSafely` helper caps per-entry decompression at 64MB
  (declared + real content) and 128MB cumulative before any `entry.content`
  access; oversized entries degrade to status fields instead of OOM
- Zip repack hardening: per-entry cap (declared + actual decompressed) and
  actual-content total cap; exception messages no longer embed hostile entry
  names
- PDF extractor: replaced non-greedy `obj...endobj` regex scan with a bounded
  linear scan (max 64 regions, 1MB window) — no more quadratic hang on PDFs
  full of object markers without `endobj`
- Honest SHA-256 for bounded-read audio (MP3/FLAC/OGG/Opus): hash now covers
  the full file (read inside the isolate) instead of only the scan prefix
- ID3 stripper synchsafe mask consistency with the extractor (`& 0x7F` per byte)
- PNG tEXt/iTXt keyword labels truncated like values
- Bounded in-memory hash cache (512 entries max, full clear on overflow)
- PDF removal: replaced regex-over-whole-document with a single-pass linear
  byte scanner (no `(?:\\\.|[^)])*` overlap → no ReDoS on hostile backslash
  floods); 9 Info keys incl. `Trapped` blanked
- Zip path consistency: shared `normalizeEntryPath` (collapse slashes, strip
  `.` segments, `\` → `/`) used by extractor viewer and remover stripper
  with exact-or-suffix matching; closes silent strip-failure for
  `a/docProps/core.xml` / `docProps//core.xml` / `docProps\core.xml`

### Phase 5: Settings — MVP Complete (2026-08-07)
**Status:** Complete for exposed MVP controls; advanced storage/processing controls remain follow-up

- App-level SettingsCubit with serialized SharedPreferences-backed load/save and live theme application
- 7 preset themes plus a persisted custom 16-token theme builder with preview
- Output-folder selection validates and updates the same device-local setting used by onboarding/removal; onboarding changes synchronize back into Settings state
- Portable JSON export/import: exports omit `outputFolderPath`; imports preserve and validate the current device folder
- Two-step reset clears app settings, theme/output-folder configuration, and onboarding state, then returns to onboarding; generated clean copies/output files are not deleted
- Maintenance and information UI: cache status/action (currently 0-byte no-op), About, version, and Licenses
- Naming template, folder structure, keep-original, JPEG quality, concurrency, and auto-confirm remain persistence/import fields only; their controls are not exposed or wired to processing

### Phase 6: Polish & Testing — Not Started
**Status:** Pending after Phases 1-5 MVP completion

---

## Verification (2026-08-07, Phase 2 + hardening + path-normalization)
- `flutter analyze`: clean (0 issues)
- `flutter test`: **245 passed, 1 skipped**
- Test coverage: not measured in this verification run
- Debug APK: build verified (`build\app\outputs\flutter-apk\app-debug.apk`); no
  device-install verification is claimed here.

## Known Risks
- **PDF removal is best-effort DocInfo blanking.** XMP, object streams, JavaScript,
  embedded files, and other metadata may survive. A structural PDF parser is
  required before comprehensive-removal claims are safe.
- `FileItemEntity` lives in the viewer feature while remover imports it;
  moving it to `shared/domain/` remains future cleanup.
- Custom font declarations disabled; asset folders empty; runtime uses system fallbacks.
- No background processing or notification support yet.
- No crash reporting, signing, or obfuscation for release builds.

## Historical Baseline

The initial project scaffold established the Flutter Android/iOS targets,
feature-first Clean Architecture, BLoC/Cubit state management, theme tokens,
shared controls, and basic smoke testing. Current completion and verification
status is maintained under `[Unreleased]`; no `1.0.0` release has been recorded.
