# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

`AGENTS.md` (imported above) holds the commands, toolchain, folder layout, format-scope rules, and testing conventions. This file adds the cross-file architecture you need to work on the format pipeline.

## Commands (quick reference)

- `flutter pub get` · `flutter analyze` · `flutter test`
- Single test file: `flutter test test/features/remover/data/datasources/remover_registry_contract_test.dart`
- Single test by name: `flutter test --plain-name "<test name substring>" <file>`
- CI (`.github/workflows/`) runs `flutter analyze`, `flutter test`, and `flutter build apk --debug` on Flutter **3.22.0**. Don't use Dart/Flutter APIs newer than that, even though the local box runs a newer SDK.
- `scripts/generate_device_fixtures.py` writes the ZIP-family stress fixtures (Z01–Z10, about 400 MB) to disk for the manual device runs in `docs/DEVICE_AND_STRESS_TEST_PLAN.md`. Host tests build the same fixtures in memory, so don't commit large fixtures.

## Format capability pipeline (the core abstraction)

Format support is declared in one place and enforced in several. When you add or change a format, update every layer below:

1. **`lib/core/format/format_registry.dart`**: `FormatRegistry.standard` is the single source of truth. Each `FormatCapability` (in `format_capability.dart`) declares extensions, MIME types, `supportsExtraction` / `supportsFullRemoval` / `supportsSelectiveRemoval`, size limits, `OutputValidationStrategy`, `RemovalCoverage`, and `knownLimitations`. Handler factories here are opaque placeholders (`_handlerDeclaration`), so core never imports feature code.
2. **`lib/core/constants/supported_extensions.dart`**: compatibility facades (`SupportedExtensions`, `RemoverStrippableExtensions`) that derive from the registry. Never hand-maintain extension lists.
3. **Viewer**: `features/viewer/data/datasources/extractors/format_registry.dart` maps each extension to a `FormatExtractionSpec` (extractor function, bounded or full read, max bytes). The per-format parsers live next to it (`*_extractor.dart`).
4. **Remover**: `features/remover/data/datasources/metadata_remover_datasource.dart` maps each extension to a `_RemovalRoute` in `_routes`. `stripMetadata` validates the request against the registry, then dispatches to `strip<Format>Metadata`. Byte-level logic lives in `strippers/` (`*_stripper.dart`, plus `*_validator.dart` for output re-validation).
5. **Contract tests** catch drift between the registry and the handlers: `test/core/format/format_registry_test.dart` (`handlerConsistencyIssues`) and `test/features/remover/data/datasources/remover_registry_contract_test.dart`. Keep them green rather than weakening them.

## Removal flow

- `RemoverBloc` → `RemoverRepositoryImpl` → `MetadataRemoverDatasource.stripMetadataWithPolicy(...)`. A `StripPolicy` is either `supportedCleanup()` (full) or `selective(fieldIds:)`.
- Byte transforms run off the UI isolate through `runOnWorker` (`core/processing/isolate_runner.dart`, a thin wrapper around `Isolate.run`). Pure stripper functions take `Uint8List` and return `Uint8List`, so they must stay isolate-safe: no closures over non-sendable state.
- ZIP-family formats (OpenXML, ODF, EPUB, APK, ZIP) share `core/processing/zip_repack.dart`. It sets its own caps: `maxRepackTotalSize` = 32 MB decompressed, `maxRepackEntryCount` = 2000, `maxRepackEntrySize`, and `maxPackageDescriptorSize`. Separately, the 50 MiB input cap (`maxRemoverFileSizeBytes`) lives in `core/constants/app_constants.dart`. The `maxZip*DecompressBytes` constants there belong to the Viewer's `zip_extractor.dart`, not the Remover.
- Output writing (`_writeCleanCopy`) never overwrites. For local paths it uses a `.claim` file, writes and flushes to a uniquely named `.tmp`, renames to `<name>_clean[_N].<ext>`, and tries up to 999 collisions. On Android, an output folder starting with `content://` goes through SAF (`_writeCleanCopyViaSaf`). In that case the returned `File` is only a URI token, not a real path. After writing, outputs are re-read and validated, and a failed validation deletes the output defensively (`_deleteIfSameBytes`).

## Selective removal

- Field selection uses stable IDs, not display labels: `MetadataFieldId` (an extension type in `features/remover/domain/entities/metadata_field_id.dart`). Examples: `pdf.info.*`, `openxml.core.*` / `openxml.app.*`, `png.text.<encoded keyword>`, `vorbis.comment.<key>`, and WAV `LIST INFO` IDs. Viewer extractors must emit these same IDs on their fields for the handoff to work.
- Handoff path: `MetadataDetailScreen` (shown only when the registry says `supportsSelectiveRemoval`) → `onSelectiveCleanup(fieldIds)` → `ViewerScreen` builds `StripPolicy.selective` → Remover.
- Every route allowlists its IDs strictly. An unknown or unsupported ID throws `FormatException('Unsupported selective metadata field')` instead of being ignored.
- PNG IDs reversibly encode the user's keyword. Don't log, persist, or export them without redaction.

## Repo hygiene

- The working tree often holds the user's in-progress, uncommitted work, such as new PDF XMP stripper files and `*.out.txt` analyze/build logs. Don't revert or stage files you didn't touch.
- Keep `CHANGELOG.md` `[Unreleased]` and `SETUP_COMPLETE.md` in sync when phase status changes.
