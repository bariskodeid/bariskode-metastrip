# SPECS.md — Product Specification
## MetaStrip: Metadata Viewer & Remover
**Version:** 1.0.0  
**Platform:** Flutter (Android-first, iOS ready)  
**Last Updated:** 2026-08-06

---

## 1. Overview

MetaStrip adalah aplikasi mobile berbasis Flutter yang memungkinkan pengguna untuk:
1. **Melihat metadata** dari hampir semua jenis file secara sangat detail
2. **Menghapus metadata** dari file tersebut secara aman, dengan output disimpan ke folder yang telah dikonfigurasi

Target pengguna: jurnalis, fotografer, aktivis privasi, developer, dan pengguna umum yang peduli dengan privasi digital.

---

## 2. Supported File Types & Metadata Coverage

### 2.1 Image Files
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.jpg` / `.jpeg` | `exif` package | EXIF (GPS, kamera, lensa, tanggal, orientasi, ISO, aperture, shutter speed, focal length), IPTC (caption, keywords, copyright), XMP |
| `.png` | `image` package | tEXt/zTXt chunks (author, creation time, software, comment), iTXt chunks |
| `.webp` | `image` package | EXIF embedded, XMP |
| `.gif` | `image` package | Comment extension, Netscape extension |
| `.bmp` | Custom parser | Header metadata (color depth, resolution) |
| `.tiff` / `.tif` | `exif` package | Full EXIF, IPTC, GPS, thumbnail embedded |
| `.heic` / `.heif` | Native + `exif` | EXIF full, GPS, color profile |
| `.raw` / `.cr2` / `.nef` / `.arw` / `.dng` | `exif` package | Manufacturer metadata, lens data, full EXIF |

### 2.2 Video Files
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.mp4` / `.m4v` | `ffmpeg_kit_flutter` | Container metadata (title, author, date, GPS, encoder, duration, bitrate, resolution, codec info, creation_time) |
| `.mov` | `ffmpeg_kit_flutter` | Apple QuickTime metadata atoms, GPS track |
| `.avi` | `ffmpeg_kit_flutter` | RIFF INFO chunk metadata |
| `.mkv` | `ffmpeg_kit_flutter` | MKV Tags (title, artist, date, encoder, language, chapters) |
| `.webm` | `ffmpeg_kit_flutter` | WebM/Matroska tags |
| `.3gp` | `ffmpeg_kit_flutter` | 3GPP metadata |
| `.flv` | `ffmpeg_kit_flutter` | FLV metadata AMF |
| `.wmv` | `ffmpeg_kit_flutter` | ASF metadata object |

### 2.3 Audio Files
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.mp3` | `id3_codec` / custom | ID3v1, ID3v2 (title, artist, album, year, genre, comment, lyrics, album art, BPM, composer, conductor, copyright, URL) |
| `.flac` | Custom parser | Vorbis Comments (full), STREAMINFO, PICTURE block |
| `.aac` | `ffmpeg_kit_flutter` | iTunes-style atoms |
| `.ogg` | Custom parser | Vorbis Comments |
| `.wav` | Custom parser | RIFF INFO chunk, BEXT chunk (broadcast), iXML |
| `.m4a` | `ffmpeg_kit_flutter` | iTunes metadata atoms |
| `.opus` | Custom parser | OpusTags |
| `.wma` | `ffmpeg_kit_flutter` | ASF metadata |
| `.aiff` | Custom parser | ID3 embedded, ANNO chunk |

### 2.4 Document Files
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.pdf` | `syncfusion_flutter_pdf` / custom | XMP metadata, DocInfo dictionary (Author, Title, Subject, Creator, Producer, CreationDate, ModDate, Keywords), embedded fonts info, embedded files |
| `.docx` / `.doc` | `archive` + XML parsing | Core properties (author, lastModifiedBy, created, modified, company, title, subject, description, keywords, revision), app properties (Application, AppVersion), custom properties |
| `.xlsx` / `.xls` | `archive` + XML parsing | Same structure as docx (core + app + custom properties) |
| `.pptx` / `.ppt` | `archive` + XML parsing | Slide author tracking, revision history metadata |
| `.odt` / `.ods` / `.odp` | `archive` + XML parsing | ODF meta.xml (creator, date, generator, editing-cycles, editing-duration, document-statistics) |
| `.rtf` | Custom parser | RTF info group (author, company, creatim, revtim, version) |
| `.txt` | File system only | File system metadata (created, modified, accessed, size, permissions) |

