# IMPLEMENTATION_PLAN.md — Technical Implementation Plan
## MetaStrip: Metadata Viewer & Remover
**Version:** 1.0.0  
**Stack:** Flutter 3.22+ / Dart 3.4+  
**Last Updated:** 2026-07-31

---

## 1. Project Architecture

### 1.1 Architecture Pattern
**Clean Architecture + Feature-first folder structure**

```
Presentation Layer  →  BLoC / Cubit
Domain Layer        →  Use Cases, Entities, Repository Interfaces
Data Layer          →  Repository Implementations, Data Sources, Models
```

Dipilih karena:
- Separation of concerns yang jelas untuk fitur kompleks (metadata parsing, file processing)
- Testability tinggi
- Scalable untuk penambahan format baru
- BLoC sudah mature di ekosistem Flutter

### 1.2 Folder Structure
```
lib/
├── app/
│   ├── app.dart                    # Root app widget, MaterialApp
│   ├── router.dart                 # deferred; MVP uses MaterialApp/Navigator
│   └── di/
│       └── injection.dart          # deferred; MVP uses direct constructors
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart      # Max files, default values
│   │   └── supported_extensions.dart  # Semua extension yang didukung
│   ├── errors/
│   │   ├── exceptions.dart         # Custom exception classes
│   │   └── failures.dart           # Failure sealed classes
│   ├── permissions/
│   │   └── permission_handler.dart # Wrapper permission_handler package
│   ├── storage/
│   │   └── local_storage.dart      # SharedPreferences wrapper
│   ├── utils/
│   │   ├── file_utils.dart         # Extension detection, MIME, size formatting
│   │   ├── date_utils.dart         # Date formatting
│   │   ├── hash_utils.dart         # MD5, SHA-256 computation
│   │   └── logger.dart             # Logging utility
│   └── theme/
│       ├── app_theme.dart          # ThemeData builder
│       ├── app_colors.dart         # Color token class + presets
│       ├── app_typography.dart     # TextStyle definitions
│       └── app_spacing.dart        # Spacing constants
│
├── features/
│   ├── onboarding/
│   │   ├── data/
│   │   │   └── onboarding_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/onboarding_state_entity.dart
│   │   │   ├── repositories/onboarding_repository.dart
│   │   │   └── usecases/
│   │   │       ├── complete_onboarding.dart
│   │   │       ├── get_onboarding_status.dart
│   │   │       └── set_output_folder.dart
│   │   └── presentation/
│   │       ├── cubit/onboarding_cubit.dart
│   │       ├── cubit/onboarding_state.dart
│   │       └── screens/
│   │           ├── onboarding_screen.dart       # PageView wrapper
│   │           ├── slides/
│   │           │   ├── slide_welcome.dart
│   │           │   ├── slide_viewer_feature.dart
│   │           │   ├── slide_remover_feature.dart
│   │           │   ├── slide_folder_setup.dart
│   │           │   └── slide_permissions.dart
│   │           └── widgets/
│   │               ├── onboarding_progress_dots.dart
│   │               └── permission_item_card.dart
│   │
│   ├── viewer/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── metadata_extractor_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── file_item_model.dart
│   │   │   │   └── metadata_model.dart
│   │   │   └── repositories/
│   │   │       └── viewer_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── file_item_entity.dart
│   │   │   │   ├── metadata_entity.dart
│   │   │   │   └── metadata_field_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── viewer_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_files_to_viewer.dart
│   │   │       ├── extract_metadata.dart
│   │   │       ├── mark_file_for_removal.dart
│   │   │       ├── mark_field_for_removal.dart
│   │   │       ├── remove_file_from_list.dart
│   │   │       └── compute_file_hash.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── viewer_bloc.dart
│   │       │   ├── viewer_event.dart
│   │       │   └── viewer_state.dart
│   │       ├── screens/
│   │       │   ├── viewer_screen.dart
│   │       │   └── metadata_detail_screen.dart
│   │       └── widgets/
│   │           ├── file_list_item.dart
│   │           ├── metadata_section_accordion.dart
│   │           ├── metadata_field_row.dart
│   │           ├── file_thumbnail.dart
│   │           ├── extension_badge.dart
│   │           ├── privacy_warning_badge.dart
│   │           ├── viewer_bottom_action_bar.dart
│   │           └── empty_viewer_state.dart
│   │
│   ├── remover/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── metadata_remover_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── removal_job_model.dart
│   │   │   │   └── processing_result_model.dart
│   │   │   └── repositories/
│   │   │       └── remover_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── removal_job_entity.dart
│   │   │   │   ├── removal_mode.dart              # enum
│   │   │   │   └── processing_result_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── remover_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_files_to_remover.dart
│   │   │       ├── set_removal_mode.dart
│   │   │       ├── process_files.dart
│   │   │       └── cancel_processing.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── remover_bloc.dart
│   │       │   ├── remover_event.dart
│   │       │   └── remover_state.dart
│   │       ├── screens/
│   │       │   ├── remover_screen.dart
│   │       │   ├── processing_screen.dart
│   │       │   └── result_screen.dart
│   │       └── widgets/
│   │           ├── remover_file_card.dart
│   │           ├── removal_mode_selector.dart
│   │           ├── processing_progress_card.dart
│   │           ├── processing_log_panel.dart
│   │           └── result_stats_grid.dart
│   │
│   └── settings/
│       ├── data/
│       │   └── repositories/
│       │       └── settings_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── app_settings_entity.dart
│       │   ├── repositories/
│       │   │   └── settings_repository.dart
│       │   └── usecases/
│       │       ├── get_settings.dart
│       │       ├── update_settings.dart
│       │       ├── clear_cache.dart
│       │       ├── reset_app_data.dart
│       │       ├── export_settings.dart
│       │       └── import_settings.dart
│       └── presentation/
│           ├── cubit/
│           │   ├── settings_cubit.dart
│           │   └── settings_state.dart
│           ├── screens/
│           │   ├── settings_screen.dart
│           │   └── theme_picker_screen.dart
│           └── widgets/
│               ├── settings_section_header.dart
│               ├── settings_tile.dart
│               ├── theme_preset_card.dart
│               └── color_picker_row.dart
│
├── shared/
│   ├── widgets/
│   │   ├── app_bar_custom.dart
│   │   ├── primary_button.dart
│   │   ├── secondary_button.dart
│   │   ├── destructive_button.dart
│   │   ├── custom_checkbox.dart
│   │   ├── custom_switch.dart
│   │   ├── custom_progress_bar.dart
│   │   ├── bottom_sheet_handle.dart
│   │   ├── section_divider.dart
│   │   ├── status_badge.dart
│   │   └── confirmation_dialog.dart
│   └── services/
│       ├── file_picker_service.dart   # Wrapper file_picker
│       ├── share_intent_service.dart  # Handle incoming share
│       ├── notification_service.dart  # Local notifications
│       └── cache_service.dart         # Thumbnail cache management
│
└── main.dart
```

