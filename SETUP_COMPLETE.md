# MetaStrip MVP Progress Report

**Snapshot:** 2026-08-06  
**Overall:** ~40% of total roadmap; Phases 0, 1, 3, 4 done; Phase 2 ~35%; Phases 5-6 not started  
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

## Partially Complete

### Phase 2: Metadata Engine — ~35%
**Done:**
- Supported extension allowlist and MIME lookup
- JPEG/TIFF EXIF extraction: GPS, camera, lens, timestamps, privacy flags
- PNG tEXt + uncompressed iTXt extraction
- SHA-256 hash computation (opt-in, size-guarded)
- Privacy field detection for GPS, author, device info

**Pending:**
- Audio: ID3 (MP3), Vorbis Comments (FLAC/OGG), RIFF (WAV/AIFF)
- Video: FFmpeg-based extraction for MP4, MKV, AVI, WebM, etc.
- PDF: `syncfusion_flutter_pdf` DocInfo + XMP extraction
- Office: DOCX/XLSX/PPTX via archive + XML parsing
- Archives: ZIP/APK metadata parsing
- GIF, WebP, BMP, HEIC extractors
- Isolate-based background extraction

## Not Started

### Phase 5: Settings (empty scaffold)
### Phase 6: Polish & Testing

## Verification

- `flutter analyze`: clean (0 issues)
- `flutter test`: 66 passed, 1 skipped
- Debug APK: builds and installs to Samsung SM M205G (Android 8.1)
- Device serial: `3201fbb0c40a1615`

## Dependencies

**Installed:** flutter_bloc, bloc, equatable, shared_preferences, path_provider, file_picker, path, mime, archive, exif, image, lucide_icons_flutter, flutter_colorpicker, shimmer, lottie, crypto, convert, intl, file_selector, saf, cupertino_icons

**Planned:** sqflite, id3_codec, ffmpeg_kit_flutter_full_gpl, syncfusion_flutter_pdf, permission_handler, cached_network_image, logger, dartz, share_plus, receive_sharing_intent, flutter_local_notifications

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```
