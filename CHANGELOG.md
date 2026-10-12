# metadata-viewer-remover

## [Unreleased]

### Fixed

Bug-audit fixes (`docs/BUG_AUDIT_2026-10-12.md`). Items marked "manual verification pending" are covered by tests only and have not been checked on a device or in the named third-party tool.

- CI and toolchain: CI pins Flutter 3.41.7 and `pubspec.yaml` requires Flutter `>=3.35.0`, matching the APIs in use; README prerequisites updated.
- Privacy: Firebase Analytics, `google-services.json` and the INTERNET/AD_ID permissions it merged were removed from the Android build, matching the offline-only policy.
- GIF: removal read the image descriptor packed byte at the wrong offset, so real-world GIFs were rejected; fixed.
- Ogg/Opus/Vorbis: rewritten pages use the spec Ogg CRC-32 (0x04C11DB7), the Vorbis comment header keeps its framing bit, comment packets spanning pages are rejected instead of left in place, and short packets fail with `FormatException`. Manual verification pending: ffmpeg/VLC decode of a cleaned real `.ogg`.
- ZIP: the registry gives ZIP a removal size limit, so `.zip` files no longer fail with "too large".
- Remover: concurrent or double-started batches are guarded, a batch that throws fails closed, Back is allowed when not processing, and retrying with an invalid folder no longer hangs.
- JPEG: Adobe APP14 and ICC segments are kept; APP11 (JUMBF/C2PA) and other APPn segments are stripped. Manual verification pending: CMYK JPEG colour check.
- PDF removal: blanking is scoped to Info dictionaries (bookmark titles are preserved), indirect values are resolved and blanked, and unresolvable Info fails closed. PDFs whose Info dictionary sits in a compressed object stream are now rejected.
- ZIP-family (OpenXML, ODF, EPUB, APK, ZIP): repack now binds the decoder to the preflighted directory (name, size, CRC and method), timestamps are normalized, and validation reads are bounded. Manual verification pending: opening a cleaned `.docx` in Word/LibreOffice.
- ODF/EPUB/OpenXML: full strip removes the `meta.xml` manifest entry, EPUB `mimetype` position rules are enforced, viewer part resolution follows relationships and prefers the root `meta.xml`, and older OpenOffice manifests with a DOCTYPE are accepted. Manual verification pending: opening a stripped LibreOffice `.odt` with a chart.
- WAV/AIFF (RIFF): `id3 `, `_PMX`, `iXML`, `cart` and AIFF `COMT` chunks are dropped and INFO values have trailing NULs cleaned.
- Output validation: unverified outputs are deleted, and the message is "Output validation failed; the invalid copy was removed".
- Settings and onboarding: SAF folder picker on Android, mobile-safe export/import, and picker errors are surfaced. Manual verification pending: Android device SAF picker and export.
- iOS: the default output folder is `Documents/MetaStrip`. Manual verification pending: iOS simulator Files visibility.
- Viewer: PDF trailer Info lookup and string decoding, ID3 (truncated tags, extended header, unsynchronisation, UTF-16 COMM, v1.0, NUL escape), Vorbis (tolerant comments, multi-page packets), PNG zTXt/iTXt/eXIf and GIF XMP are now parsed or shown.
- About and Settings: About links point at real destinations with an Android 11+ `<queries>` entry, onboarding resets cleanly, unwired settings show "Not yet applied", and persisted SAF grants are released. Manual verification pending: About links on device.

## v0.1.0 (WIP)

**Status:** In progress. PDF XMP stripping and ZIP stress tests implemented, but crash reporting plan still pending finalization.