---

## 2. Dependencies (pubspec.yaml)

```yaml
name: metastrip
description: Metadata Viewer & Remover — strip the invisible, own your files.
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'
  flutter: '>=3.22.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_bloc: ^8.1.5
  bloc: ^8.1.4
  equatable: ^2.0.5

  # Local Storage
  shared_preferences: ^2.3.1
  sqflite: ^2.3.3+1
  path_provider: ^2.1.3

  # File Operations
  file_picker: ^8.0.6
  path: ^1.9.0
  mime: ^1.0.5
  archive: ^3.6.0          # ZIP, TAR parsing

  # Metadata — Images
  exif: ^3.3.0              # JPEG/TIFF/RAW EXIF
  image: ^4.2.0             # PNG, GIF, BMP, WebP parsing

  # Metadata — Audio
  id3_codec: ^1.1.1         # ID3 tags for MP3
  # Vorbis Comments: custom parser

  # Metadata — Video & Audio (ffmpeg)
  ffmpeg_kit_flutter_full_gpl: ^6.0.3  # Full GPL build dengan semua codec

  # PDF
  syncfusion_flutter_pdf: ^25.1.37    # PDF metadata read/write

  # Permissions
  permission_handler: ^11.3.1

  # UI / Design
  lucide_icons_flutter: ^1.0.1    # Icon set
  flutter_colorpicker: ^1.1.0     # HSL color picker
  cached_network_image: ^3.3.1    # (untuk map tiles jika pakai online map)
  shimmer: ^3.0.0                 # Loading shimmer effect
  lottie: ^3.1.2                  # Onboarding animations (opsional)

  # Utilities
  crypto: ^3.0.3             # MD5, SHA-256 hashing
  convert: ^3.1.1            # Encoding utilities
  intl: ^0.19.0              # Localization, date formatting
  logger: ^2.3.0             # Debug logging
  dartz: ^0.10.1             # Functional programming (Either, Option)

  # Share & Intent
  share_plus: ^9.0.0         # Share files out
  receive_sharing_intent: ^1.8.0  # Receive files from other apps

  # Notifications
  flutter_local_notifications: ^17.2.2

  # Directory picker
  file_selector: ^1.0.3      # Cross-platform folder/file selection

dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^9.1.7
  flutter_lints: ^4.0.0
  very_good_analysis: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
    - assets/illustrations/
    - assets/icons/
    - assets/textures/

  fonts:
    - family: BebasNeue
      fonts:
        - asset: assets/fonts/BebasNeue-Regular.ttf
    - family: SpaceMono
      fonts:
        - asset: assets/fonts/SpaceMono-Regular.ttf
        - asset: assets/fonts/SpaceMono-Bold.ttf
          weight: 700
        - asset: assets/fonts/SpaceMono-Italic.ttf
          style: italic
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
        - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/IBMPlexMono-Italic.ttf
          style: italic
```

---

## 3. Development Phases & Sprint Plan

### Implementation Status (updated 2026-07-31)

Done:
- [x] **Phase 0 MVP foundation: 90.9% complete (10/11 roadmap tasks).** The only deferred task is dev/prod flavor configuration; flavors are deliberately unnecessary for the current single-binary MVP.
- [x] App composition root initializes the storage abstraction and wires repositories/use cases with direct constructor injection. A DI container and declarative router remain intentional post-MVP options, not missing foundation work.
- [x] Startup initialization is retryable; onboarding persistence and the configured output folder are accessed through the local-storage abstraction.
- [x] Output handling validates the configured folder before processing, fails clearly when it is unavailable, and reserves collision-free output paths without the previous check-then-write race. Originals remain untouched.
- [x] Android/iOS use system file pickers and app-scoped access; no broad storage or media permissions are requested.
- [x] Foundation verification: `flutter analyze` is clean; `flutter test` reports 65 passed and 1 skipped.
- [ ] Debug APK verification is blocked: Gradle dependency downloads from `dl.google.com` failed with TLS `bad_record_mac`/tag-mismatch errors. No successful APK build is claimed for this snapshot.
- [x] Phase 1 partial onboarding: 5-slide onboarding UI, slide navigation, output folder picker, permission request UI, completion flag redirect.
- [x] Phase 2 partial metadata engine: supported extension allowlist, basic filesystem metadata extraction, MIME lookup, SHA-256 hash computation.
- [x] Phase 3 partial Viewer UI: Viewer Cubit, multi-file picker, extension filter, dedup, size/session validation, file list item, extension badge, empty state, metadata detail scaffold, grouped metadata fields, unit/widget tests.
- [x] Viewer iteration 2026-05-19: metadata detail widget test, Viewer sort/filter by name/size/type/newest, JPEG/TIFF EXIF MVP with privacy-sensitive field detection and size guard.
- [x] Viewer iteration 2026-05-19b: PNG `tEXt`/uncompressed `iTXt` metadata MVP, copy metadata value to clipboard, mark visible/clear marks/send marked handoff stub for Remover.
- [x] Remover iteration 2026-05-20: real Viewer → Remover handoff screen, JPEG/PNG/PDF strip MVP writing `_clean` copy to configured output folder when writable, hash opt-in + in-memory cache.
- [x] **Phase 4 Remover UI (2026-07-06): RemoverBloc + events/states (sequential processing, cancel via direct method, queue cap `maxFilesPerSession`), ProcessingScreen with live progress + result log, ResultScreen with stats grid (stripped/failed/total/bytes), RemoverScreen refactored to BlocProvider with repo injection at composition root, error message sanitization (path stripping), shared `RemoverStrippableExtensions` constant.**
- [x] **Security hardening (2026-07-06): JPEG scrubber now drops APP2 (ICC color profile) + APP14 (Adobe) in addition to APP1/APP12/APP13/COM; PNG scrubber now drops `tIME` (edit timestamp) in addition to text chunks/eXIf; error strings sanitized to strip absolute filesystem paths.**

