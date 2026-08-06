# MetaStrip Phase 0 MVP Foundation Report

**Snapshot:** 2026-07-31  
**Roadmap status:** 90.9% (10/11 Phase 0 tasks)  
**Deferred task:** dev/prod flavors, deliberately deferred for the current single-binary MVP

## Current Foundation

- Flutter project targets Android and iOS using Clean Architecture with a feature-first layout.
- The app has a real onboarding-to-viewer startup flow; the old temporary setup homepage no longer exists.
- The composition root initializes the local-storage abstraction and wires repositories, use cases, and state objects with direct constructors.
- Manual constructor DI and `MaterialApp`/`Navigator` routing are intentional MVP decisions. A DI container or declarative router should be introduced only when complexity justifies it.
- Startup storage initialization can fail visibly and be retried instead of leaving the app on an unrecoverable loading screen.
- SharedPreferences is behind the storage abstraction for onboarding state and output-folder persistence.
- Output processing validates that the configured folder exists and is writable, reports failure rather than silently falling back, and reserves collision-free clean-copy paths safely. Originals are never mutated.
- Platform file access uses system pickers/app-scoped grants. The app requests no broad storage or media permissions.

## Phase 0 Checklist

| Status | Roadmap task | Notes |
|--------|--------------|-------|
| Done | Flutter project initialization | Android and iOS project initialized |
| Done | Folder structure | Clean Architecture, feature-first modules |
| Done | Git setup | Repository and ignore rules configured |
| Done | Dependency setup | MVP dependencies resolved in `pubspec.yaml` |
| Done | Theme system | Seven presets, typography, spacing, and system font fallbacks |
| Done | Shared widgets | Reusable MVP controls and feedback widgets |
| Done | DI setup | Direct constructor composition is intentional for MVP |
| Done | Router setup | `MaterialApp`/`Navigator` is intentional for MVP |
| Done | Storage setup | Abstract storage, SharedPreferences backend, retryable startup |
| Done | Platform access setup | System picker/app-scoped model; no broad permissions |
| Deferred | Dev/prod flavors | Add only when separate environments are required |

## Verification

- `flutter analyze`: clean.
- `flutter test`: 65 passed, 1 skipped.
- `flutter build apk --debug`: **not verified for this snapshot**. Gradle downloads from `dl.google.com` failed with TLS `bad_record_mac`/tag-mismatch errors; this is an external download failure, not a successful build result.
- Release builds additionally require `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD`.

## Scope And Residual Risk

- Metadata removal is intentionally limited to the JPEG, PNG, and PDF MVP paths; it is not a broad all-format scrubber.
- PDF removal is best-effort DocInfo blanking. XMP, object streams, JavaScript, embedded files, and other metadata may survive, so cleaned PDFs must not be described as comprehensively sanitized.
- Custom font declarations remain disabled and asset folders remain empty; runtime typography uses system fallbacks.
- Video/audio/share/notification work and dev/prod flavors remain deferred until their features require them.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

The build command is retained as the intended verification step, not as evidence that the current snapshot produced an APK.
