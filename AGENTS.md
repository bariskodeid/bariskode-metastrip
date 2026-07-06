# AGENTS.md — MetaStrip

Flutter app (Dart 3, package name `metastrip`). Reads metadata from many file types and strips metadata from a smaller MVP set (JPEG, PNG, PDF). Offline-only.

## Commands

- Install deps: `flutter pub get`
- Run app (needs device/emulator): `flutter run`
- Analyze (lint + type): `flutter analyze`
- Tests: `flutter test` (single file: `flutter test test/features/remover/data/...`)
- Debug APK: `flutter build apk --debug`
- Release APK: `flutter build apk --release` — requires env vars `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Missing vars → release build fails; debug builds unaffected. See `SETUP_COMPLETE.md` §Known Issues.
- Format: Dart default (`dart format`); not wired to CI.

## Toolchain

- Flutter SDK ≥ 3.22, Dart ≥ 3.4. CI/dev box recorded at 3.41.7 / 3.11.5.
- Android + iOS only (no web/desktop). Manifests in `android/`, `ios/`.
- Lints: `flutter_lints` + `very_good_analysis` (see `analysis_options.yaml`).

## Architecture

Clean Architecture, feature-first. Single binary, no monorepo.

```
lib/
├── main.dart                    # entrypoint; boots SharedPreferences, wraps View in OnboardingCubit
├── app/di/                      # placeholder; MVP uses direct constructors, no get_it
├── core/
│   ├── constants/               # app_constants.dart, supported_extensions.dart
│   ├── errors/                  # exceptions, failures (sealed)
│   ├── permissions/             # permission_handler wrapper
│   ├── processing/              # format-specific scrubbers
│   ├── storage/                 # SharedPreferences wrapper
│   ├── theme/                   # app_theme, app_colors (7 presets), app_typography, app_spacing
│   └── utils/                   # file/date/hash/logger
├── features/
│   ├── onboarding/{data,domain,presentation}   # cubit + screens; gates first-run flow
│   ├── viewer/{data,domain,presentation}       # viewer_screen, metadata_detail_screen
│   ├── remover/{data,domain,presentation}
│   └── settings/{data,domain,presentation}
└── shared/widgets/, shared/services/   # PrimaryButton, SecondaryButton, etc.
```

Each feature follows `data/` (repo impls + datasources/models) → `domain/` (entities, repo interfaces, usecases) → `presentation/` (bloc/cubit, screens, widgets).

## Routing

`main.dart` routes by onboarding state, not via Navigator named routes:
- `OnboardingCubit.load()` reads `keyOnboardingCompleted` from `SharedPreferences`.
- Completed → `ViewerScreen`. Otherwise → `OnboardingScreen`. (Router/named-routes are intentionally deferred — IMPLEMENTATION_PLAN.md §1.2.)

## Key conventions / gotchas

- **Remover MVP scope**: only JPEG, PNG text chunks, and PDF `DocInfo` entries are scrubbed. Deep XMP/EXIF/Office/Video scrub is pending — do not promise broader removal in copy or tests.
- **Clean copies**: output is a new file in the user-configured output folder; originals are never mutated.
- **MVP size cap**: SHA-256 only computed for files ≤ 100MB.
- **Custom fonts**: `pubspec.yaml` font blocks are commented out. Runtime uses system fallbacks (IBM Plex Mono → system mono). Do not assume `Bebas Neue` / `Space Mono` are loaded.
- **Assets folders** (`assets/{fonts,illustrations,icons,textures}/`) exist but are empty.
- **State management**: `flutter_bloc` with `Cubit` for onboarding + `Bloc` for viewer/remover. Mirror existing pattern in new features.
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
- `docs/IMPLEMENTATION_PLAN.md` — phased plan; phase status (Phase 0 done, Phase 1+ planned) is authoritative over earlier `CHANGELOG.md` "XX" placeholders.
- `SETUP_COMPLETE.md` — Phase 0 report + keystore env-var note.
- `CHANGELOG.md` — Keep-a-Changelog format; `[Unreleased]` tracks current phase.

## Quirks for agents

- Output-folder path is stored in `SharedPreferences`; users pick it during onboarding.
- Repository pattern: feature-owned `*Repository` interface in `domain/repositories/`, impl in `data/repositories/`. New formats → add a datasource under `features/<feature>/data/datasources/`.
- Do not introduce `get_it`/`go_router` without a planning step — IMPLEMENTATION_PLAN defers them on purpose.
- No git repo on disk (`Is directory a git repo: no` in this workspace); commit/PR workflow is not enforced locally.