Still pending:
- [ ] Dev/prod flavors (the remaining Phase 0 roadmap task) when separate environments are actually needed.
- [ ] DI container and declarative router only if app complexity outgrows the intentional manual-constructor/`MaterialApp`/`Navigator` MVP approach.
- [ ] **PDF removal remains best-effort DocInfo blanking. XMP packets, object streams, JavaScript, embedded files, and other metadata may survive; use a structural PDF parser before making comprehensive-removal claims. (CRITICAL)**
- [ ] More format-specific metadata extractors/removers beyond JPEG/TIFF EXIF + PNG text + JPEG/PNG/PDF remover MVP.
- [ ] Viewer thumbnails, share intent, settings screen, e2e hardening.
- [ ] Move `FileItemEntity` to `shared/domain/` to remove remover→viewer cross-feature coupling.
- [ ] Release hardening (crash reporting, signing, obfuscation).

### Phase 0: Project Setup (1 minggu)
**Sprint 0 — Foundation**

**Status:** 90.9% complete (10/11). Dev/prod flavors are deliberately deferred for the single-binary MVP. Manual constructor injection and `MaterialApp`/`Navigator` routing are intentional MVP decisions; the composition root owns storage initialization and dependency wiring.

| Status | Task | Current implementation | Est. |
|--------|------|------------------------|------|
| [x] | Flutter project init | Android/iOS project initialized | 1h |
| [x] | Folder structure setup | Clean Architecture, feature-first structure | 1h |
| [x] | Git setup | Repository and ignore rules configured | 30m |
| [x] | `pubspec.yaml` | MVP dependencies configured | 1h |
| [x] | Theme system | `AppColors`, `AppTheme`, `AppTypography`, and spacing | 4h |
| [x] | Shared widgets | MVP shared controls and feedback widgets | 8h |
| [x] | DI setup | Intentional direct constructors wired at the composition root; container deferred | 2h |
| [x] | Router setup | Intentional `MaterialApp`/`Navigator` flow; declarative router deferred | 2h |
| [x] | Storage setup | Abstract local storage backed by SharedPreferences; retryable startup initialization | 2h |
| [x] | Platform file access | System picker/app-scoped access on Android and iOS; no broad permissions | 3h |
| [ ] | Dev/prod flavors | Deliberately deferred until separate environments are needed | 1h |

Foundation hardening also validates the output folder before use and safely reserves collision-free clean-copy paths. Verification for this snapshot is 65 tests passed, 1 skipped, and a clean analyzer. Debug APK build verification remains blocked by TLS `bad_record_mac`/tag-mismatch failures while Gradle downloads from `dl.google.com`.

---

### Phase 1: Onboarding (1 minggu)
**Sprint 1 — First Run Experience**

| Task | Detail | Est. |
|------|--------|------|
| Onboarding Cubit | State: `slideIndex`, `folderPath`, `permissionsStatus` | 3h |
| Slide 1 — Welcome | Full UI, Bebas Neue title, animations | 3h |
| Slide 2 — Viewer Feature | Ilustrasi SVG + description | 2h |
| Slide 3 — Remover Feature | Ilustrasi SVG + description | 2h |
| Slide 4 — Folder Setup | DirectoryPicker integration, path display | 4h |
| Slide 5 — Permissions | Per-permission card, grant/deny handling | 6h |
| Progress dots widget | Animated dots dengan active state | 2h |
| Navigation logic | Back/next/skip dengan state persistence | 2h |
| Onboarding complete flag | `SharedPreferences`, redirect logic di splash | 2h |
| Edge cases | Permission denied flow, folder not set fallback | 3h |

---

### Phase 2: Core — Metadata Engine (2 minggu)
**Sprint 2 — Metadata Extraction**

| Task | Detail | Est. |
|------|--------|------|
| File detection | MIME + extension → format category routing | 4h |
| Image EXIF extractor | `exif` package, GPS decode, datetime parse — **MVP done: raw JPEG/TIFF EXIF fields + privacy flags + size guard** | 8h |
| Image PNG/GIF/WebP extractor | `image` package, text chunks — **MVP done: PNG tEXt + uncompressed iTXt fields; GIF/WebP pending** | 4h |
| Audio ID3 extractor | `id3_codec`, album art handling | 6h |
| Audio FLAC/Vorbis extractor | Custom binary parser | 8h |
| Audio WAV/AIFF extractor | RIFF chunk parser | 4h |
| Video/Audio ffmpeg extractor | `ffmpeg_kit`, parse JSON output | 6h |
| PDF metadata extractor | `syncfusion_flutter_pdf` | 4h |
| DOCX/XLSX/PPTX extractor | `archive` + XML parsing (Open XML spec) | 8h |
| ODT/ODS/ODP extractor | `archive` + `meta.xml` parsing | 4h |
| ZIP/APK extractor | `archive` + manifest parsing | 4h |
| File system metadata | `File` stats, path info | 2h |
| Hash computation | MD5 + SHA-256 via `crypto` (isolate) — **MVP done: SHA-256 opt-in + memory cache; isolate pending** | 4h |
| Metadata entity unification | Normalize semua format ke `MetadataEntity` | 6h |
| Privacy field detection | Flag GPS, author, device info fields | 3h |
| Unit tests — extractors | Test per format dengan sample files | 8h |