### 2.5 Archive & Other Files
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.zip` | `archive` package | Central directory comment, file entries (date, method, CRC) |
| `.tar` / `.gz` / `.bz2` | `archive` package | Header metadata (owner, group, permissions, mtime) |
| `.apk` | `archive` + XML | AndroidManifest.xml (package, version, permissions, minSdk), CERT.RSA signer info |
| `.epub` | `archive` + XML | OPF metadata (title, creator, publisher, date, rights, language, subject) |

### 2.6 File System Metadata (Universal — semua file)
Selalu ditampilkan untuk setiap file terlepas dari formatnya:
- File name, extension, MIME type
- File size (bytes, KB, MB)
- Absolute path
- Creation date/time
- Last modified date/time
- Last accessed date/time
- File permissions (read/write/execute)
- SHA-256 hash (computed on-device)
- MD5 hash (computed on-device)

---

## 3. Feature Specifications

### 3.1 Onboarding Wizard

#### Flow
```
Slide 1: Welcome Screen (App name, tagline, brief description)
         ↓
Slide 2: Feature Overview — Viewer (illustrasi + penjelasan)
         ↓
Slide 3: Feature Overview — Remover (illustrasi + penjelasan)
         ↓
Slide 4: Output Folder Setup (DirectoryPicker → set default output folder)
         ↓
Slide 5: Privacy Access (system picker; no broad storage permission for Viewer MVP)
         ↓
