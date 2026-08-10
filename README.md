# MetaStrip

<p align="center">
  <strong>Strip the invisible. Own your files.</strong>
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.22%2B-02569B?logo=flutter">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.4%2B-0175C2?logo=dart">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-green">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey">
</p>

MetaStrip is a mobile application for viewing and removing metadata from photos, audio, documents, and archives offline. The app creates clean copies without modifying the original files, keeping your privacy entirely on-device.

---

## Main Features

### Viewer
- Select files via system picker and view structured metadata
- Extract filesystem metadata, EXIF, audio tags, document properties, and archive entries
- Copy metadata values to clipboard
- Mark specific files or fields for selective removal

### Remover
- Create clean copies for supported formats
- Full cleanup and selective removal for stable-ID metadata
- Sequential processing with progress, per-file log, and cancel
- Collision-safe output with `_clean` suffix
- Original files remain untouched

### Selective Removal
- PNG text chunks
- PDF DocInfo
- FLAC Vorbis comments
- WAV LIST INFO
- Open XML core/app properties
- ODF meta.xml

### Settings
- 7 preset themes + custom theme builder
- Output folder synchronization between onboarding and remover
- Portable JSON export/import
- Two-step reset without deleting clean copies
- About, version, licenses, and cache status

---

## Supported Formats

### Viewer Extraction
- **Images:** JPG, JPEG, PNG, WebP, GIF, BMP, TIFF, TIF, HEIC
- **Video:** MP4, MOV, AVI, MKV, WebM, 3GP, FLV, WMV
- **Audio:** MP3, FLAC, AAC, OGG, WAV, M4A, Opus, WMA, AIFF, AIF, AIFC
- **Documents:** PDF, DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF, TXT
- **Archives:** ZIP, TAR, APK, EPUB

### Clean Copy Removal
JPG/JPEG, PNG, PDF, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, DOCX, XLSX, PPTX, ODT, ODS, ODP, GIF, WebP, ZIP

---

## Privacy

- All processing happens on your device
- No upload to servers
- No analytics or tracking
- No ads
- Original files are not modified
- Open source

---

## Architecture

- **Pattern:** Clean Architecture + Feature-first
- **State Management:** BLoC / Cubit
- **Navigation:** MaterialApp + Navigator
- **DI:** Direct constructor composition

```
lib/
├── app/                     # Root app, providers
├── core/
│   ├── constants/           # App constants, format registry
│   ├── errors/              # Exceptions and failures
│   ├── processing/          # ZIP/worker helpers
│   ├── storage/             # SharedPreferences wrapper
│   ├── theme/               # 7 presets, typography, spacing
│   └── utils/               # File utilities
├── features/
│   ├── onboarding/          # Onboarding wizard
│   ├── viewer/              # Metadata viewer
│   ├── remover/             # Metadata remover
│   └── settings/            # App settings
└── shared/widgets/          # Reusable widgets
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.22+
- Dart SDK 3.4+
- Android Studio / VS Code with Flutter extension

### Installation

```bash
git clone https://github.com/bariskodeid/bariskode-metastrip.git
cd metastrip
flutter pub get
```

### Running the App

```bash
flutter run
```

### Build

```bash
# Debug APK
flutter build apk --debug

# Release APK (requires signing config)
flutter build apk --release
```

### Testing

```bash
flutter analyze
flutter test
```

---

## Documentation

- [SPECS.md](docs/SPECS.md) — Product specification
- [DESIGN.md](docs/DESIGN.md) — Design system
- [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) — Implementation plan
- [SETUP_COMPLETE.md](SETUP_COMPLETE.md) — MVP progress report
- [DEVICE_AND_STRESS_TEST_PLAN.md](docs/DEVICE_AND_STRESS_TEST_PLAN.md) — Device and stress test plan
- [RELEASE_SIGNING_CHECKLIST.md](docs/RELEASE_SIGNING_CHECKLIST.md) — Release signing checklist
- [PLAY_STORE_LISTING.md](docs/PLAY_STORE_LISTING.md) — Google Play description

---

## Project Status

**Current Phase:** Implemented-scope MVP — usable and mostly complete.

### Implemented
- Onboarding + output folder setup
- System picker + SAF, without broad storage permission
- Viewer: metadata extraction for registered formats
- Remover: clean copy for 20 registered extensions
- Selective removal for PNG, PDF, FLAC, WAV INFO, Open XML, ODF
- Remover UI: queue, processing, result
- Settings: themes, output folder, import/export, reset
- ZIP hardening, PDF linear scan, error sanitization

### Planned
- Video and HEIC/HEIF support
- Share intent
- Background processing + notifications
- Removal modes: Full Strip, Anonymize, Preserve Technical
- Device/SAF validation and stress testing
- Performance and accessibility verification

---

## Contributing

Contributions are welcome! Please open an issue or pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Credits

- [Lucide Icons](https://lucide.dev/) — Icons
- Flutter BLoC pattern by Felix Angelov

---

<p align="center">
  <strong>MetaStrip</strong> · Built with Flutter · Privacy First
</p>

<p align="center">
  <em>Strip the invisible. Own your files.</em>
</p>