**Sprint 3 — Metadata Removal**

| Task | Detail | Est. |
|------|--------|------|
| Removal mode enum | `FullStrip`, `Selective`, `Anonymize`, `PreserveTechnical` | 1h |
| Image JPEG remover | Re-encode dengan stripped EXIF (lossless path) — **MVP done: strip APP1/APP13/APP12/COM to `_clean` copy** | 8h |
| Image PNG remover | Rebuild PNG tanpa text chunks | 6h |
| Image WebP/GIF remover | Strip metadata via `image` package | 4h |
| Audio MP3 remover | Rebuild ID3 tanpa target tags | 6h |
| Audio FLAC/Vorbis remover | Rebuild STREAMINFO + cleared comments | 6h |
| Audio WAV remover | Rebuild RIFF tanpa INFO chunk | 4h |
| Video remover | `ffmpeg_kit` remux: `-map_metadata -1 -c copy` | 6h |
| PDF remover | `syncfusion_flutter_pdf` clear DocInfo + XMP | 4h |
| DOCX/XLSX/PPTX remover | Repack ZIP dengan cleared core.xml + app.xml | 8h |
| Output naming logic | Template processing, auto-increment | 3h |
| Selective strip logic | Field-level filtering per file | 6h |
| Background isolate | Move heavy processing ke Dart isolate | 6h |
| Progress reporting | Stream-based progress dari isolate ke UI | 4h |
| Error handling | Per-file, partial batch, retry logic | 4h |
| Integration tests — removal | Verify metadata benar-benar hilang dari output | 8h |

---

### Phase 3: Viewer UI (1.5 minggu)
**Sprint 4 — Viewer Screen**

| Task | Detail | Est. |
|------|--------|------|
| Viewer BLoC | Events, States, full logic | 6h |
| File picker integration | Multi-select, extension filter, dedup | 4h |
| Share intent receiver | Handle file dari app lain via `receive_sharing_intent` | 4h |
| File list item widget | Thumbnail, info, badges, actions | 5h |
| Thumbnail generation | Image: native, Video: ffmpeg frame extract, Others: icon | 6h |
| Thumbnail cache | Disk cache dengan size management | 4h |
| Filter & sort | By name/size/date/type, persist preference — **MVP done: name/size/type/newest + query filter; persistence pending** | 4h |
| Select all / batch actions | Multi-select state, mark batch, remove batch — **MVP done: mark visible/clear/send marked stub** | 4h |
| Bottom action bar | Animated appearance saat ada file | 2h |
| Empty state | SVG illustration + CTA | 2h |

**Sprint 5 — Metadata Detail Screen**

| Task | Detail | Est. |
|------|--------|------|
| Detail screen scaffold | App bar, scroll, header card — **done MVP** | 3h |
| Accordion sections | 10 sections, expand/collapse animation — **done MVP: grouped expansion sections** | 6h |
| Metadata field row | Key-value, copy gesture, warning icon — **done MVP: selectable values + warning icon** | 4h |
| GPS map preview | Static map tile (OpenStreetMap) untuk koordinat GPS | 4h |
| Raw metadata section | Flat key-value dump dari semua fields | 3h |
| Mark/unmark per file | State sync dengan viewer BLoC | 3h |
| Per-field selective mark | Checkbox per field, selective strip state | 6h |
| Copy actions | Clipboard + snackbar feedback — **done MVP: per-field copy value** | 2h |
| Share metadata | Export sebagai text/JSON | 3h |

---

### Phase 4: Remover UI (1 minggu)
**Sprint 6 — Remover Screen & Processing**

| Task | Detail | Est. |
|------|--------|------|
| Remover BLoC | Events, States, full logic — **done MVP: RemoverBloc with sequential processing, cancel via direct method, queue cap** | 6h |
| Remover queue list | File cards dengan mode selector — **done MVP: receive marked files + strippable status per file** | 5h |
| Removal mode selector | Chip group + per-file override | 4h |
| Add files (direct) | File picker + share intent | 2h |
| Receive from Viewer | Navigate + pass marked files — **done MVP via Navigator extra object list** | 2h |
| Processing screen | Full-screen modal, progress, log — **done MVP: ProcessingScreen with live progress bar + result log + cancel** | 8h |
| Log panel | Expandable, real-time updates dari stream — **done MVP: reverse-scroll result log in ProcessingScreen** | 4h |
| Cancel processing | Graceful cancellation via token — **done MVP: requestCancel() direct method, per-file granularity** | 3h |
| Result screen | Stats grid, fail list, action buttons — **done MVP: ResultScreen with 4-tile stats grid + per-file output list + Done** | 5h |
| Open output folder | Intent ke file manager pada path output | 2h |
| Share output files | `share_plus` multi-file share | 2h |
| Background processing | `flutter_local_notifications` saat ke the background | 4h |

---

### Phase 5: Settings (0.5 minggu)
**Sprint 7 — Settings**

