# MetaStrip - Metadata Viewer & Remover

> **Strip the invisible. Own your files.**

MetaStrip adalah aplikasi mobile Flutter untuk melihat metadata dari format yang diterima Viewer dan membuat clean copy untuk format yang didukung Remover, sepenuhnya offline di perangkat.

## 🚀 Project Status

**Current Phase:** Implemented-scope MVP ✅ **usable / mostly complete** · Full product-spec MVP and release-readiness work remain pending

Implemented now: onboarding, system file picker, file validation, format-specific metadata extraction where a parser is registered, small-file SHA-256, a 20-extension remover registry with ZIP-only container cleanup, RemoverBloc + ProcessingScreen + ResultScreen, and Settings for themes, output folder, maintenance, portable import/export, and reset.

Planned next: deeper PDF stripping, video/HEIC support, share intent, unexposed processing controls, and e2e hardening.

### Status terminology

- **Implemented-scope MVP:** the currently usable feature set for the registered Viewer extractors and 20 Remover extensions. This scope is substantially implemented, but still has known limitations such as best-effort PDF cleanup and ZIP-only, non-recursive container cleanup.
- **Full product-spec MVP:** all capabilities described in [SPECS.md](docs/SPECS.md), including broader format support, removal modes, sharing, background processing, and the remaining Viewer features. This is **not complete**.
- **Release-ready product:** full product-spec scope plus integration/device testing, performance and accessibility verification, release-build validation, and release hardening. This is **not complete**.

## 📋 Quick Start

### Prerequisites
- Flutter SDK 3.22+ (Currently using 3.41.7)
- Dart SDK 3.4+ (Currently using 3.11.5)
- Android Studio / VS Code with Flutter extension
- Git

### Installation

```bash
# Clone repository
git clone https://github.com/username/metastrip.git
cd metastrip

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run app
flutter run
```

## 🏗️ Architecture

**Pattern:** Clean Architecture + Feature-first folder structure  
**State Management:** BLoC / Cubit  
**Navigation:** MaterialApp + Navigator  
**Dependency Injection:** direct constructors for MVP

```
lib/
├── app/                    # Root app, router, DI
├── core/                   # Constants, utils, theme, permissions
├── features/
│   ├── onboarding/         # Onboarding wizard
│   ├── viewer/             # Metadata viewer
│   ├── remover/            # Metadata remover
│   └── settings/           # App settings
└── shared/                 # Shared widgets & services
```

## 🎨 Design System

**Design Language:** Industrial Minimalism

### Color Themes (7 presets)
- **Dark Industrial** (Default) - Near-black with rust orange accent
- **Steel Blue** - Dark blue with steel blue accent
- **Acid Green** - Dark green with neon green accent
- **Rust** - Dark brown with rust accent
- **Mercury** (Light Mode) - Light gray
- **Neon Orange** - Dark with neon orange
- **Cobalt** - Dark blue with cobalt

### Typography
- Design target: Bebas Neue display, Space Mono headings, and IBM Plex Mono body/data
- Runtime: custom font assets are not currently bundled; system fallbacks are used

### Spacing
- Base unit: 4dp
- Scale: 4, 8, 16, 24, 32, 48, 64

## 📦 Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^8.1.5 | State management |
| `exif` | ^3.3.0 | JPEG/TIFF EXIF extraction |
| `image` | ^4.2.0 | PNG/GIF/BMP/WebP processing |

## 🎯 Features

### ✅ Implemented-scope MVP
- Onboarding wizard
- Output folder selection stored locally on-device
- System-picker scoped file access; users explicitly choose files and no broad OS storage permission is requested
- Extension allowlist, duplicate/size/session validation
- Basic file metadata detail screen
- MIME lookup and SHA-256 for files up to 100MB
- Best-effort remover MVP for 20 registered extensions: JPG/JPEG, PNG, PDF, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, DOCX, XLSX, PPTX, ODT, ODS, ODP, GIF, WebP, and ZIP
- ZIP cleanup removes container EOCD/entry comments, DOS timestamps, and recognized `0x5455`/`0x000a` timestamp extras. Unknown extras and platform/external attributes remain. Compressed member payloads are preserved without decompression or payload CRC verification; member metadata is not recursively cleaned.
- Clean copies are written to configured output folder when writable; originals are preserved
- Full Remover UI: RemoverBloc with sequential processing + cancel, ProcessingScreen with live progress bar + result log, ResultScreen with stats grid (stripped/failed/total/bytes)
- Security hardening: JPEG ICC (APP2) + Adobe (APP14) stripping, PNG `tIME` stripping, error message path sanitization, queue cap enforcement
- Settings: 7 preset themes plus a persisted 16-token custom theme builder, output-folder changes synchronized with onboarding/removal, cache status, About/Licenses, portable JSON import/export, and two-step reset
- Settings export excludes the device-local output folder; import preserves and validates the current device folder
- Reset clears app settings, theme/output-folder configuration, and onboarding state, then returns to onboarding; generated clean copies are not deleted

### 📅 Planned / Follow-up

#### 🔍 Viewer
- Planned: view metadata from 40+ file formats; current support is limited to the Viewer allowlist and registered extractors described above
- GPS location with map preview
- Camera/device info
- Timestamps and technical metadata
- Mark files/fields for removal

