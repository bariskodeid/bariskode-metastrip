# MetaStrip MVP Progress Report

**Snapshot:** 2026-08-07  
**Overall:** Phases 1-5 MVP done; Phase 0 is 10/11; Phase 2 follow-ups and Phase 6 remain  
**Device:** Samsung SM M205G (Android 8.1), serial `3201fbb0c40a1615`

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

### Phase 2: Metadata Engine — MVP Complete for Implemented Formats (2026-08-07)
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
- GIF (comment extension), WebP (EXIF/XMP RIFF chunks), BMP (status only)
- Isolate-worker extraction while the app is foregrounded (single
  `runOnWorker` for parse + hash); OS background execution is not wired

**Done (removal, 18 extensions):**
- JPEG/PNG scrubbers, PDF linear-scanner DocInfo stripper (9 keys incl.
  `Trapped`)
- New strippers: ID3 (synchsafe masked), Vorbis (FLAC block drop + OGG
  in-place comment rewrite with Ogg CRC recompute), RIFF (WAV/AIFF),
  OpenXML (zip repack without `docProps/{core,app,custom}.xml`),
  ODF (zip repack without `meta.xml`), GIF (comment + XMP app-extension),
  WebP (EXIF/XMP chunk + VP8X flag clear)
- Limited selector parameters for PNG tEXt/iTXt (per keyword) and PDF DocInfo
  (per Info key); null/empty uses the current supported-cleanup behavior. The
  general Selective mode UI remains unavailable.
- Output naming: collision-safe `_clean`, `_clean_1`, …; SAF content:// write

**Deferred / out of scope:**
- Video (MP4/MKV/AVI/WebM/3GP/FLV/WMV) — `ffmpeg_kit_flutter_full_gpl` retired
  upstream and breaks on Flutter ≥3.29; alternative is a pure-Dart container
  parser, deferred to a follow-up
- HEIC/HEIF extraction — requires HEIF container parser, deferred
- Archive removal (ZIP/APK stripping) — APK stripping would invalidate the
  signing block; out of MVP strip scope
- Audio selective strip (MP3 frame-level, Vorbis per-key) — parameter
  plumbing shipped, stripper implementation pending
- Granular Office property removal — current Office strippers perform
  format-level property cleanup rather than per-property selection
- PDF XMP packet stripping — Info-only removal today (best-effort)

### Phase 3: Viewer UI — MVP Complete
- ViewerCubit: file add, mark/unmark, sort (name/size/type/newest), filter
- Multi-file picker integration with dedup + extension filter
- File list items with extension badge + privacy warning
- Metadata detail screen: grouped accordion sections, selectable fields
- Copy field value to clipboard
- Mark visible / clear marks / send marked to Remover handoff
- Empty state widget

### Phase 4: Remover UI — MVP Complete + Security Hardening
- RemoverBloc: sequential processing, queue cap, cancel, reset
- RemoverScreen: file queue with supported-cleanup status, process button; the
  broader mode selector remains planned/unwired
- ProcessingScreen: live progress bar + per-file status + cancel
- ResultScreen: 4-tile stats grid + per-file output list + Done
- **JPEG scrubber:** preserves APP0/JFIF and drops APP1/APP2/APP12/APP13/APP14/COM; EOI truncation
- **PNG scrubber:** drops text chunks + tIME + eXIf
- **PDF scrubber:** DocInfo blanking (best-effort) — linear scanner
- Output: collision-safe naming (`_clean`, `_clean_1`, etc.)
- SAF output writing for `content://` URIs via `Saf().writeFileBytes()`
- Error sanitization (strips filesystem paths from messages)
- Android package fix: `MainActivity.kt` → `com.bariskode.metastrip`

### Phase 5: Settings — MVP Complete (2026-08-07)
- App-level SettingsCubit with SharedPreferences-backed persistence and serialized operations
- 7 preset themes plus a custom 16-token theme builder; theme changes apply live
- Output-folder changes are validated and synchronized with onboarding/removal state
- Portable JSON export excludes the device-local output path; import preserves and validates the current device folder
- Two-step reset clears app configuration and onboarding state, then returns to onboarding; generated clean copies/output files remain untouched
- Cache status/action (currently a 0-byte no-op), About, version, and Licenses are wired
- Naming/folder-structure/keep-original and JPEG-quality/concurrency/auto-confirm fields persist for import compatibility, but their controls are not exposed or wired to processing

### Security & Correctness Hardening (2026-08-07)
- Zip decompression-bomb guard: shared `decodeArchiveFileSafely` caps
  per-entry decompression at 64MB (declared + real) and 128MB cumulative
  before any `entry.content` access — oversized entries degrade to status
  fields instead of OOM on mobile
- Zip repack hardening: per-entry cap (declared + actual) and actual-content
  total cap; exception messages no longer embed hostile entry names
- PDF extractor: replaced non-greedy `obj...endobj` regex scan with a
  bounded linear scan (max 64 regions, 1MB window) — no quadratic hang
- PDF removal: replaced regex-over-whole-document with a single-pass linear
  byte scanner — no `(?:\\\.|[^)])*` overlap → no ReDoS on hostile backslash
  floods
- Zip path consistency: shared `normalizeEntryPath` (collapse slashes,
  strip `.` segments, `\` → `/`) used by viewer extractor and remover
  stripper with exact-or-suffix matching — closes silent strip-failure
  for non-canonical paths
- Honest SHA-256 for bounded-read audio (full-file hash via second isolate
  read); hash cache bounded to 512 entries
- ID3 synchsafe mask consistency (`& 0x7F`) between extractor and stripper
- PNG tEXt/iTXt keyword labels truncated like values

## Not Started

### Phase 6: Polish & Testing

## Verification (2026-08-07)
- `flutter analyze`: clean (0 issues)
- `flutter test`: **248 passed, 1 skipped**
- Test coverage: not measured in this verification run
- Debug APK: builds (`build\app\outputs\flutter-apk\app-debug.apk`)

## Dependencies

**Installed:** flutter_bloc, bloc, equatable, shared_preferences, path_provider, file_picker, path, mime, archive, exif, image, lucide_icons_flutter, flutter_colorpicker, shimmer, lottie, crypto, convert, intl, file_selector, saf, cupertino_icons

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