| Task | Detail | Est. |
|------|--------|------|
| Settings Cubit | Load/save ke SharedPreferences | 4h |
| Settings screen scaffold | Grouped sections dengan headers | 3h |
| Color theme settings | Navigate ke theme picker, apply live | 2h |
| Theme picker screen | 8 presets + custom picker, live preview | 8h |
| Output folder setting | DirectoryPicker, display + change | 2h |
| Storage settings | Structure, naming template, keep original | 3h |
| Processing settings | JPEG quality slider, concurrent files, auto-confirm | 3h |
| Clear cache | Compute cache size, delete, snackbar | 3h |
| Reset app data | 2-step confirmation, clear all, restart to onboarding | 3h |
| Export/import settings | JSON serialization, file I/O | 4h |
| About screen | Version info, links | 2h |
| Licenses screen | `showLicensePage` Flutter built-in | 1h |

---

### Phase 6: Polish & Testing (1 minggu)
**Sprint 8 — QA & Polish**

| Task | Detail | Est. |
|------|--------|------|
| Unit tests — all BLoCs | 80%+ coverage | 12h |
| Widget tests — key screens | Viewer, Remover, Detail | 8h |
| Integration tests | Full flow end-to-end | 6h |
| Performance profiling | Memory, CPU, frame drops | 4h |
| Accessibility audit | Semantic labels, contrast, touch targets | 4h |
| Edge case handling | Large files, corrupt files, storage full | 4h |
| Animation polish | Timing, easing, stagger refinement | 4h |
| Empty states polish | SVG finalization | 2h |
| Onboarding polish | Transition smoothness | 2h |
| Dark theme consistency | Review semua screen di semua tema | 3h |
| Android 14 compatibility | Scoped storage, granular media permissions | 3h |
| iOS testing | Permission flow, file access | 3h |
| Crash reporting setup | (Sentry atau Firebase Crashlytics) | 2h |
| Build & release prep | `flutter build apk --release`, signing, obfuscation | 3h |

---

## 4. Key Technical Implementations

### 4.1 Metadata Extraction — Core Flow
```dart
// lib/features/viewer/data/datasources/metadata_extractor_datasource.dart

abstract class MetadataExtractorDatasource {
  Future<MetadataModel> extract(File file);
}

class MetadataExtractorDatasourceImpl implements MetadataExtractorDatasource {
  
  @override
  Future<MetadataModel> extract(File file) async {
    final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
    final fileSystemMeta = await _extractFileSystemMeta(file);
    
    try {
      final formatMeta = await _extractByFormat(file, extension);
      return MetadataModel.merge(fileSystemMeta, formatMeta);
    } catch (e) {
      // Format-specific extraction failed, return file system meta only
      return MetadataModel(
        fileSystemMeta: fileSystemMeta,
        error: MetadataExtractionError(file: file.path, message: e.toString()),
      );
    }
  }

  Future<FormatMetadata?> _extractByFormat(File file, String ext) async {
    return switch (ext) {
      'jpg' || 'jpeg' || 'tiff' || 'tif' || 'heic' || 'heif' ||
      'raw' || 'cr2' || 'nef' || 'arw' || 'dng' => _extractExif(file),
      
      'png' || 'gif' || 'bmp' || 'webp'          => _extractImagePackage(file),
      
      'mp3'                                        => _extractId3(file),
      'flac' || 'ogg' || 'opus'                   => _extractVorbis(file),
      'wav' || 'aiff'                              => _extractRiffChunks(file),
      
      'mp4' || 'm4v' || 'mov' || 'avi' || 'mkv' ||
      'webm' || '3gp' || 'flv' || 'wmv' ||
      'm4a' || 'aac' || 'wma'                     => _extractFfmpeg(file),
      
      'pdf'                                        => _extractPdf(file),
      
      'docx' || 'xlsx' || 'pptx'                  => _extractOpenXml(file),
      'odt' || 'ods' || 'odp'                     => _extractOdf(file),
      'doc' || 'xls' || 'ppt'                     => _extractLegacyOffice(file),
      
      'zip' || 'apk' || 'epub'                    => _extractZipBased(file, ext),
      
      _                                            => null, // file system meta only
    };
  }

  Future<FormatMetadata> _extractFfmpeg(File file) async {
    // Use ffmpeg_kit to probe file
    final session = await FFprobeKit.getMediaInformation(file.path);
    final info = session.getMediaInformation();
    
    if (info == null) throw Exception('FFprobe failed: ${(await session.getOutput())}');
    
    final tags = info.getTags() ?? {};
    final streams = info.getStreams() ?? [];
    
    return FfmpegFormatMetadata(
      title: tags['title'],
      artist: tags['artist'],
      album: tags['album'],
      date: tags['date'] ?? tags['creation_time'],
      encoder: tags['encoder'],
      comment: tags['comment'],
      copyright: tags['copyright'],
      gpsLocation: _parseGpsFromFfmpegTags(tags),
      streams: streams.map((s) => StreamInfo(
        index: s.getIndex() ?? 0,
        codecName: s.getCodec(),
        codecType: s.getType(),
        width: s.getWidth(),
        height: s.getHeight(),
        duration: s.getRealFrameRate(),
        bitRate: s.getBitrate(),
        sampleRate: s.getSampleRate(),
        channels: s.getChannelLayout(),
      )).toList(),
      rawTags: Map<String, String>.from(tags),
    );
  }
}
```

### 4.2 Metadata Removal — Video (FFmpeg)

Security note: snippets below are planning pseudocode. Implementation must use argument-list APIs / ffmpeg-kit safe parameter passing, never shell-interpolated user paths. Validate canonical input/output paths before execution.

