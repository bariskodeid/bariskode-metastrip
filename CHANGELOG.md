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

### Phase 2: Metadata Engine — Partial (2026-07-31)
**Status:** ~35% (JPEG/TIFF/PNG MVP done; audio/video/docs pending)

#### Done
- Supported extension allowlist and MIME lookup
- JPEG/TIFF EXIF extraction: GPS, camera, lens, timestamps, privacy flags
- PNG tEXt + uncompressed iTXt extraction
- SHA-256 hash computation (opt-in, size-guarded)
- Privacy field detection for GPS, author, device info

#### Pending
- Audio: ID3 (MP3), Vorbis Comments (FLAC/OGG), RIFF (WAV/AIFF)
- Video: FFmpeg-based extraction for MP4, MKV, AVI, WebM, etc.
- PDF: `syncfusion_flutter_pdf` DocInfo + XMP extraction
- Office: DOCX/XLSX/PPTX via archive + XML parsing
- Archives: ZIP/APK metadata parsing
- GIF, WebP, BMP, HEIC extractors
- Isolate-based background extraction

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
- RemoverScreen: file queue with mode selector, process button
- ProcessingScreen: live progress bar + per-file status + cancel
- ResultScreen: 4-tile stats grid + per-file output list + Done
- **JPEG scrubber:** drops APP0/APP1/APP2/APP12/APP13/APP14/COM; EOI truncation
- **PNG scrubber:** drops text chunks + tIME + eXIf
- **PDF scrubber:** DocInfo blanking (best-effort)
- Output: collision-safe naming (`_clean`, `_clean_1`, etc.)
- SAF output writing for `content://` URIs via `Saf().writeFileBytes()`
- Error sanitization (strips filesystem paths from messages)
- Android package fix: `MainActivity.kt` → `com.bariskode.metastrip`

### Phase 5: Settings — Not Started
**Status:** Scaffold only (empty directories)

- Settings Cubit, settings screen, theme picker, storage settings,
  processing settings, cache management, reset app data all pending

### Phase 6: Polish & Testing — Not Started
**Status:** Pending phases 1-5 completion

---

## Verification (2026-08-06)
- `flutter analyze`: clean (0 issues)
- `flutter test`: 66 passed, 1 skipped
- Debug APK: builds and installs to Samsung SM M205G (Android 8.1)
- Device serial: `3201fbb0c40a1615`

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