#### 🗑️ Remover
- Current MVP: registered-format clean-copy stripping; PDF removal is best-effort DocInfo only
- Planned/unwired removal modes: Full Strip, Selective, Anonymize, Preserve Technical (current pipeline uses the supported-cleanup behavior)
- Batch processing with the current sequential queue, progress, cancellation, and result log
- Planned: background processing with notifications

#### ⚙️ Settings
- Storage naming/folder-structure controls and processing controls (JPEG quality, concurrency, auto-confirm) exist in the persisted settings model but are not exposed or wired to processing in the current UI

#### 🚀 Onboarding
- Interactive wizard
- Folder setup
- System-picker scoped access explanation; no broad OS storage permission request

## 📱 Supported File Types

### Viewer allowlist
The Viewer accepts these extensions for file selection and filesystem metadata:

JPG, JPEG, PNG, WebP, GIF, BMP, TIFF, TIF, HEIC, MP4, MOV, AVI, MKV, WebM, 3GP, FLV, WMV, MP3, FLAC, AAC, OGG, WAV, M4A, Opus, WMA, AIFF, AIF, AIFC, PDF, DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF, TXT, ZIP, TAR, APK, EPUB.

The Viewer has registered payload extractors for: JPG/JPEG, TIFF/TIF, PNG, GIF, WebP, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, PDF, DOCX, XLSX, PPTX, ODT, ODS, ODP, ZIP, APK, and EPUB. Other allowlisted formats currently surface filesystem fields only. HEIC is allowlisted but filesystem-only; HEIF, RAW, M4V, legacy Office, GZ, and BZ2 are omitted from the current allowlist and parser registry.

### Remover registry
The Remover can currently create clean copies for: JPG/JPEG, PNG, PDF, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, DOCX, XLSX, PPTX, ODT, ODS, ODP, GIF, WebP, and ZIP. WAV selective removal is limited to eleven allowlisted `LIST INFO` stable IDs; AIFF selective removal remains disabled. ZIP support is container-only and non-recursive. APK and EPUB remain unsupported for removal; video, HEIC/HEIF, RAW, legacy Office, and broader granular audio removal remain deferred.


## 🔒 Privacy

- ✅ Offline MVP - no server communication in implemented Dart flow
- ✅ No analytics/tracking code in implemented MVP
- ✅ No ads
- ✅ On-device only processing
- ✅ Open source
- ✅ Viewer MVP does not modify/delete originals

## 📚 Documentation

- [SPECS.md](docs/SPECS.md) - Product specification
- [DESIGN.md](docs/DESIGN.md) - Design system
- [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) - Technical implementation plan
- [SETUP_COMPLETE.md](SETUP_COMPLETE.md) - MVP progress and verification report

## 🛠️ Development

### Run Tests
```bash
flutter test
```

### Code Analysis
```bash
flutter analyze
```

### Build
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

## 📈 Development Roadmap

### 🟡 Phase 0: Project Setup (10/11, 90.9% complete; flavors deferred)
- Flutter project initialization
- Folder structure
- Dependencies configuration
- Theme system
- Shared widgets
- Basic tests
- Deferred: Android/iOS flavor configuration

### ✅ Phase 1: Onboarding (COMPLETE)
- Onboarding wizard
- 5 slides with animations
- Folder setup
- System-picker scoped access explanation; no broad OS storage permission request

### ✅ Phase 2: Core - Metadata Engine (implemented-scope MVP complete; follow-ups remain)
- Metadata extraction for registered formats; filesystem metadata for other allowlisted files
- Metadata removal engine for the current registered remover formats
- Isolate-based extraction and processing helpers (foreground app flow; background processing is planned)

### ✅ Phase 3: Viewer UI (implemented-scope MVP complete; follow-ups remain)
- File list screen
- Metadata detail screen
- Mark for removal

### ✅ Phase 4: Remover UI (implemented-scope MVP complete; follow-ups remain)
- Remover queue
- Processing screen
- Result screen

### ✅ Phase 5: Settings (implemented-scope MVP complete)
- Settings screen and live theme application
- 7 preset themes plus 16-token custom theme builder
- Output-folder configuration synchronized with onboarding
- Portable settings import/export, cache status, reset, About, and Licenses
- Advanced storage/processing controls remain unexposed and unwired

### 📅 Phase 6: Polish & Testing (1 week)
- Unit tests
- Widget tests
- Integration tests
- Performance profiling

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Credits

- PDF DocInfo scrub uses an MVP custom byte-level sanitizer with bounded
  generated-byte mutation validation. Recognized Info-key candidates are
  bounded, and malformed supported Info values fail closed. This does not read persisted output back or
  claim PDF structure, rendering, or comprehensive metadata removal. Deep XMP
  scrub remains pending.
- [Lucide Icons](https://lucide.dev/) - Icon set
- Flutter BLoC pattern by Felix Angelov

---

<div align="center">

**MetaStrip** · Built with Flutter · Privacy First

*Strip the invisible. Own your files.*

**Version:** 1.0.0+1  
**Status:** 🚧 In Development

</div>
