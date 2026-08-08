# MetaStrip Project Progress Report

**Snapshot:** 2026-08-09
**Overall:** Implemented-scope MVP is usable and mostly complete. Gap-closure Phases 0-1 are implemented, the narrow Phase 2 BMP subset is enabled, and Phase 4 ZIP-only cleanup is implemented; full product-spec MVP, device/SAF validation, stress testing, and release readiness are not complete.
**Device:** Samsung SM M205G (Android 8.1), serial `3201fbb0c40a1615`

## Status Definitions

- **Implemented-scope MVP:** the currently usable scope covering onboarding, Viewer functionality for registered extractors, clean-copy removal for the registered 20 extensions, and exposed Settings controls. Known format and workflow limitations remain.
- **Full product-spec MVP:** the complete target described in `docs/SPECS.md`. It includes capabilities that are still planned, deferred, or unwired, so it is **not complete**.
- **Release-ready product:** full product-spec MVP plus integration/device testing, performance and accessibility verification, release-build validation, and release hardening. It is **not complete**.

## Gap Closure Update (2026-08-09)

Phases 0 and 1 of `docs/IMPLEMENTATION_PLAN_GAP_CLOSURE.md` are complete within
the current PNG/PDF selective scope, and the narrow Phase 2 BMP subset is
enabled. The shared capability registry describes all 41 Viewer extensions and
the 20 registered Remover extensions, including ZIP-only container cleanup.
Stable field IDs and a per-file `StripPolicy` now travel from Viewer field
selection through the Remover BLoC, repository, and datasource. `StripReport`
facts reach the result UI, including warnings and output-validation state.
Unsupported or mismatched selective requests fail closed per file without a
silent full-cleanup fallback.

PNG selective text removal is verified for local persisted output: the clean
copy is read back and reparsed before the report is marked verified. Generated
SAF PNG bytes are validated before writing, but persisted SAF readback remains
unverified and scheduled for device validation. PDF selective DocInfo cleanup is only attempted by the existing
best-effort scanner: its report does not claim removed IDs or validated output,
and the result UI presents the unverified warning. These changes do not enable
TIFF removal, APK/EPUB removal, recursive archive-member cleanup, HEIF, video, legacy Office, broader selective format
support, Anonymize, or Preserve Technical behavior.

Device/SAF and ZIP-family memory stress testing are scheduled, not complete.
The executable lanes and acceptance thresholds are in
[`docs/DEVICE_AND_STRESS_TEST_PLAN.md`](docs/DEVICE_AND_STRESS_TEST_PLAN.md).

## Completed Phases

### Phase 0: MVP Foundation — 90.9% (10/11 tasks)
- Flutter project init, Clean Architecture feature-first layout, git setup
- Theme system: 7 presets, typography, spacing, system font fallbacks
- Shared widgets: PrimaryButton, SecondaryButton, StatusPanel
- Storage abstraction: SharedPreferences wrapper, retryable bootstrap init
- Platform access: system picker + SAF; no broad storage/media permissions
- DI: direct constructor composition; router: MaterialApp/Navigator
- Dev/prod flavors deliberately deferred for single-binary MVP

### Phase 1: Onboarding — Complete
- 5-slide onboarding: Welcome, Viewer Feature, Remover Feature, Folder Setup, Permissions
- OnboardingCubit manages slide navigation + state persistence
- Output folder picker: `Saf().pickDirectory()` on Android, `file_selector` elsewhere
- SAF tree URI validation via `Saf().stat()` instead of dart:io probe
- "I UNDERSTAND" completes setup in one tap when valid folder is selected
- Onboarding state persisted via SharedPreferences through storage abstraction

### Phase 2: Metadata Engine — Implemented-scope MVP Complete (2026-08-07)
**Done (extraction for the registered extractor formats):**
- Supported extension allowlist and MIME lookup
- JPEG/TIFF EXIF extraction: GPS, camera, lens, timestamps, privacy flags
- PNG tEXt + uncompressed iTXt extraction (keyword label truncated to 4096)
- SHA-256 hash computation (opt-in, size-guarded ≤100MB; full-file hash for
  bounded-read audio via second isolate read)
- Privacy field detection for GPS, author, device info
- Audio: ID3v2.2/2.3/2.4 + ID3v1.1 (MP3), Vorbis Comments (FLAC/OGG/Opus),
  RIFF INFO (WAV/AIFF); AIF/AIFC are allowlisted for filesystem metadata only
- PDF: pure-Dart Info dictionary (bounded object scan: max 64 regions and 1MB
  per region) + linear XMP packet scan over the size-capped extraction payload
- Office: DOCX/XLSX/PPTX core props via archive + ODT/ODS/ODP ODF meta.xml
- Archives: ZIP entry listing + best-effort textual APK manifest package/version
  scanning; binary AXML parsing remains deferred
- GIF (comment extension), WebP (EXIF/XMP RIFF chunks), BMP extraction and
  narrow canonical BMP removal
