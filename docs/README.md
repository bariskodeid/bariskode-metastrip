# MetaStrip
### Metadata Viewer & Remover

> **Strip the invisible. Own your files.**

MetaStrip adalah aplikasi mobile Flutter untuk melihat metadata dari format yang diterima Viewer dan membuat clean copy untuk format yang didukung Remover, sepenuhnya offline di perangkat.

> Status implementasi saat ini: **Implemented-scope MVP** sudah dapat digunakan dan sebagian besar selesai untuk onboarding, Viewer, Remover, dan Settings. **Full product-spec MVP belum selesai**; dukungan video/HEIC, GPS map, share intent, pemrosesan background, mode removal lanjutan, serta kontrol storage/processing lanjutan masih direncanakan, ditunda, atau belum terhubung ke alur aplikasi. **Release-ready product** berarti Full product-spec MVP ditambah verifikasi integrasi/perangkat, performa, aksesibilitas, release build, dan hardening rilis. Seluruh pekerjaan tersebut masih tertunda.

---

```
┌─────────────────────────────────────────┐
│  METASTRIP  v1.0.0                      │
│  ─────────────────────────────────────  │
│  Platform  : Android 7.0+ · iOS 13.0+  │
│  Framework : Flutter 3.22 · Dart 3.4   │
│  License   : MIT                        │
│  Privacy   : 100% Offline · No Servers  │
└─────────────────────────────────────────┘
```

---

## Daftar Isi