```dart
// lib/features/remover/data/datasources/metadata_remover_datasource.dart

Future<ProcessingResult> _removeVideoMetadata(
  File inputFile,
  String outputPath,
  RemovalMode mode,
  Set<String> selectiveFields,
) async {
  String ffmpegCommand;
  
  switch (mode) {
    case RemovalMode.fullStrip:
      // Remove ALL metadata, copy streams without re-encoding
      ffmpegCommand = '-i "${inputFile.path}" '
          '-map_metadata -1 '           // hapus semua global metadata
          '-map_chapters -1 '           // hapus chapters
          '-vf "setpts=PTS" '           // reset video PTS (hapus timing metadata)
          '-c:v copy -c:a copy '        // no re-encoding
          '-movflags +faststart '       // optimize MP4
          '"$outputPath"';
      break;
      
    case RemovalMode.anonymize:
      // Hapus hanya user-identifying metadata
      ffmpegCommand = '-i "${inputFile.path}" '
          '-map_metadata 0 '            // copy semua metadata dulu
          '-metadata location="" '      // hapus GPS
          '-metadata location-eng="" '
          '-metadata com.apple.quicktime.location.ISO6709="" '
          '-metadata author="" '
          '-metadata artist="" '
          '-metadata album_artist="" '
          '-metadata composer="" '
          '-metadata encoded_by="" '
          '-c copy '
          '"$outputPath"';
      break;
      
    case RemovalMode.preserveTechnical:
      // Hapus user metadata, pertahankan technical metadata
      ffmpegCommand = '-i "${inputFile.path}" '
          '-map_metadata -1 '
          // Re-add technical metadata
          '-c copy '
          '"$outputPath"';
      break;
      
    default:
      ffmpegCommand = '-i "${inputFile.path}" '
          '-map_metadata -1 -c copy "$outputPath"';
  }
  
  final session = await FFmpegKit.execute(ffmpegCommand);
  final returnCode = await session.getReturnCode();
  
  if (ReturnCode.isSuccess(returnCode)) {
    return ProcessingResult.success(
      inputPath: inputFile.path,
      outputPath: outputPath,
      fieldsRemoved: mode == RemovalMode.fullStrip ? ['ALL'] : selectiveFields.toList(),
    );
  } else {
    final logs = await session.getLogs();
    throw VideoProcessingException(
      message: logs.map((l) => l.getMessage()).join('\n'),
    );
  }
}
```

### 4.3 Isolate-based Processing
```dart
// lib/features/remover/domain/usecases/process_files.dart

class ProcessFiles {
  final RemoverRepository _repository;

  Future<Stream<ProcessingProgress>> call(List<RemovalJob> jobs) async {
    final progressController = StreamController<ProcessingProgress>.broadcast();
    
    // Spawn isolate untuk processing berat
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _processingIsolate,
      _IsolateMessage(
        jobs: jobs,
        sendPort: receivePort.sendPort,
      ),
    );
    
    receivePort.listen((message) {
      if (message is ProcessingProgress) {
        progressController.add(message);
      } else if (message is ProcessingComplete) {
        progressController.close();
        receivePort.close();
      } else if (message is ProcessingError) {
        progressController.addError(message.exception);
      }
    });
    
    return progressController.stream;
  }

  static void _processingIsolate(_IsolateMessage message) async {
    // Jalankan di dalam isolate — tidak blokir main thread
    for (int i = 0; i < message.jobs.length; i++) {
      final job = message.jobs[i];
      
      message.sendPort.send(ProcessingProgress(
        currentFile: job.file.path,
        currentIndex: i,
        totalFiles: message.jobs.length,
        percentage: i / message.jobs.length,
        status: ProcessingStatus.processing,
      ));
      
      try {
        // Actual processing
        final result = await _processJob(job);
        
        message.sendPort.send(ProcessingProgress(
          currentFile: job.file.path,
          currentIndex: i,
          totalFiles: message.jobs.length,
          percentage: (i + 1) / message.jobs.length,
          status: ProcessingStatus.done,
          result: result,
        ));
      } catch (e) {
        message.sendPort.send(ProcessingProgress(
          currentFile: job.file.path,
          currentIndex: i,
          totalFiles: message.jobs.length,
          percentage: (i + 1) / message.jobs.length,
          status: ProcessingStatus.failed,
          error: e.toString(),
        ));
      }
    }
    
    message.sendPort.send(const ProcessingComplete());
  }
}
```

### 4.4 Share Intent Handling
```dart
// lib/shared/services/share_intent_service.dart

class ShareIntentService {
  StreamSubscription? _subscription;

  void initialize(BuildContext context) {
    // Handle share intent saat app SUDAH buka
    _subscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> files) {
      _handleSharedFiles(context, files);
    });

    // Handle share intent saat app BARU dibuka
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(context, files);
      }
    });
  }

  void _handleSharedFiles(BuildContext context, List<SharedMediaFile> files) {
    final validFiles = files
        .where((f) => SupportedExtensions.isSupported(f.path))
        .map((f) => File(f.path))
        .toList();
    
    if (validFiles.isEmpty) return;
    
    // Navigate ke Remover dengan files
    context.go('/remover', extra: RemoverExtraArgs(files: validFiles));
  }

  void dispose() => _subscription?.cancel();
}
```