- Isolate-worker extraction while the app is foregrounded (single
  `runOnWorker` for parse + hash); OS background execution is not wired

**Done (removal, 20 extensions):**
- JPEG/PNG scrubbers, PDF linear-scanner DocInfo stripper (9 keys incl.
  `Trapped`)
- New strippers: ID3 (synchsafe masked), Vorbis (FLAC block drop + OGG
  in-place comment rewrite with Ogg CRC recompute), RIFF (WAV/AIFF),
  OpenXML (zip repack without `docProps/{core,app,custom}.xml`),
  ODF (zip repack without `meta.xml`), GIF (comment + XMP app-extension),
  WebP (EXIF/XMP chunk + VP8X flag clear), and ZIP container cleanup (EOCD and
  entry comments, DOS timestamps, recognized `0x5455`/`0x000a` extras; member
  compressed payloads preserved; no recursive member cleanup)
- Stable-ID selective cleanup for PNG tEXt/iTXt (per keyword) and PDF DocInfo
  (per Info key) is wired end to end through a per-file policy. Local PNG output
  is read back, reparsed, and verified; SAF reports best-effort attempted/
  unverified semantics until persisted readback is tested on device. PDF reports
  best-effort attempted/unverified semantics.
  Unsupported fields/formats fail closed per file. Anonymize, Preserve
  Technical, and granular cleanup for other formats remain unavailable.
- Output naming: collision-safe `_clean`, `_clean_1`, …; SAF content:// write

- BMP removal for strict canonical 24/32-bit Windows BITMAPINFOHEADER, BI_RGB,
  positive dimensions, and `bfOffBits == 54`: header/pixel payload bytes are
  preserved, reserved fields are zeroed, size fields are normalized, and
  trailing bytes are discarded. This is not comprehensive BMP sanitization.
  TIFF/TIF removal remains disabled pending a future structural writer/POC.

**Deferred / out of scope:**
- Video (MP4/MKV/AVI/WebM/3GP/FLV/WMV) — `ffmpeg_kit_flutter_full_gpl` retired
  upstream and breaks on Flutter ≥3.29; alternative is a pure-Dart container
  parser, deferred to a follow-up
- HEIC/HEIF extraction — requires HEIF container parser, deferred
- APK and EPUB removal — unsupported; APK stripping would invalidate the signing
  block. ZIP-only container cleanup is implemented and is not recursive.
- Audio selective strip (MP3 frame-level, Vorbis per-key) — parameter
  plumbing shipped, stripper implementation pending
- Granular Office property removal — current Office strippers perform
  format-level property cleanup rather than per-property selection
- PDF XMP packet stripping — Info-only removal today (best-effort)

### Phase 3: Viewer UI — Implemented-scope MVP Complete
- ViewerCubit: file add, mark/unmark, sort (name/size/type/newest), filter
- Multi-file picker integration with dedup + extension filter
- File list items with extension badge + privacy warning
- Metadata detail screen: grouped accordion sections, selectable fields
- Copy field value to clipboard
- Mark visible / clear marks / send marked to Remover handoff
- Empty state widget

### Phase 4: Remover UI — Implemented-scope MVP Complete + Security Hardening
- RemoverBloc: sequential processing, queue cap, cancel, reset
- RemoverScreen: direct remover file picking with the registered extension
  filter, file queue with supported-cleanup status, process button; the
  broader mode selector remains planned/unwired
- Remover-wide 50 MB input cap is named as
  `AppConstants.maxRemoverFileSizeBytes`; it is enforced both when files enter
  the queue and during actual pre-processing validation
- Pre-processing validation checks the current local filesystem entry rather
  than trusting picker metadata (present regular file, supported extension,
  and current size)
- ProcessingScreen: live progress bar + per-file status + cancel
- ResultScreen: 4-tile stats grid + per-file output list + Done
- Viewer field selection can enqueue PNG/PDF files with a stable-ID selective
  policy; result summaries consume `StripReport` removal/absence/warning facts
- **JPEG scrubber:** preserves APP0/JFIF and drops APP1/APP2/APP12/APP13/APP14/COM; EOI truncation
- **PNG scrubber:** drops text chunks + tIME + eXIf
- **PDF scrubber:** DocInfo blanking (best-effort) — linear scanner
- Output: collision-safe naming (`_clean`, `_clean_1`, etc.)
- SAF output writing for `content://` URIs via `Saf().writeFileBytes()`
- Error sanitization (strips filesystem paths from messages)
- Android package fix: `MainActivity.kt` → `com.bariskode.metastrip`

**Remover verification:** contract tests assert the exact 20-extension registry
and datasource routing. Integration-style tests use the real remover pipeline
to verify clean-copy output, preservation of the original, and no output for
malformed input. This is host-side verification only; Android device and SAF
picker/output smoke testing remains required, and no device validation is
claimed.

