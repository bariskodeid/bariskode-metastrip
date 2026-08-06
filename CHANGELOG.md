# Changelog

All notable changes to MetaStrip project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase 0 MVP Foundation — 90.9% (2026-07-31)

#### Changed
- Completed 10 of 11 Phase 0 roadmap tasks. Dev/prod flavors are deliberately
  deferred while MetaStrip remains a single-binary MVP.
- Kept direct constructor injection and `MaterialApp`/`Navigator` routing as
  intentional MVP decisions; the composition root owns storage initialization
  and dependency wiring without adding a service locator or router package.
- Routed onboarding state and output-folder persistence through the local
  storage abstraction, with visible, retryable startup initialization.
- Kept platform access least-privileged through system pickers and app-scoped
  grants; no broad storage or media permissions are requested.
- Made the final onboarding acknowledgment ("I UNDERSTAND") complete first-run
  setup in one tap when a valid output folder is already selected.
- Added Android Storage Access Framework (SAF) support so folders picked via
  the system picker (`content://` tree URIs) validate and receive clean
  output copies; no broad storage or media permissions are requested.

#### Fixed
- Validated the configured output folder before removal and return a clear
  failure instead of silently falling back to the input directory.
- Hardened collision-free output creation to remove the prior check/write
  TOCTOU window.
- Truncated JPEG output at EOI so appended post-EOI data is not copied.
- Retained existing remover hardening for sensitive JPEG/PNG chunks, sanitized
  errors, queue limits, cancellation, and per-file failure isolation.

#### Verification
- `flutter analyze`: clean.
- `flutter test`: 65 passed, 1 skipped.
- Debug APK build is not verified for this snapshot: Gradle downloads from
  `dl.google.com` failed with TLS `bad_record_mac`/tag-mismatch errors.

#### Known Risks
- **PDF removal remains best-effort DocInfo blanking.** XMP packets, object
  streams, JavaScript, embedded files, and other metadata may survive. A
  structural PDF implementation is required before comprehensive-removal
  claims are safe.
- `FileItemEntity` still lives in the viewer feature while remover imports it;
  moving it to shared domain remains future cleanup.

## Historical Baseline

The initial project scaffold established the Flutter Android/iOS targets,
feature-first Clean Architecture, BLoC/Cubit state management, theme tokens,
shared controls, and basic smoke testing. Current completion and verification
status is maintained under `[Unreleased]`; no `1.0.0` release has been recorded.