- [Fitur](#fitur)
- [Format yang Didukung](#format-yang-didukung)
- [Screenshot & Design](#screenshot--design)
- [Persyaratan](#persyaratan)
- [Instalasi & Setup Development](#instalasi--setup-development)
- [Struktur Project](#struktur-project)
- [Arsitektur](#arsitektur)
- [Dokumentasi](#dokumentasi)
- [Kontribusi](#kontribusi)
- [Lisensi](#lisensi)

---

## Status dan Fitur

### ✅ Implemented-scope MVP
- Onboarding dasar + output folder setup
- System file picker tanpa broad storage permission
- Extension allowlist, dedup, size/session cap
- Detail metadata dasar: file info, MIME, timestamps, SHA-256 untuk file kecil
- Remover dengan progress/cancel/result flow dan clean copy ke output folder tanpa mengubah file asli
- Settings: 7 preset tema + 16-token custom theme, output folder, cache status, portable export/import, reset, About, dan Licenses

### 📅 Full product-spec MVP (planned/follow-up)

### 🔍 Viewer
- Pilih multiple file sekaligus dari file manager atau galeri
- Tampilkan metadata secara sangat detail dalam tampilan accordion per-kategori:
  - GPS & Lokasi (dengan peta mini)
  - Info Kamera/Device (make, model, lens)
  - Tanggal & Waktu (creation, modification, GPS timestamp)
  - Metadata Teknis (resolusi, codec, bitrate, color space)
  - Embedded tags (EXIF, IPTC, XMP, ID3, Vorbis Comments)
  - Properti Dokumen (author, company, revision history)
  - Hash file (MD5 + SHA-256)
  - Raw metadata dump
- Tandai file atau field spesifik untuk dihapus
- Copy nilai metadata ke clipboard
- Warning visual untuk field yang privacy-sensitive (GPS, author, device info)
- Kirim file yang ditandai langsung ke Remover

### 🗑️ Remover
- Terima file dari Viewer atau file picker; share intent masih planned
- Current MVP: clean copies for the 20 registered remover extensions, including ZIP-only, non-recursive container cleanup; PDF DocInfo removal remains best-effort
- Full Strip, Selective, Anonymize, dan Preserve Technical masih planned/unwired; current UI exposes supported-cleanup behavior only
- Output otomatis tersimpan ke folder yang sudah dikonfigurasi
- Progress real-time dengan log detail; background processing dan notifikasi masih planned
- Summary hasil lengkap: berhasil, gagal, ukuran data yang dihapus

### ⚙️ Settings
- **7 preset tema** industrial (Dark Industrial, Steel Blue, Acid Green, Rust, Mercury, Neon Orange, Cobalt) + **16-token custom theme builder**, dengan perubahan tema diterapkan langsung
- Konfigurasi folder output; perubahan disinkronkan dengan konfigurasi onboarding/remover
- Clear cache (saat ini melaporkan 0 karena cache thumbnail/temp belum aktif), About, dan Licenses
- Export/import konfigurasi JSON portabel; path folder output yang device-local tidak diekspor dan import mempertahankan serta memvalidasi folder perangkat saat ini
- Reset settings + konfigurasi onboarding dan kembali ke onboarding; clean copy/output yang sudah dibuat tetap ada
- Model persistence sudah memuat naming template, folder structure, keep-original, JPEG quality, concurrency, dan auto-confirm, tetapi kontrol tersebut belum ditampilkan di UI atau dihubungkan ke pipeline processing

### 🚀 Onboarding
- Wizard slide interaktif di first launch
- Setup folder output sebelum mulai
- System picker access explanation; broad permissions hanya jika fitur future benar-benar membutuhkan

---

## Format yang Didukung

### Viewer allowlist
`JPG/JPEG` · `PNG` · `WebP` · `GIF` · `BMP` · `TIFF/TIF` · `HEIC` · `MP4` · `MOV` · `AVI` · `MKV` · `WebM` · `3GP` · `FLV` · `WMV` · `MP3` · `FLAC` · `AAC` · `OGG` · `WAV` · `M4A` · `Opus` · `WMA` · `AIFF/AIF/AIFC` · `PDF` · `DOCX` · `XLSX` · `PPTX` · `ODT/ODS/ODP` · `RTF` · `TXT` · `ZIP/TAR/APK/EPUB`.

### Registered extractor formats
`JPG/JPEG` · `TIFF/TIF` · `PNG` · `GIF` · `WebP` · `BMP` · `MP3` · `FLAC` · `OGG` · `Opus` · `WAV` · `AIFF` · `PDF` · `DOCX/XLSX/PPTX` · `ODT/ODS/ODP` · `ZIP/APK/EPUB`.

### Remover registry
`JPG/JPEG` · `PNG` · `PDF` · `BMP` · `MP3` · `FLAC` · `OGG` · `Opus` · `WAV` · `AIFF` · `DOCX/XLSX/PPTX` · `ODT/ODS/ODP` · `GIF` · `WebP`.

HEIC/HEIF, RAW, M4V, legacy Office, GZ/BZ2, video, archives, granular audio removal, and per-property Office removal are not current supported-removal features.

---

## Screenshot & Design

MetaStrip menggunakan bahasa desain **Industrial Minimalism**:
- Latar belakang gelap mendominasi (near-black charcoal)
- Tipografi target: **Bebas Neue** (display) + **Space Mono** (heading) + **IBM Plex Mono** (body); asset font custom belum dibundel sehingga runtime menggunakan system fallback
- Palet warna diambil dari material industri: besi, karat, beton
- Border radius minimal — sudut tajam, angular
- Aksen warna sparingly untuk signaling, bukan dekorasi

Lihat [DESIGN.md](./DESIGN.md) untuk dokumentasi design system lengkap.

---

## Persyaratan

| Platform | Minimum |
|----------|---------|
| Android  | 7.0 Nougat (API 24) |
| iOS      | iOS 13.0 |
| Flutter  | 3.22.x |
| Dart     | 3.4.x |

### Development Tools
- Flutter SDK 3.22+
- Android Studio / VS Code dengan Flutter extension
- Xcode 15+ (untuk iOS build)
- Git

---

## Instalasi & Setup Development

### 1. Clone Repository
```bash
git clone https://github.com/username/metastrip.git
cd metastrip
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Code Generation
Tidak diperlukan untuk MVP saat ini.

### 4. Fonts
Custom font assets belum dibundel pada MVP saat ini. Runtime menggunakan system
fallback; tidak ada langkah download font yang diperlukan untuk development.

### 5. Setup Android
```bash
# Pastikan Android SDK terinstall
flutter doctor

# Build debug
flutter build apk --debug
```

### 6. Run Development
```bash
# Run di device/emulator
flutter run

# Run dengan hot reload
flutter run --hot

# Run di device spesifik
flutter run -d <device_id>

# List connected devices
flutter devices
```

### 7. Run Tests
```bash
# Unit tests
flutter test

# Tests dengan coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Integration tests belum tersedia dan direncanakan untuk Phase 6.
```

---

## Struktur Project

```
metastrip/
├── lib/
│   ├── app/                    # Root app, router, DI
│   ├── core/                   # Constants, utils, theme, permissions
│   ├── features/
│   │   ├── onboarding/         # Onboarding wizard
│   │   ├── viewer/             # Metadata viewer
│   │   ├── remover/            # Metadata remover
│   │   └── settings/           # App settings
│   └── shared/                 # Shared widgets & services
│
├── test/                       # Unit & widget tests
│   └── fixtures/               # Sample files untuk testing
│
├── android/                    # Android native config
├── ios/                        # iOS native config
│
├── assets/
│   ├── fonts/                  # BebasNeue, SpaceMono, IBMPlexMono
│   ├── illustrations/          # SVG onboarding illustrations
│   ├── icons/                  # App icon
│   └── textures/               # Noise texture
│
├── docs/                       # Dokumentasi tambahan
│
├── SPECS.md                    # Product specification
├── DESIGN.md                   # Design system
├── IMPLEMENTATION_PLAN.md      # Implementation plan & sprints
├── README.md                   # This file
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Arsitektur

MetaStrip menggunakan **Clean Architecture** dengan **feature-first folder structure** dan **BLoC** untuk state management.

```
┌─────────────────────────────────────────────────┐
│                PRESENTATION LAYER               │
│   Flutter Widgets → BLoC/Cubit → UI State       │
├─────────────────────────────────────────────────┤
│                  DOMAIN LAYER                   │
│   Use Cases → Entities → Repository Interfaces  │
├─────────────────────────────────────────────────┤
│                   DATA LAYER                    │
│   Repository Impl → Data Sources → Models       │
│   (SharedPreferences, File System, custom       │
│    format parsers)                              │
└─────────────────────────────────────────────────┘
```

### Prinsip Utama
- **Unidirectional Data Flow** — Event → BLoC → State → UI
- **Dependency Inversion** — Domain tidak bergantung ke Data layer
- **Isolate-based Processing** — Semua metadata processing berat berjalan di Dart Isolate agar UI tetap smooth
- **Offline-first** — Tidak ada network request untuk processing
- **Immutable State** — Semua state menggunakan `freezed`/`equatable`

### Key Design Decisions

| Keputusan | Pilihan | Alasan |
|-----------|---------|--------|
| State management | BLoC | Mature, testable, unidirectional |
| Navigation | MaterialApp + Navigator | Simple MVP flow |
| DI | Direct constructors | Simple MVP wiring |
| Heavy processing | Dart Isolate | Non-blocking UI thread while the app remains foregrounded; OS background execution is planned |
| Video processing | Deferred | FFmpeg Kit was retired; no current video extractor/remover |
| Image EXIF | `exif` package | Pure Dart, no native dependency |
| PDF | Custom pure-Dart parser/sanitizer | DocInfo + XMP extraction; best-effort DocInfo removal |

---

## Dokumentasi

| File | Deskripsi |
|------|-----------|
| [SPECS.md](./SPECS.md) | Spesifikasi produk lengkap: format yang didukung, fitur detail, edge cases, performance requirements |
| [DESIGN.md](./DESIGN.md) | Design system: color tokens, typography, spacing, component library, screen specifications, animations |
| [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) | Rencana implementasi teknis: arsitektur, dependencies, sprint plan, code examples, testing strategy |
| [README.md](./README.md) | This file — project overview & setup guide |

---

## Dependency Highlights

| Package | Version | Fungsi |
|---------|---------|--------|
| `flutter_bloc` | ^8.1.5 | State management |
| `exif` | ^3.3.0 | JPEG/TIFF EXIF extraction |
| `image` | ^4.2.0 | PNG/GIF/BMP/WebP processing |
| `archive` | ^3.6.0 | ZIP/DOCX/ODF/APK parsing |
| `file_picker` | ^8.0.6 | Multi-file selection |
| `crypto` | ^3.0.3 | SHA-256 hashing |

`receive_sharing_intent`, `permission_handler`, and `dartz` are planned and are not current dependencies.

> **Phase 2 dependency note:** `ffmpeg_kit_flutter_full_gpl`, `syncfusion_flutter_pdf`,
> and `id3_codec` were the originally planned Phase 2 dependencies but were
> deliberately not added. `ffmpeg_kit_flutter_full_gpl` was retired upstream and
> breaks on Flutter ≥3.29; video extraction is deferred. `syncfusion_flutter_pdf`
> requires a commercial or Syncfusion Community license key; PDF extraction was
> replaced by a pure-Dart Info dictionary + XMP packet parser. ID3 parsing was
> replaced by a manual ID3v2.2/2.3/2.4 + ID3v1.1 parser.

---

## Privacy & Security

MetaStrip dirancang dengan **privacy-by-design**:

- ✅ **100% Offline** — tidak ada data yang dikirim ke server manapun
- ✅ **No analytics** — tidak ada tracking, tidak ada telemetri
- ✅ **No ads** — tidak ada iklan, tidak ada SDK pihak ketiga untuk monetisasi
- ✅ **On-device only** — semua pemrosesan terjadi di perangkatmu
- ✅ **Open source** — kode dapat diaudit oleh siapapun
- ✅ **File asli aman** — MetaStrip hanya menulis ke file output, tidak memodifikasi file aslimu

Data persisten lokal pada MVP saat ini hanya konfigurasi aplikasi di
`SharedPreferences`, termasuk setting/preferensi dan path folder output yang
dipilih. Riwayat pemrosesan berbasis SQLite dan cache thumbnail masih planned;
aksi Clear Cache saat ini adalah no-op dan melaporkan 0 byte.

---

## Kontribusi

Kontribusi dapat diajukan melalui pull request dengan alur berikut.

### Quick Start
```bash
# Fork repository
# Buat branch baru
git checkout -b feature/support-new-format

# Commit dengan conventional commits
git commit -m "feat(extractor): add support for AVIF format"

# Push & buat Pull Request
git push origin feature/support-new-format
```

### Panduan Commit
Gunakan [Conventional Commits](https://www.conventionalcommits.org/):
```
feat:     Fitur baru
fix:      Bugfix
docs:     Perubahan dokumentasi
style:    Formatting, tidak ada perubahan logika
refactor: Refactoring code
test:     Tambah atau ubah tests
chore:    Build process, dependency update
```

### Menambah Format Baru
1. Tambahkan extension ke `lib/core/constants/supported_extensions.dart`
2. Buat extractor di `lib/features/viewer/data/datasources/`
3. Buat remover di `lib/features/remover/data/datasources/`
4. Register di switch statement `_extractByFormat()` di `MetadataExtractorDatasourceImpl`
5. Tambahkan test dengan sample file di `test/fixtures/`

---

## Roadmap

### v1.0 (Initial Release)
- [x] Onboarding wizard
- [x] Viewer dengan detail metadata
- [x] Remover supported-cleanup flow for the registered formats
- [x] 7 preset tema + 16-token custom theme
- [ ] Full Strip, Selective, Anonymize, dan Preserve Technical modes
- [ ] Share intent support
- [ ] Background processing dengan notifikasi

### v1.1
- [ ] Riwayat processing (history screen)
- [ ] Batch template presets (simpan konfigurasi removal yang sering dipakai)
- [ ] Metadata comparison (before/after side by side)
- [ ] Widget homescreen (quick-strip file terbaru)

### v1.2
- [ ] Multiple language support (Arabic, Spanish, French)
- [ ] Cloud file support (Google Drive — download → process → upload)
- [ ] QR Code generator dari metadata tertentu

### v2.0
- [ ] Desktop support (Windows/macOS/Linux via Flutter Desktop)
- [ ] Batch scheduling (proses file pada waktu tertentu)
- [ ] Plugin system untuk format baru

---

## Lisensi

```
MIT License

Copyright (c) 2026 MetaStrip Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Kredit & Acknowledgements

- [Lucide Icons](https://lucide.dev/) — Icon set (ISC license)
- [Space Mono](https://fonts.google.com/specimen/Space+Mono) by Colophon Foundry (OFL)
- [IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono) by IBM (OFL)
- [Bebas Neue](https://fonts.google.com/specimen/Bebas+Neue) by Flat-it (OFL)
- Flutter BLoC pattern oleh Felix Angelov

---

<div align="center">

**MetaStrip** · Built with Flutter · Privacy First

*Strip the invisible. Own your files.*

</div>
