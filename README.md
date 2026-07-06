# MetaStrip - Metadata Viewer & Remover

> **Strip the invisible. Own your files.**

MetaStrip adalah aplikasi mobile Flutter untuk melihat dan menghapus metadata dari hampir semua jenis file — foto, video, audio, dan dokumen — sepenuhnya offline, langsung di perangkatmu.

## 🚀 Project Status

**Current Phase:** Phase 4 Remover UI ✅ **DONE** · Phase 2/5/6 pending

Implemented now: onboarding, system file picker, file validation, basic file metadata, MIME lookup, small-file SHA-256, detail screen, JPEG/PNG/PDF remover MVP with full RemoverBloc + ProcessingScreen (live progress + cancel) + ResultScreen (stats grid).

Planned next: PDF scrubber rewrite (critical — regex is unsafe), deeper format-specific extraction, share intent, settings, e2e hardening.

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
- Display: Bebas Neue 48sp
- Headings: Space Mono Bold
- Body: IBM Plex Mono
- Monospace data: IBM Plex Mono

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

### ✅ Implemented MVP
- Onboarding wizard
- Output folder selection stored locally on-device
- System picker based file import
- Extension allowlist, duplicate/size/session validation
- Basic file metadata detail screen
- MIME lookup and SHA-256 for files up to 100MB
- Best-effort remover MVP for JPEG, PNG text chunks, and basic PDF DocInfo entries
- Clean copies are written to configured output folder when writable; originals are preserved
- Full Remover UI: RemoverBloc with sequential processing + cancel, ProcessingScreen with live progress bar + result log, ResultScreen with stats grid (stripped/failed/total/bytes)
- Security hardening: JPEG ICC (APP2) + Adobe (APP14) stripping, PNG `tIME` stripping, error message path sanitization, queue cap enforcement

### 📅 Planned

#### 🔍 Viewer
- View metadata from 40+ file formats
- GPS location with map preview
- Camera/device info
- Timestamps and technical metadata
- Mark files/fields for removal

#### 🗑️ Remover
- MVP: JPEG/PNG/PDF clean-copy stripping
- 4 removal modes: Full Strip, Selective, Anonymize, Preserve Technical
- Batch processing
- Background processing with notifications
- Progress tracking with logs

#### ⚙️ Settings
- 8 color themes + custom
- Output folder configuration
- JPEG quality control
- Processing options

#### 🚀 Onboarding
- Interactive wizard
- Folder setup
- Permission requests

## 📱 Supported File Types

### Images
JPG, PNG, WebP, GIF, BMP, TIFF, HEIC, RAW formats

### Videos
MP4, MOV, AVI, MKV, WebM, 3GP, FLV, WMV

### Audio
MP3, FLAC, AAC, OGG, WAV, M4A, Opus, WMA, AIFF

### Documents
PDF, DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF, TXT

### Archives
ZIP, TAR, APK, EPUB

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
- [SETUP_COMPLETE.md](SETUP_COMPLETE.md) - Phase 0 completion report

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

### ✅ Phase 0: Project Setup (COMPLETE)
- Flutter project initialization
- Folder structure
- Dependencies configuration
- Theme system
- Shared widgets
- Basic tests

### 🔄 Phase 1: Onboarding (Next - 1 week)
- Onboarding wizard
- 5 slides with animations
- Folder setup
- Permission requests

### 📅 Phase 2: Core - Metadata Engine (2 weeks)
- Metadata extraction for all formats
- Metadata removal engine
- Isolate-based processing

### 📅 Phase 3: Viewer UI (1.5 weeks)
- File list screen
- Metadata detail screen
- Mark for removal

### 📅 Phase 4: Remover UI (1 week)
- Remover queue
- Processing screen
- Result screen

### 📅 Phase 5: Settings (0.5 week)
- Settings screen
- Theme picker
- App management

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

- [FFmpeg](https://ffmpeg.org/) - Video & audio processing
- PDF DocInfo scrub uses an MVP custom byte-level sanitizer; deep XMP scrub is pending.
- [Lucide Icons](https://lucide.dev/) - Icon set
- Flutter BLoC pattern by Felix Angelov

---

<div align="center">

**MetaStrip** · Built with Flutter · Privacy First

*Strip the invisible. Own your files.*

**Version:** 1.0.0+1  
**Status:** 🚧 In Development

</div>