[Done] → Main App
```

#### Slide 5 — Privacy Access Detail
| Access | Android | iOS | Alasan |
|--------|---------|-----|--------|
| System file picker / SAF | ✅ | ✅ | User memilih file eksplisit tanpa broad storage permission |
| App-scoped output folder | ✅ | ✅ | Menyimpan output future tanpa akses penuh storage |

Broad media/storage permissions (`READ_MEDIA_*`, `MANAGE_EXTERNAL_STORAGE`) tidak dipakai di Viewer MVP. Jika fitur future membutuhkan akses lebih luas, permission harus diminta just-in-time dengan justifikasi eksplisit.

#### Onboarding State Persistence
Onboarding hanya muncul sekali. State disimpan di `SharedPreferences` (`key: onboarding_completed = true`). Onboarding bisa di-reset melalui Settings → Reset App Data.

---

### 3.2 Viewer Menu

#### 3.2.1 File Selection
- Tombol **"Add Files"** membuka file picker multi-select (`file_picker` package)
- Filter berdasarkan semua extension yang didukung (lihat bagian 2)
- File juga dapat diterima via **Share Intent** dari aplikasi lain (gallery, file manager, browser, dll.)
- Maksimum file yang dapat dimuat sekaligus: **50 file** (configurable di Settings)
- File list menampilkan: thumbnail (jika gambar/video), nama file, ukuran, tanggal modifikasi, badge extension

#### 3.2.2 File List View
```
┌──────────────────────────────────────────────────┐
│ [☰] VIEWER                          [+ Add Files] │
├──────────────────────────────────────────────────┤
│ [Filter ▼] [Sort ▼]          3 file(s) selected  │
├──────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────┐ │
│ │ [thumbnail] photo_vacation.jpg               │ │
│ │             2.4 MB · 2024-03-15 · ☑ Marked  │ │
│ │             [View Detail] [Mark] [Remove]    │ │
│ └──────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────┐ │
│ │ [thumbnail] document_draft.pdf               │ │
│ │             890 KB · 2024-01-09 · ○ Unmarked│ │
│ │             [View Detail] [Mark] [Remove]    │ │
│ └──────────────────────────────────────────────┘ │
│                                                  │
│ [Select All]  [Mark Selected]  [Remove Selected] │
│ [Send Marked to Remover]                         │
└──────────────────────────────────────────────────┘
```

#### 3.2.3 Metadata Detail View
Dibuka dengan tap pada item atau tombol "View Detail". Menampilkan metadata dalam format accordion/expandable sections:

**Sections:**
1. **File System Info** — nama, path, ukuran, tanggal (selalu terbuka)
2. **Basic Info** — MIME type, format, dimensi (jika media), durasi (jika audio/video)
3. **Camera / Device Info** — make, model, software, lens (jika ada)
4. **GPS & Location** — koordinat dengan peta mini (MapBox static tile), altitude, DOP
5. **Date & Time** — creation, modification, digitized, GPS timestamp
6. **Technical** — resolution, color space, bit depth, compression, codec, bitrate
7. **Embedded Metadata** — IPTC, XMP, ID3, Vorbis Comments (sesuai format)
8. **Document Properties** — author, company, revision (untuk dokumen)
9. **Hashes** — MD5, SHA-256 (computed on demand, ada tombol "Compute")
10. **Raw Metadata** — tabel key-value mentah semua field yang ditemukan

**Per-field actions:**
- Tap field → copy value ke clipboard
- Long press field → opsi "Copy Key", "Copy Value", "Copy Both"
- Icon `⚠️` pada field yang berpotensi privacy-sensitive (GPS, author, device info)

#### 3.2.4 Mark for Removal
- Checkbox per file atau per metadata field
- Marking per-field memungkinkan selective metadata removal (hanya hapus GPS, pertahankan EXIF lainnya)
- Status: `Unmarked` | `Marked (Full)` | `Marked (Selective: N fields)`
- Badge merah pada file yang sudah ditandai

#### 3.2.5 Remove from List
Hanya menghapus file dari daftar viewer, tidak menghapus file asli dari storage.

---

### 3.3 Remover Menu

#### 3.3.1 Input Sources
File masuk ke Remover dari dua sumber:
1. **Dari Viewer** — via tombol "Send Marked to Remover" (file sudah bertanda)
2. **Langsung** — tombol "Add Files" di dalam Remover, bisa dari:
   - File Manager
   - Galeri / Photos
   - Share Intent dari aplikasi lain
   - Camera (capture & immediate processing)

#### 3.3.2 Removal Mode Selection
Untuk setiap file (atau batch), pengguna memilih mode:

| Mode | Deskripsi |
|------|-----------|
| **Full Strip** | Hapus semua metadata yang terdeteksi |
| **Selective Strip** | Hapus hanya kategori tertentu (pilih via checklist: GPS, Author, Timestamps, Camera Model, Custom Fields) |
| **Anonymize** | Hapus metadata sensitif saja (GPS, author info, device info) — preset cepat |
| **Preserve Technical** | Hapus user metadata tapi pertahankan metadata teknis (dimensi, codec, color space) |

#### 3.3.3 Processing Pipeline
```
Input File(s)
    │
    ▼
[Validation & Format Detection]
    │
    ▼
[Metadata Extraction] ─── tampil preview "will be removed" / "will be kept"
    │
    ▼
[User Confirmation] ──── "Process X file(s)?"
    │
    ▼
[Metadata Removal Engine]
    │  ├─ Image: re-encode dengan stripped metadata (lossless untuk PNG, konfigurable quality untuk JPEG)
    │  ├─ Audio: rebuild ID3/Vorbis tags
    │  ├─ Video: ffmpeg remux tanpa metadata streams
    │  └─ Doc: repack ZIP/XML tanpa properties
    │
    ▼
[Output ke Folder Terkonfigurasi]
    │  Naming convention: [original_name]_clean.[ext]
    │  Jika file sudah ada: [original_name]_clean_1.[ext] (auto-increment)
    │
    ▼