### Phase 5: Settings — Implemented-scope MVP Complete (2026-08-07)
- App-level SettingsCubit with SharedPreferences-backed persistence and serialized operations
- 7 preset themes plus a custom 16-token theme builder; theme changes apply live
- Output-folder changes are validated and synchronized with onboarding/removal state
- Portable JSON export excludes the device-local output path; import preserves and validates the current device folder
- Two-step reset clears app configuration and onboarding state, then returns to onboarding; generated clean copies/output files remain untouched
- Cache status/action (currently a 0-byte no-op), About, version, and Licenses are wired
- Naming/folder-structure/keep-original and JPEG-quality/concurrency/auto-confirm fields persist for import compatibility, but their controls are not exposed or wired to processing

### Security & Correctness Hardening (2026-08-07)
- ZIP package preflight now parses raw EOCD/central-directory records before
  `ZipDecoder`, rejecting ZIP64/multi-disk input, encryption, unsupported
  compression, symlinks, unsafe/duplicate paths, malformed local records, and
  excessive entry counts. Structural validation is separate from repack-only
  size policy, so Viewer can inspect bounded metadata without decompressing
  unrelated large entries.
- ZIP decompression uses a bounded output sink followed by exact-size and CRC
  checks for Viewer ZIP/OpenXML/ODF decoding. ZIP container cleanup preserves
  compressed payloads and only checks structural CRC-field consistency; it does
  not verify payload CRCs. The in-memory repacker has a 32 MiB total
  decompressed-content budget and a 50 MiB input cap. Device/SAF and stress
  validation remain pending, so these are safety bounds rather than demonstrated
  performance limits.
- OOXML cleanup validates bounded semantic content types for Transitional and
  Strict DOCX/XLSX/PPTX packages, removes the union of validated root-relationship
  targets and normalized conventional Viewer-visible property paths, rejects
  unsafe/ambiguous targets, and removes dangling relationship/content-type
  declarations. ODF cleanup requires and preserves a physical first, stored,
  exact `mimetype` entry.
- PDF extractor: replaced non-greedy `obj...endobj` regex scan with a
  bounded linear scan (max 64 regions, 1MB window) — no quadratic hang
- PDF removal: replaced regex-over-whole-document with a single-pass linear
  byte scanner — no `(?:\\\.|[^)])*` overlap → no ReDoS on hostile backslash
  floods
- PDF technology-spike hardening: generated bytes are checked with bounded
  same-length mutation validation; the scrubber and validator share a balanced
  literal parser, with malformed recognized-value and key-candidate caps. The
  bounded Info scan fails closed when either limit is breached. Reports remain
  `attemptedUnverified` with `outputValidated: false`; no persisted output
  readback or PDF structural claims are made.
- Zip path consistency: shared `normalizeEntryPath` (collapse slashes,
  strip `.` segments, `\` → `/`) supports structural duplicate and traversal
  rejection; OOXML cleanup uses relationship-resolved exact paths.
- Honest SHA-256 for bounded-read audio (full-file hash via second isolate
  read); hash cache bounded to 512 entries
- ID3 synchsafe mask consistency (`& 0x7F`) between extractor and stripper
- PNG tEXt/iTXt keyword labels truncated like values

## Not Started

### Phase 6: Polish & Testing — Release-readiness work

## Verification Snapshot (2026-08-09)

**Final host verification:**
- `flutter analyze`: clean (0 issues)
- `flutter test`: 390 tests completed; 389 passed, 1 skipped
- Test coverage: not measured in this verification run
- Debug APK: passed (`build\app\outputs\flutter-apk\app-debug.apk`)
- Diff check: passed
- Local PNG persisted output is verified. SAF persisted-artifact read-back and
  Android/iOS device tests remain scheduled/pending. PDF selective cleanup
  remains attempted/unverified.
- These checks do not establish full product-spec completion or release
  readiness. ZIP stress testing, integration/device testing, performance,
  accessibility, and release-build verification remain outstanding.

## Dependencies

**Installed:** flutter_bloc, bloc, equatable, shared_preferences, path_provider, file_picker, path, mime, archive, xml, exif, image, lucide_icons_flutter, flutter_colorpicker, shimmer, lottie, crypto, convert, intl, file_selector, saf, cupertino_icons

**Planned (Phase 6/follow-ups):** sqflite, permission_handler, cached_network_image, logger, dartz, share_plus, receive_sharing_intent, flutter_local_notifications

**Deliberately not added:**
- `ffmpeg_kit_flutter_full_gpl` — retired upstream; breaks on Flutter ≥3.29.
  Replaced by a deferred pure-Dart video container parser.
- `syncfusion_flutter_pdf` — would require commercial or community license
  key. Replaced by a pure-Dart Info dictionary parser + bounded linear XMP
  packet scanner.
- `id3_codec` — replaced by the manual ID3v2/ID3v1 parser in
  `extractors/id3_extractor.dart`.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

Android release builds additionally require `KEYSTORE_PATH`,
`KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD` in the environment. Keep
the keystore and credential values outside the repository.