### 4.5 JPEG Metadata Strip (Lossless)
```dart
// Lossless JPEG metadata removal menggunakan pure Dart
// Prinsip: JPEG terdiri dari markers. Skip marker APP0 (JFIF) dan APP1 (EXIF)
// Copy semua data lain verbatim — tidak ada re-encoding, tidak ada quality loss

Future<File> _stripJpegMetadata(File input, String outputPath) async {
  final bytes = await input.readAsBytes();
  final output = BytesBuilder();
  int i = 0;

  // JPEG selalu dimulai dengan SOI marker: FF D8
  if (bytes[0] != 0xFF || bytes[1] != 0xD8) {
    throw InvalidFileException('Not a valid JPEG file');
  }
  output.add([0xFF, 0xD8]); // Write SOI
  i = 2;

  while (i < bytes.length - 1) {
    if (bytes[i] != 0xFF) {
      // Image data (after SOS marker) — copy verbatim
      output.add(bytes.sublist(i));
      break;
    }

    final marker = bytes[i + 1];
    i += 2;

    // Markers tanpa length (SOI, EOI, RST*)
    if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) {
      output.add([0xFF, marker]);
      continue;
    }

    final segmentLength = (bytes[i] << 8) | bytes[i + 1];
    final segmentData = bytes.sublist(i, i + segmentLength);
    i += segmentLength;

    // Skip metadata markers:
    // APP0 (E0): JFIF header
    // APP1 (E1): EXIF / XMP
    // APP2 (E2): ICC Profile (pertahankan jika PreserveTechnical mode)
    // APP12 (EC): Picture Info
    // APP13 (ED): IPTC / Photoshop
    // APP14 (EE): Adobe
    // COM (FE): Comment
    final skipMarkers = {0xE0, 0xE1, 0xEC, 0xED, 0xEE, 0xFE};
    
    if (skipMarkers.contains(marker)) {
      continue; // Skip marker ini
    }

    // Keep semua marker lainnya (SOF, DHT, DQT, SOS, dll)
    output.add([0xFF, marker]);
    output.add(segmentData);
  }

  final outputFile = File(outputPath);
  await outputFile.writeAsBytes(output.toBytes());
  return outputFile;
}
```

### 4.6 BLoC — Viewer
```dart
// lib/features/viewer/presentation/bloc/viewer_bloc.dart

class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  final AddFilesToViewer _addFiles;
  final ExtractMetadata _extractMetadata;
  final MarkFileForRemoval _markFile;
  final RemoveFileFromList _removeFile;
  final ComputeFileHash _computeHash;

  ViewerBloc({...}) : super(ViewerInitial()) {
    on<ViewerFilesAdded>(_onFilesAdded);
    on<ViewerFileRemoved>(_onFileRemoved);
    on<ViewerFileMarked>(_onFileMarked);
    on<ViewerFileUnmarked>(_onFileUnmarked);
    on<ViewerAllSelected>(_onAllSelected);
    on<ViewerAllDeselected>(_onAllDeselected);
    on<ViewerBatchMarked>(_onBatchMarked);
    on<ViewerBatchRemoved>(_onBatchRemoved);
    on<ViewerSortChanged>(_onSortChanged);
    on<ViewerFilterChanged>(_onFilterChanged);
    on<ViewerSendToRemover>(_onSendToRemover);
  }

  Future<void> _onFilesAdded(
    ViewerFilesAdded event,
    Emitter<ViewerState> emit,
  ) async {
    final current = state as ViewerLoaded? ?? const ViewerLoaded(files: []);
    emit(current.copyWith(isLoading: true));
    
    // Deduplicate
    final existingPaths = current.files.map((f) => f.path).toSet();
    final newFiles = event.files
        .where((f) => !existingPaths.contains(f.path))
        .toList();
    
    if (newFiles.isEmpty) {
      emit(current.copyWith(isLoading: false));
      return;
    }
    
    // Extract metadata for each new file
    final results = <FileItemEntity>[];
    for (final file in newFiles) {
      final result = await _extractMetadata(ExtractMetadataParams(file: file));
      result.fold(
        (failure) => results.add(FileItemEntity.withError(file, failure)),
        (metadata) => results.add(FileItemEntity(file: file, metadata: metadata)),
      );
    }
    
    emit(ViewerLoaded(
      files: [...current.files, ...results],
      isLoading: false,
    ));
  }
}
```

### 4.7 Theme System
```dart
// lib/core/theme/app_colors.dart

@freezed
class AppColorScheme with _$AppColorScheme {
  const factory AppColorScheme({
    required Color backgroundPrimary,
    required Color backgroundSecondary,
    required Color backgroundTertiary,
    required Color border,
    required Color borderEmphasis,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color accentPrimary,
    required Color accentSecondary,
    required Color accentSuccess,
    required Color accentDanger,
    required Color accentInfo,
    required Brightness brightness,
  }) = _AppColorScheme;
  
  static const AppColorScheme darkIndustrial = AppColorScheme(
    backgroundPrimary:   Color(0xFF0D0D0D),
    backgroundSecondary: Color(0xFF1A1A1A),
    backgroundTertiary:  Color(0xFF242424),
    border:              Color(0xFF2E2E2E),
    borderEmphasis:      Color(0xFF404040),
    textPrimary:         Color(0xFFE8E0D0),
    textSecondary:       Color(0xFF9A9080),
    textTertiary:        Color(0xFF5A5248),
    accentPrimary:       Color(0xFFC94B1A),
    accentSecondary:     Color(0xFFE8A040),
    accentSuccess:       Color(0xFF4A8C5A),
    accentDanger:        Color(0xFF8C2A2A),
    accentInfo:          Color(0xFF2A5A8C),
    brightness:          Brightness.dark,
  );
  
  static const AppColorScheme steelBlue = AppColorScheme(
    backgroundPrimary:   Color(0xFF0A1628),
    backgroundSecondary: Color(0xFF112038),
    backgroundTertiary:  Color(0xFF1A2E4A),
    border:              Color(0xFF243850),
    borderEmphasis:      Color(0xFF2E4C68),
    textPrimary:         Color(0xFFE0E8F0),
    textSecondary:       Color(0xFF8090A8),
    textTertiary:        Color(0xFF506070),
    accentPrimary:       Color(0xFF2E7DD1),
    accentSecondary:     Color(0xFF5BB8E8),
    accentSuccess:       Color(0xFF3A9C6A),
    accentDanger:        Color(0xFFC03030),
    accentInfo:          Color(0xFF3080C0),
    brightness:          Brightness.dark,
  );
  
  // ... more presets
}

// Provider via BLoC/Cubit
class ThemeCubit extends Cubit<AppColorScheme> {
  final SettingsRepository _settings;
  
  ThemeCubit(this._settings) : super(AppColorScheme.darkIndustrial) {
    _loadSavedTheme();
  }
  
  Future<void> _loadSavedTheme() async {
    final saved = await _settings.getColorTheme();
    emit(saved);
  }
  
  Future<void> setTheme(AppColorScheme scheme) async {
    await _settings.saveColorTheme(scheme);
    emit(scheme);
  }
}
```

