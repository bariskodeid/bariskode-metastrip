# metadata-viewer-remover

## [Unreleased]

## [1.0.0+4] - 2026-10-27

### Fixed

- Viewer EXIF: JPEGs whose Exif APP1 sits behind more than ~4 KB of other segments (APP11 JUMBF/C2PA, large APP2 ICC profiles, an earlier XMP APP1) showed "No EXIF metadata found", because the `exif` package only scans the first 4 KB. The extractor now locates the Exif APP1 itself. Verified on a Galaxy M20 (Android 10) with a C2PA-style JPEG.

## [1.0.0+3] - 2026-10-21

### Fixed

Bug-audit fixes (`docs/BUG_AUDIT_2026-10-12.md`). Items marked "manual verification pending" are covered by tests only and have not been checked on a device or in the named third-party tool.

- CI and toolchain: CI pins Flutter 3.41.7 and `pubspec.yaml` requires Flutter `>=3.35.0`, matching the APIs in use; README prerequisites updated.
- Privacy: Firebase Analytics, `google-services.json` and the INTERNET/AD_ID permissions it merged were removed from the Android build, matching the offline-only policy.
- GIF: removal read the image descriptor packed byte at the wrong offset, so real-world GIFs were rejected; fixed. The viewer had the same off-by-one and missed comment and XMP extensions after the first frame; fixed.
- Ogg/Opus/Vorbis: rewritten pages use the spec Ogg CRC-32 (0x04C11DB7), the Vorbis comment header keeps its framing bit, comment packets spanning pages are rejected instead of left in place, and short packets fail with `FormatException`. Manual verification pending: ffmpeg/VLC decode of a cleaned real `.ogg`.
- ZIP: the registry gives ZIP a removal size limit, so `.zip` files no longer fail with "too large".
- Remover: concurrent or double-started batches are guarded, a batch that throws fails closed, Back is allowed when not processing, and retrying with an invalid folder no longer hangs.
- JPEG: Adobe APP14 and ICC segments are kept; APP11 (JUMBF/C2PA) and other APPn segments are stripped. Manual verification pending: CMYK JPEG colour check.
- PDF removal: blanking is scoped to Info dictionaries (bookmark titles are preserved), indirect values are resolved and blanked, and unresolvable Info fails closed. PDFs whose Info dictionary sits in a compressed object stream are now rejected.
- ZIP-family (OpenXML, ODF, EPUB, APK, ZIP): repack now binds the decoder to the preflighted directory (name, size, CRC and method), timestamps are normalized, and validation reads are bounded. Manual verification pending: opening a cleaned `.docx` in Word/LibreOffice.
- ODF/EPUB/OpenXML: full strip removes the `meta.xml` manifest entry, EPUB `mimetype` position rules are enforced, viewer part resolution follows relationships and prefers the root `meta.xml`, and older OpenOffice manifests with a DOCTYPE are accepted. Manual verification pending: opening a stripped LibreOffice `.odt` with a chart.
- WAV/AIFF (RIFF): `id3 `, `_PMX`, `iXML`, `cart` and AIFF `COMT` chunks are dropped and INFO values have trailing NULs cleaned.
- Output validation: unverified outputs are deleted, and the message is "Output validation failed; the invalid copy was removed". When the persisted file no longer matches and is kept, the message is "Output validation failed; unverified copy may remain".
- Remover messages: deliberate rejections (Ogg/Opus comment packets spanning pages such as cover art, PDF Info in compressed object streams, EPUB mimetype rule violations, ZIP directory mismatch) say what is unsupported instead of "File format invalid or corrupt". The PDF limitations now note keyword false rejections and that output validation re-applies the cleaner's own plan.
- Settings and onboarding: SAF folder picker on Android, mobile-safe export/import, and picker errors are surfaced. Manual verification pending: Android device SAF picker and export.
- iOS: the default output folder is `Documents/MetaStrip`, re-derived when an app update or restore moves the app container, so onboarding and the Remover no longer break on the stale path. Manual verification pending: iOS simulator Files visibility and an app update on device.
- Viewer: PDF trailer Info lookup and string decoding, ID3 (truncated tags, extended header, unsynchronisation, UTF-16 COMM, v1.0, NUL escape), Vorbis (tolerant comments, multi-page packets, a truncation status when the comment packet runs past the 1 MiB read), PNG zTXt/iTXt/eXIf and GIF XMP are now parsed or shown.
- About and Settings: About links point at real destinations with an Android 11+ `<queries>` entry, onboarding resets cleanly, unwired settings show "Not yet applied", and persisted SAF grants are released. Manual verification pending: About links on device.
## v0.1.0 (WIP)

**Status:** In progress. PDF XMP stripping and ZIP stress tests implemented, but crash reporting plan still pending finalization.