[Result Summary Screen]
    │  - File berhasil diproses: N
    │  - File gagal: M (dengan alasan)
    │  - Ukuran data metadata yang dihapus
    │  - Tombol "Open Output Folder"
    │  - Tombol "Share Files"
    │  - Tombol "Process Another Batch"
```

#### 3.3.4 Output File Naming
```
Original: vacation_photo.jpg
Output:   vacation_photo_clean.jpg

Jika sudah ada:
Output:   vacation_photo_clean_1.jpg
          vacation_photo_clean_2.jpg
          ... dst
```

Pengguna dapat mengubah naming template di Settings:
- `{name}_clean` (default)
- `{name}_stripped`
- `{name}_metaremoved`
- Custom template dengan variabel: `{name}`, `{date}`, `{time}`, `{ext}`

#### 3.3.5 Progress & Feedback
- Progress bar per-file dan overall
- Estimasi waktu sisa
- Log real-time di expandable bottom sheet
- Background processing untuk batch besar (tetap berjalan jika app ke background)
- Notifikasi push saat batch selesai

#### 3.3.6 Failure Handling
| Skenario | Behavior |
|----------|----------|
| File corrupt/unreadable | Skip dengan error message, lanjutkan batch |
| Format tidak didukung untuk removal | Informasikan user, tawarkan "Copy only" |
| Insufficient storage | Stop batch, tampilkan warning dengan storage info |
| Permission denied | Redirect ke Settings permission |
| File sedang digunakan | Retry 3x dengan delay, jika tetap gagal skip |

---

### 3.4 Settings Menu

#### 3.4.1 Appearance
- **Color Theme** — pilih dari 8 preset palette industrial, atau custom via color picker (ColorPicker widget)
  - Dark Industrial (default): `#0D0D0D` bg, `#E8E0D0` text, `#C94B1A` accent
  - Steel Blue: `#0A1628` bg, `#E0E8F0` text, `#2E7DD1` accent  
  - Acid Green: `#0F1A0F` bg, `#D0E8D0` text, `#39D353` accent
  - Rust: `#1A0D00` bg, `#F0E0C8` text, `#D4521A` accent
  - Mercury: `#F5F5F5` bg, `#1A1A1A` text, `#555555` accent (light mode)
  - Neon Orange: `#0D0800` bg, `#F0E8D0` text, `#FF6B00` accent
  - Cobalt: `#000D1A` bg, `#D0E0F0` text, `#0055D4` accent
  - Custom: user pilih warna sendiri

#### 3.4.2 Storage Options
- **Output Folder** — ubah folder output default (DirectoryPicker)
- **Folder Structure** — flat (default) | organized by date (`/YYYY-MM-DD/`) | organized by type (`/images/`, `/videos/`, etc.)
- **Naming Template** — template untuk nama file output
- **Keep Original** — toggle: apakah file asli tetap disimpan atau dihapus setelah processing
- **Auto-confirm Processing** — toggle: skip confirmation dialog untuk processing

#### 3.4.3 Processing Options
- **JPEG Quality** — slider 60–100% untuk output JPEG (default: 95%)
- **Max Concurrent Files** — 1 | 2 | 4 | 8 (default: 4)
- **Max Files per Session** — 10 | 25 | 50 | 100 | Unlimited (default: 50)
- **Compute Hashes Automatically** — toggle (mempengaruhi performance)
- **Show Raw Metadata** — toggle untuk section Raw Metadata di viewer

#### 3.4.4 App Management
- **Clear App Cache** — hapus thumbnail cache, temp files processing (tampil ukuran cache saat ini)
- **Reset App Data** — reset semua settings ke default + hapus onboarding state (dengan konfirmasi 2-step)
- **Export Settings** — export konfigurasi ke file JSON
- **Import Settings** — import konfigurasi dari file JSON

#### 3.4.5 About
- App name, version, build number
- Flutter version, Dart version
- Open source licenses (Flutter standard)
- Privacy Policy link
- GitHub repository link
- Contact / bug report link

---

## 4. Data Flow & Privacy

