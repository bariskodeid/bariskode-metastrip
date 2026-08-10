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

MetaStrip adalah aplikasi mobile untuk melihat dan menghapus metadata dari foto, audio, dokumen, dan arsip secara offline. Aplikasi membuat clean copy tanpa mengubah file asli, menjaga privasi Anda sepenuhnya di perangkat.

---

## Fitur Utama

### Viewer
- Pilih file melalui system picker dan lihat metadata terstruktur
- Ekstraksi metadata filesystem, EXIF, audio tags, properti dokumen, dan entri arsip
- Salin nilai metadata ke clipboard
- Tandai file atau field tertentu untuk penghapusan selective

### Remover
- Buat clean copy untuk format yang didukung
- Penghapusan full cleanup dan selective removal untuk stable-ID metadata
- Proses berurutan dengan progress, log per-file, dan cancel
- Output collision-safe dengan suffix `_clean`
- File asli tetap tidak diubah

### Selective Removal
- PNG text chunks
- PDF DocInfo
- FLAC Vorbis comments
- WAV LIST INFO
- Open XML core/app properties
- ODF meta.xml

### Settings
- 7 preset tema + custom theme builder
- Output folder sinkronisasi antar onboarding dan remover
- Portable JSON export/import
- Reset dua langkah tanpa menghapus clean copy
- About, version, licenses, dan cache status

---

## Format yang Didukung

### Ekstraksi Viewer
- **Gambar:** JPG, JPEG, PNG, WebP, GIF, BMP, TIFF, TIF, HEIC
- **Video:** MP4, MOV, AVI, MKV, WebM, 3GP, FLV, WMV
- **Audio:** MP3, FLAC, AAC, OGG, WAV, M4A, Opus, WMA, AIFF, AIF, AIFC
- **Dokumen:** PDF, DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF, TXT
- **Arsip:** ZIP, TAR, APK, EPUB

### Clean Copy Removal
JPG/JPEG, PNG, PDF, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, DOCX, XLSX, PPTX, ODT, ODS, ODP, GIF, WebP, ZIP

---

## Privasi

- Semua pemrosesan terjadi di perangkat Anda
- Tidak ada upload ke server
- Tidak ada analytics atau tracking
- Tidak ada iklan
- File asli tidak diubah
- Open source

---

## Arsitektur

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

## Memulai

### Prasyarat
- Flutter SDK 3.22+
- Dart SDK 3.4+
- Android Studio / VS Code dengan Flutter extension

### Instalasi

```bash
git clone https://github.com/bariskodeid/bariskode-metastrip.git
cd metastrip
flutter pub get
```

### Menjalankan Aplikasi

```bash
flutter run
```

### Build

```bash
# Debug APK
flutter build apk --debug

# Release APK (memerlukan signing config)
flutter build apk --release
```

### Testing

```bash
flutter analyze
flutter test
```

---

## Dokumentasi

- [SPECS.md](docs/SPECS.md) — Spesifikasi produk
- [DESIGN.md](docs/DESIGN.md) — Sistem desain
- [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) — Rencana implementasi
- [SETUP_COMPLETE.md](SETUP_COMPLETE.md) — Laporan progres MVP
- [DEVICE_AND_STRESS_TEST_PLAN.md](docs/DEVICE_AND_STRESS_TEST_PLAN.md) — Rencana pengujian device dan stress
- [RELEASE_SIGNING_CHECKLIST.md](docs/RELEASE_SIGNING_CHECKLIST.md) — Checklist signing release
- [PLAY_STORE_LISTING.md](docs/PLAY_STORE_LISTING.md) — Deskripsi Google Play

---

## Status Proyek

**Fase Saat Ini:** Implemented-scope MVP — usable dan sebagian besar selesai.

### Yang Sudah Diimplementasikan
- Onboarding + output folder setup
- System picker + SAF, tanpa broad storage permission
- Viewer: ekstraksi metadata untuk format terdaftar
- Remover: clean copy untuk 20 ekstensi terdaftar
- Selective removal untuk PNG, PDF, FLAC, WAV INFO, Open XML, ODF
- Remover UI: queue, processing, result
- Settings: tema, output folder, import/export, reset
- ZIP hardening, PDF linear scan, error sanitization

### Yang Direncanakan
- Video dan HEIC/HEIF support
- Share intent
- Background processing + notifikasi
- Mode penghapusan: Full Strip, Anonymize, Preserve Technical
- Device/SAF validation dan stress testing
- Performance dan accessibility verification

---

## Kontribusi

Kontribusi sangat diterima! Silakan buka issue atau pull request.

1. Fork repositori
2. Buat branch fitur (`git checkout -b feature/amazing-feature`)
3. Commit perubahan (`git commit -m 'Add amazing feature'`)
4. Push ke branch (`git push origin feature/amazing-feature`)
5. Buka Pull Request

---

## Lisensi

MIT License — lihat file [LICENSE](LICENSE) untuk detail.

---

## Credits

- [Lucide Icons](https://lucide.dev/) — Ikon
- Flutter BLoC pattern oleh Felix Angelov

---

<p align="center">
  <strong>MetaStrip</strong> · Built with Flutter · Privacy First
</p>

<p align="center">
  <em>Strip the invisible. Own your files.</em>
</p>