### 4.8 Router Configuration
```dart
// lib/app/router.dart

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (ctx, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (ctx, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      builder: (ctx, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/viewer',
          builder: (ctx, state) => const ViewerScreen(),
          routes: [
            GoRoute(
              path: 'detail/:filePath',
              builder: (ctx, state) => MetadataDetailScreen(
                filePath: Uri.decodeComponent(state.pathParameters['filePath']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/remover',
          builder: (ctx, state) {
            final extra = state.extra as RemoverExtraArgs?;
            return RemoverScreen(initialFiles: extra?.files ?? []);
          },
          routes: [
            GoRoute(
              path: 'processing',
              builder: (ctx, state) => const ProcessingScreen(),
            ),
            GoRoute(
              path: 'result',
              builder: (ctx, state) => ResultScreen(
                result: state.extra as BatchProcessingResult,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (ctx, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'theme',
              builder: (ctx, state) => const ThemePickerScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
  redirect: (ctx, state) async {
    final isOnboarded = await SharedPreferences.getInstance()
        .then((p) => p.getBool('onboarding_completed') ?? false);
    
    if (!isOnboarded && !state.matchedLocation.startsWith('/onboarding')) {
      return '/onboarding';
    }
    if (isOnboarded && state.matchedLocation == '/splash') {
      return '/viewer';
    }
    return null;
  },
);
```

---

## 5. Android Configuration

### 5.1 AndroidManifest.xml
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Viewer MVP uses system picker / SAF only.
         No broad storage/media permissions.
         Add runtime permissions later only with explicit feature justification. -->

    <application
        android:label="MetaStrip"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask">
            
            <!-- Share intent receiver — receive files dari app lain -->
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="*/*"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="*/*"/>
            </intent-filter>
            
            <!-- File open via file manager -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="image/*"/>
                <data android:mimeType="video/*"/>
                <data android:mimeType="audio/*"/>
                <data android:mimeType="application/pdf"/>
            </intent-filter>
        </activity>
        
        <!-- FileProvider untuk share output files -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths"/>
        </provider>
        
    </application>
</manifest>
```

### 5.2 Proguard Rules
```proguard
# FFmpeg Kit
-keep class com.arthenica.ffmpegkit.** { *; }

# Syncfusion PDF
-keep class com.syncfusion.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
```

---

## 6. Testing Strategy

### 6.1 Unit Tests
```
test/
├── core/
│   ├── utils/
│   │   ├── file_utils_test.dart
│   │   └── hash_utils_test.dart
│   └── permissions/
│       └── permission_handler_test.dart
├── features/
│   ├── viewer/
│   │   ├── data/
│   │   │   └── metadata_extractor_test.dart  # Test per format dengan fixture files
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── add_files_test.dart
│   │   │       └── extract_metadata_test.dart
│   │   └── presentation/
│   │       └── bloc/viewer_bloc_test.dart
│   ├── remover/
│   │   ├── data/
│   │   │   └── metadata_remover_test.dart   # Verify metadata removed from output
│   │   └── presentation/
│   │       └── bloc/remover_bloc_test.dart
│   └── settings/
│       └── cubit/settings_cubit_test.dart
└── fixtures/
    ├── images/          # Sample files untuk testing
    │   ├── test_with_gps.jpg
    │   ├── test_no_exif.png
    │   └── test_raw.cr2
    ├── videos/
    │   └── test_with_metadata.mp4
    ├── audio/
    │   └── test_with_id3.mp3
    └── documents/
        └── test_with_author.docx
```

### 6.2 Coverage Target
| Module | Target Coverage |
|--------|----------------|
| Domain — Use Cases | 90%+ |
| Data — Extractors | 85%+ |
| Data — Removers | 85%+ |
| Presentation — BLoCs | 80%+ |
| Core Utils | 90%+ |

### 6.3 Integration Tests (e2e)
```dart
// integration_test/full_flow_test.dart

void main() {
  group('Full User Flow', () {
    testWidgets('Onboarding → Viewer → Detail → Remover → Result', (tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Onboarding
      expect(find.text('METASTRIP'), findsOneWidget);
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();
      
      // ... full flow test
    });
    
    testWidgets('Share intent file → Remover → Process → Result', (tester) async {
      // Simulate share intent
    });
  });
}
```

---

## 7. Release Checklist

### Pre-Release
- [ ] Semua unit + widget + integration tests passing
- [ ] Performance profiling: tidak ada jank, memory tidak leak
- [ ] Accessibility: TalkBack tested di Android
- [ ] Dark theme: semua 8 tema tampil benar di semua screen
- [ ] Permission flows: semua skenario denied/granted/restricted tested
- [ ] Edge cases: corrupt file, large file, no storage space
- [ ] Crash analytics terintegrasi (Sentry/Firebase)
- [ ] ProGuard rules verified — tidak ada class penting yang ter-strip
- [ ] App icon tersedia di semua density (mdpi s/d xxxhdpi + adaptive)
- [ ] Onboarding reset dari Settings berfungsi
- [ ] Share intent dari Gallery, Files, WhatsApp, Chrome tested
- [ ] Output files verified benar-benar bebas metadata

### Build
```bash
# Release build Android
flutter build apk --release --obfuscate --split-debug-info=debug-info/

# Release build App Bundle (Play Store)
flutter build appbundle --release --obfuscate --split-debug-info=debug-info/

# Release build iOS
flutter build ipa --release
```

### Version Bump
```yaml
# pubspec.yaml
version: 1.0.0+1  # format: semver+buildNumber
```