### 4.1 Offline-First
**Semua pemrosesan dilakukan sepenuhnya on-device.** Tidak ada data, metadata, atau file yang dikirim ke server manapun.

### 4.2 Data yang Disimpan Lokal (SharedPreferences / SQLite)
| Data | Storage | Purpose |
|------|---------|---------|
| `onboarding_completed` | SharedPreferences | Cek apakah onboarding sudah selesai |
| `output_folder_path` | SharedPreferences | Path folder output |
| `color_theme` | SharedPreferences | Tema warna yang dipilih |
| `app_settings` | SharedPreferences (JSON) | Semua setting lainnya |
| `processing_history` | SQLite | Riwayat file yang pernah diproses (nama, tanggal, mode) |
| `thumbnail_cache` | File system (`app_cache_dir`) | Cache thumbnail untuk viewer |

### 4.3 Tidak Disimpan
- Konten file asli
- Metadata yang diekstrak (hanya ditampilkan di memori, tidak di-persist)
- Data pribadi apapun dari file yang diproses

---

## 5. Performance Requirements

| Metric | Target |
|--------|--------|
| App startup time (cold) | < 2 detik |
| App startup time (warm) | < 500ms |
| Metadata extraction — Image | < 500ms per file |
| Metadata extraction — Video/Audio | < 1 detik per file |
| Metadata extraction — Document | < 2 detik per file |
| JPEG strip & save (10MB file) | < 3 detik |
| Video remux (100MB file) | < 15 detik |
| Batch processing — 10 images | < 10 detik |
| Memory usage (idle) | < 80MB RAM |
| Memory usage (processing batch 50) | < 300MB RAM |
| Storage footprint (app install) | < 50MB |

---

## 6. Error States & Edge Cases

### 6.1 Empty States
- Viewer tanpa file: ilustrasi + tombol "Add Files" + teks panduan
- Remover tanpa file: ilustrasi + dua tombol ("From Viewer" dan "Add Files")
- History kosong: ilustrasi + teks "No processing history yet"

### 6.2 Special Cases
- File yang sama ditambahkan dua kali → deduplikasi otomatis berdasarkan path + hash
- File terlalu besar (> 2GB) → warning, tawarkan tetap proses atau skip
- File yang sedang dimodifikasi aplikasi lain → warning + retry option
- Storage penuh saat processing → pause batch, tampilkan dialog, resume setelah ada ruang
- Rotasi layar saat processing → state dipertahankan (no restart)

---

## 7. Accessibility

- Semua elemen interaktif memiliki semantic label untuk screen reader (TalkBack/VoiceOver)
- Minimum touch target: 48×48dp
- Kontras warna: minimum WCAG AA (4.5:1 untuk teks normal, 3:1 untuk teks besar)
- Font size: menghormati system font size setting (scalable text)
- Tidak bergantung pada warna saja untuk menyampaikan informasi (icon + label)

---

## 8. Minimum Requirements

| Platform | Requirement |
|----------|------------|
| Android | API 24 (Android 7.0 Nougat) |
| iOS | iOS 13.0 |
| Flutter | 3.22.x atau lebih baru |
| Dart | 3.4.x atau lebih baru |
| Storage | Minimal 100MB free untuk processing |

---

## 9. Localization

- **Phase 1 (v1.0):** Bahasa Indonesia + English (toggle di Settings)
- **Phase 2 (v1.x):** Arabic, Spanish, French, German
- Menggunakan Flutter `intl` package dengan ARB files
- Format tanggal, angka, dan ukuran file mengikuti locale

---

## 10. Known Limitations (v1.0)

1. RAW file removal — hanya bisa strip metadata layer, tidak bisa full re-encode ke RAW baru
2. Encrypted PDF — tidak bisa diproses tanpa password
3. File di cloud storage (Google Drive, Dropbox) — hanya bisa diproses setelah download lokal
4. Beberapa format proprietary (e.g., Sony ARW advanced) mungkin tidak ter-support penuh
5. Video re-encoding (transcode) tidak dilakukan — hanya remux (metadata strip), sehingga codec/quality tetap sama
