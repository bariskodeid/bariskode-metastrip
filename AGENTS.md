# AGENTS.md — MetaStrip

Flutter app (Dart 3, package name `metastrip`). Reads metadata from an allowlisted set and strips metadata from the registered 20-extension Remover set, including the narrow canonical BMP subset and ZIP-only container cleanup. Offline-only.

## Commands

- Install deps: `flutter pub get`
- Run app (needs device/emulator): `flutter run`
- Analyze (lint + type): `flutter analyze`
- Tests: `flutter test` (single file: `flutter test test/features/remover/data/...`)
- Debug APK: `flutter build apk --debug`
- Release APK: `flutter build apk --release` — requires env vars `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Missing vars → release build fails; debug builds unaffected. See the release-signing notes in `SETUP_COMPLETE.md` and `docs/IMPLEMENTATION_PLAN.md`.
- Format: Dart default (`dart format`); not wired to CI.

## Toolchain

- Flutter SDK ≥ 3.22, Dart ≥ 3.4. CI/dev box recorded at 3.41.7 / 3.11.5.
- Android + iOS only (no web/desktop). Manifests in `android/`, `ios/`.
- Lints: `flutter_lints` + `very_good_analysis` (see `analysis_options.yaml`).

## Architecture

Clean Architecture, feature-first. Single binary, no monorepo.

```
lib/
├── main.dart                    # bootstrap; initializes storage and Settings dependencies
├── app/                         # app root; providers, OnboardingCubit, direct constructors
├── core/
│   ├── constants/               # app_constants.dart, supported_extensions.dart
│   ├── errors/                  # exceptions, failures (sealed)
│   ├── processing/              # shared worker/ZIP processing helpers
│   ├── storage/                 # SharedPreferences wrapper
│   ├── theme/                   # app_theme, app_colors (7 presets), app_typography, app_spacing
│   └── utils/                   # file utilities
├── features/
│   ├── onboarding/{data,domain,presentation}   # cubit + screens; gates first-run flow
│   ├── viewer/{data,domain,presentation}       # viewer_screen, metadata_detail_screen
│   ├── remover/{data,domain,presentation}       # scrubbers live under data/datasources
│   └── settings/{data,domain,presentation}
└── shared/widgets/              # PrimaryButton, SecondaryButton, etc.
```

Each feature follows `data/` (repo impls + datasources/models) → `domain/` (entities, repo interfaces, usecases) → `presentation/` (bloc/cubit, screens, widgets).

## Routing

`main.dart` routes by onboarding state, not via Navigator named routes:
- `OnboardingCubit.load()` reads `keyOnboardingCompleted` from `SharedPreferences`.
- Completed → `ViewerScreen`. Otherwise → `OnboardingScreen`. (Router/named-routes are intentionally deferred — IMPLEMENTATION_PLAN.md §1.2.)

## Key conventions / gotchas

- **Remover MVP scope**: the registry currently includes JPG/JPEG, PNG, PDF, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, DOCX, XLSX, PPTX, ODT, ODS, ODP, GIF, WebP, and ZIP. WAV selective removal is enabled only for eleven stable-ID `LIST INFO` subchunks; AIFF selective removal remains disabled. BMP removal is limited to the narrow canonical subset, PDF removal remains best-effort DocInfo only, and ZIP cleanup is container-only/nonrecursive. APK and EPUB are excluded from removal. Video, archives other than ZIP, HEIC/HEIF, RAW, broader granular audio removal, and the Full Strip/Selective/Anonymize/Preserve Technical UI modes are deferred or unwired. Office selective removal is available in the data/policy path for exact allowlisted standard core/app IDs only; custom and legacy Office properties remain unsupported.
- **Clean copies**: output is a new file in the user-configured output folder; originals are never mutated.
- **MVP size cap**: SHA-256 only computed for files ≤ 100MB. ZIP-family processing is bounded by a 50MiB input cap and in-memory limits; device/SAF and stress validation are still pending, so these are safety bounds rather than demonstrated performance guarantees.
- **Custom fonts**: `pubspec.yaml` font blocks are commented out. Runtime uses system fallbacks (IBM Plex Mono → system mono). Do not assume `Bebas Neue` / `Space Mono` are loaded.
- **Assets folders** (`assets/{fonts,illustrations,icons,textures}/`) exist but are empty.
- **State management**: `flutter_bloc` with Cubits for onboarding, viewer, and Settings; `RemoverBloc` handles removal. Mirror the owning feature's existing pattern.
- **DI**: direct constructors passed into `MetaStripApp`. No service locator yet.
- **Lints are strict** (`very_good_analysis`); expect line-length, doc-comment, and ordering nits. Run `flutter analyze` before claiming done.

## Testing

- Widget tests mock `SharedPreferences` with `SharedPreferences.setMockInitialValues(...)` — see `test/widget_test.dart` for the pattern.
- Existing tests:
  - `test/widget_test.dart` — smoke test of full app boot.
  - `test/features/remover/data/` — format-specific scrubber unit tests.
  - `test/features/viewer/` — viewer-side tests.
- `bloc_test` is available; use it for new cubit/bloc specs.

## Docs

- `README.md` — pitch, install, phases.
- `docs/SPECS.md` — product spec.
- `docs/DESIGN.md` — design system tokens.
- `docs/IMPLEMENTATION_PLAN.md` — roadmap and implementation follow-ups.
- `SETUP_COMPLETE.md` — progress report + keystore env-var note; tracks current phase status with `CHANGELOG.md`.
- `CHANGELOG.md` — Keep-a-Changelog format; `[Unreleased]` tracks current phase status with `SETUP_COMPLETE.md`.

## Quirks for agents

- Output-folder path is stored in `SharedPreferences`; users pick it during onboarding.
- Repository pattern: feature-owned `*Repository` interface in `domain/repositories/`, impl in `data/repositories/`. New formats → add a datasource under `features/<feature>/data/datasources/`.
- Do not introduce `get_it`/`go_router` without a planning step — IMPLEMENTATION_PLAN defers them on purpose.
- This workspace is a Git repository. Preserve unrelated dirty-worktree changes and stage only task-owned files when a commit is requested.
