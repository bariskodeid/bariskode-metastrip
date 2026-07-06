# Changelog

All notable changes to MetaStrip project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase 4: Remover UI — DONE ✅ (2026-07-06)

#### Added
- `RemoverBloc` (Bloc, not Cubit) with sequential file processing, progress
  streaming, and cancel support — mirrors the Viewer cubit pattern.
- `RemoverEvent`/`RemoverState` with `RemoverStatus` enum
  (idle/processing/completed/cancelled), `ProcessingProgress`, and
  `ProcessingResultEntity` (success/failure with bytes written).
- `RemoverRepository` domain interface + `RemoverRepositoryImpl` data layer
  that wraps the existing datasource and converts exceptions to failure
  results so a single bad file never crashes the batch.
- `ProcessingScreen`: full-screen modal with live `LinearProgressIndicator`,
  reverse-scroll result log, and a CANCEL button.
- `ResultScreen`: 4-tile stats grid (stripped/failed/total/bytes written)
  plus per-file output path list and a DONE button that pops to root.
- `RemoverScreen` refactored from `StatefulWidget` to `BlocProvider`;
  acts as the composition root (constructs `RemoverRepositoryImpl` and
  injects into the Bloc) so the Bloc only depends on the domain interface.
- Shared `RemoverStrippableExtensions` constant in `core/constants/` —
  single source of truth for which formats the remover can strip
  (consumed by both the datasource switch and the queue UI gate).
- BLoC unit tests (8 cases): dedup, queue cap, remove, clear, sequential
  processing, failure handling, cancel, reset.

#### Security Hardening
- JPEG scrubber now drops APP2 (ICC color profile — device fingerprint
  vector) and APP14 (Adobe markers) in addition to APP1/APP12/APP13/COM.
- PNG scrubber now drops `tIME` (last-modified timestamp) in addition to
  `tEXt`/`zTXt`/`iTXt`/`eXIf`.
- Error messages from the repository are sanitized: known exception types
  map to opaque messages, and absolute filesystem paths are stripped via
  regex so layout is not disclosed in the UI (users may screenshot errors).
- Queue enforces `maxFilesPerSession` (50) with a user-facing skip message.
- Cancel is a direct `requestCancel()` method on the Bloc (not a queued
  event) so it can interrupt the processing loop without waiting on the
  Bloc's sequential event transformer.

#### Known Risks (carried forward)
- **PDF scrubber remains regex-based and unsafe** (XMP, object streams,
  JavaScript, and embedded files survive; binary may corrupt). This is
  the top-priority item for the next phase — see Phase 2 "pending" list.
- JPEG post-EOI appended data is still copied verbatim.
- TOCTOU window between `existsSync` check and `rename` on output write.
- Silent fallback to the input directory when the configured output folder
  is missing/unwritable (should surface a hard error instead).
- `FileItemEntity` still lives in the viewer feature; remover domain
  imports it — planned move to `shared/domain/`.

### Phase 1: Onboarding (Planned)
- Onboarding wizard with 5 slides
- Welcome screen with app branding
- Feature overview slides (Viewer & Remover)
- Output folder setup with directory picker
- Permission request handling
- Progress indicator dots
- Navigation logic with state persistence

### Phase 2: Core - Metadata Engine (Planned)
- Metadata extraction for 40+ file formats
- Image metadata (EXIF, IPTC, XMP)
- Video/Audio metadata (FFmpeg)
- Document metadata (PDF, Office formats)
- Metadata removal engine
- Isolate-based processing for performance

### Phase 3-6: UI & Features (Planned)
- Viewer UI with file list and detail screens
- Remover UI with queue and processing
- Settings screen with theme picker
- Polish, testing, and optimization

## [1.0.0] - 2025-01-XX

### Phase 0: Project Setup - COMPLETE ✅

#### Added
- Flutter project initialization (Flutter 3.41.7, Dart 3.11.5)
- Clean Architecture folder structure with feature-first organization
- Complete dependency configuration (50+ packages)
- Theme system with 7 color presets:
  - Dark Industrial (default)
  - Steel Blue
  - Acid Green
  - Rust
  - Mercury (light mode)
  - Neon Orange
  - Cobalt
- Typography system (Bebas Neue, Space Mono, IBM Plex Mono)
- Spacing system (4dp base unit)
- Shared widgets:
  - PrimaryButton
  - SecondaryButton
- App constants and configuration
- Basic smoke test
- Documentation:
  - README.md
  - SETUP_COMPLETE.md
  - CHANGELOG.md

#### Technical Details
- State Management: BLoC/Cubit
- Navigation: direct MaterialApp/Navigator MVP
- Dependency Injection: direct constructors MVP
- Local Storage: shared_preferences + path_provider
- File Operations: file_picker, archive
- Metadata Libraries: exif, image, custom JPEG/PNG/PDF MVP scrubbers
- UI: lucide_icons, flutter_colorpicker, shimmer, lottie

#### Testing
- Widget test framework setup
- Basic smoke test passing
- Flutter analyze: Clean (1 minor warning)

#### Known Issues
- Custom fonts not yet added (using system fonts as fallback)
- Assets folders created but empty
- Video/audio metadata dependencies deferred until feature implementation

---

## Project Milestones

- **2025-01-XX**: Phase 0 Complete - Project Foundation Ready
- **TBD**: Phase 1 Start - Onboarding Implementation
- **TBD**: Phase 2 Start - Metadata Engine
- **TBD**: Phase 3 Start - Viewer UI
- **TBD**: Phase 4 Start - Remover UI
- **TBD**: Phase 5 Start - Settings
- **TBD**: Phase 6 Start - Polish & Testing
- **TBD**: v1.0.0 Release

---

## Development Notes

### Sprint 0 - Foundation (Completed)
**Duration:** ~2 hours  
**Tasks Completed:** 11/11
- ✅ Flutter project init
- ✅ Folder structure setup
- ✅ Git setup
- ✅ pubspec.yaml configuration
- ✅ Theme system implementation
- ✅ Shared widgets
- ✅ DI setup preparation
- ✅ Router setup preparation
- ✅ SharedPreferences wrapper preparation
- ✅ Android permissions preparation
- ✅ iOS permissions preparation

**Next Sprint:** Sprint 1 - First Run Experience (1 week estimated)
