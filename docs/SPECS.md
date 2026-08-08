# SPECS.md — Product Specification
## MetaStrip: Metadata Viewer & Remover
**Version:** 1.0.0  
**Platform:** Flutter (Android-first, iOS ready)  
**Last Updated:** 2026-08-08

> **Implementation status:** This file describes the product target. Current code accepts a narrower Viewer allowlist, has registered extractors for only some allowlisted formats, and has a 19-extension Remover registry. Full Strip, Selective, Anonymize, Preserve Technical, share intent, and background processing are planned unless explicitly marked implemented in the progress reports.

---

## 1. Overview

MetaStrip adalah aplikasi mobile berbasis Flutter yang memungkinkan pengguna untuk:
1. **Melihat metadata** dari format target; implementasi saat ini terbatas pada Viewer allowlist dan registered extractor formats
2. **Menghapus metadata** untuk format yang didukung Remover, dengan output disimpan ke folder yang telah dikonfigurasi

Target pengguna: jurnalis, fotografer, aktivis privasi, developer, dan pengguna umum yang peduli dengan privasi digital.

---

## 2. Supported File Types & Metadata Coverage

### 2.1 Image Files (target versus current)
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.jpg` / `.jpeg` | `exif` package | EXIF (GPS, kamera, lensa, tanggal, orientasi, ISO, aperture, shutter speed, focal length), IPTC (caption, keywords, copyright), XMP |
| `.png` | `image` package | tEXt/zTXt chunks (author, creation time, software, comment), iTXt chunks |
| `.webp` | `image` package | EXIF embedded, XMP |
| `.gif` | `image` package | Comment extension, Netscape extension |
| `.bmp` | Custom parser | Header metadata (color depth, resolution); removal is enabled only for strict canonical 24/32-bit Windows `BITMAPINFOHEADER`, `BI_RGB`, positive dimensions, and `bfOffBits == 54`. It preserves header/pixel payload bytes, zeroes reserved fields, normalizes size fields, and discards trailing bytes; this is not comprehensive BMP sanitization. SAF persisted readback and device validation remain pending. |
| `.tiff` / `.tif` | `exif` package | Full EXIF, IPTC, GPS, thumbnail embedded |
| `.heic` / `.heif` | Planned HEIF parser | `.heic` is currently Viewer-allowlisted but filesystem-only; `.heif` is omitted from the current allowlist/parser |
| RAW/CR2/NEF/ARW/DNG | Planned RAW parser | Planned; not in current Viewer allowlist/parser |

### 2.2 Video Files (target; current allowlisted video is filesystem-only)
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.mp4` / `.m4v` | Planned video parser | Planned; not in current extractor registry (`.m4v` is not in the Viewer allowlist) |
| `.mov` | `ffmpeg_kit_flutter` | Apple QuickTime metadata atoms, GPS track |
| `.avi` | `ffmpeg_kit_flutter` | RIFF INFO chunk metadata |
| `.mkv` | `ffmpeg_kit_flutter` | MKV Tags (title, artist, date, encoder, language, chapters) |
| `.webm` | `ffmpeg_kit_flutter` | WebM/Matroska tags |
| `.3gp` | `ffmpeg_kit_flutter` | 3GPP metadata |
| `.flv` | `ffmpeg_kit_flutter` | FLV metadata AMF |
| `.wmv` | `ffmpeg_kit_flutter` | ASF metadata object |

### 2.3 Audio Files (target; see current registry summary below)
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

### 2.4 Document Files (target; see current registry summary below)
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.pdf` | `syncfusion_flutter_pdf` / custom | XMP metadata, DocInfo dictionary (Author, Title, Subject, Creator, Producer, CreationDate, ModDate, Keywords), embedded fonts info, embedded files |
| `.docx` | `archive` + XML parsing | Core/app properties; implemented extractor and remover support |
| `.xlsx` | `archive` + XML parsing | Core/app properties; implemented extractor and remover support |
| `.pptx` | `archive` + XML parsing | Core/app properties; implemented extractor and remover support |
| Legacy `.doc` / `.xls` / `.ppt` | Planned legacy Office parser | Not in current Viewer allowlist/parser |
| `.odt` / `.ods` / `.odp` | `archive` + XML parsing | ODF meta.xml (creator, date, generator, editing-cycles, editing-duration, document-statistics) |
| `.rtf` | Custom parser | RTF info group (author, company, creatim, revtim, version) |
| `.txt` | File system only | File system metadata (created, modified, accessed, size, permissions) |

### 2.5 Archive & Other Files (target; see current registry summary below)
| Extension | Library | Metadata yang Didukung |
|-----------|---------|----------------------|
| `.zip` | `archive` package | Central directory comment, file entries (date, method, CRC) |
| `.tar` / `.gz` / `.bz2` | Planned archive parser | `.tar` is Viewer-allowlisted but has no registered extractor; `.gz`/`.bz2` are not in the current allowlist |
| `.apk` | `archive` + XML | AndroidManifest.xml (package, version, permissions, minSdk), CERT.RSA signer info |
| `.epub` | `archive` + XML | OPF metadata (title, creator, publisher, date, rights, language, subject) |

### 2.6 Current Implementation Registry

- **Viewer allowlist:** JPG/JPEG, PNG, WebP, GIF, BMP, TIFF/TIF, HEIC; MP4, MOV, AVI, MKV, WebM, 3GP, FLV, WMV; MP3, FLAC, AAC, OGG, WAV, M4A, Opus, WMA, AIFF/AIF/AIFC; PDF, DOCX, XLSX, PPTX, ODT/ODS/ODP, RTF, TXT; ZIP, TAR, APK, EPUB.
- **Registered payload extractors:** JPG/JPEG, TIFF/TIF, PNG, GIF, WebP, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, PDF, DOCX/XLSX/PPTX, ODT/ODS/ODP, ZIP/APK/EPUB. Other allowlisted extensions receive filesystem metadata only.
- **Remover registry:** JPG/JPEG, PNG, PDF, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, DOCX/XLSX/PPTX, ODT/ODS/ODP, GIF, WebP.
- **Not current support:** TIFF/TIF removal, HEIF, RAW, M4V, legacy Office, GZ/BZ2. TIFF/TIF extraction remains available, but removal is disabled pending a future structural writer/POC. HEIC is allowlisted but has no format extractor. Video and archive removal, granular audio removal, and per-property Office removal are deferred.

### 2.7 File System Metadata (Universal — semua allowlisted file)
Selalu ditampilkan untuk setiap file terlepas dari formatnya:
- File name, extension, MIME type
- File size (bytes, KB, MB)
- Absolute path
- Creation date/time
- Last modified date/time
- Last accessed date/time
- File permissions (read/write/execute)
- SHA-256 hash (computed on-device only for files <= 100 MB)
- **Planned:** MD5 hash; not computed by the current implementation

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
Onboarding hanya muncul sekali. State disimpan di `SharedPreferences` (`key: onboarding_completed = true`). Folder output yang dipilih disinkronkan ke state Settings saat startup/perubahan. Onboarding bisa di-reset melalui Settings → Reset All Data.

---

### 3.2 Viewer Menu

#### 3.2.1 File Selection
- Tombol **"Add Files"** membuka file picker multi-select (`file_picker` package)
- Filter berdasarkan semua extension yang didukung (lihat bagian 2)
- **Planned:** File dapat diterima via Share Intent dari aplikasi lain.
- Maksimum file yang dapat dimuat sekaligus pada MVP saat ini: **50 file** (fixed); konfigurasi batas melalui Settings direncanakan
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
9. **Hashes** — SHA-256 untuk file <= 100 MB; MD5 dan tombol on-demand "Compute" masih planned
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
   - Share Intent dari aplikasi lain (**planned**)
   - Camera (capture & immediate processing)

#### 3.3.2 Removal Mode Selection
Untuk setiap file (atau batch), pengguna memilih mode:

| Mode | Deskripsi |
|------|-----------|
| **Supported cleanup (current)** | Clean-copy behavior for the registered remover format; PDF is best-effort DocInfo only |
| **Full Strip** | Planned/unwired: Hapus semua metadata yang terdeteksi |
| **Selective Strip** | Planned/unwired; limited PNG/PDF selector parameters exist, but the general UI mode is unavailable |
| **Anonymize** | Planned/unwired: Hapus metadata sensitif saja |
| **Preserve Technical** | Planned/unwired: Hapus user metadata sambil mempertahankan metadata teknis |

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
    │  - Tombol "Share Files" (planned)
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

**Planned/model-only:** Pengguna akan dapat mengubah naming template di Settings. Field template saat ini hanya tersimpan pada model/import-export, kontrolnya belum diekspos atau dihubungkan ke pipeline, dan Remover selalu memakai suffix `_clean`:
- `{name}_clean` (default)
- `{name}_stripped`
- `{name}_metaremoved`
- Custom template dengan variabel: `{name}`, `{date}`, `{time}`, `{ext}`

#### 3.3.5 Progress & Feedback
- Progress bar per-file dan overall
- Estimasi waktu sisa
- Log real-time di expandable bottom sheet
- **Planned:** Background processing untuk batch besar dan notifikasi saat batch selesai

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

Status implementasi MVP: UI saat ini mengekspos Appearance, Output, Maintenance, dan About. Field storage/processing lanjutan tetap ada pada model settings dan format import/export untuk kompatibilitas, tetapi kontrolnya belum ditampilkan dan nilainya belum dihubungkan ke pipeline remover.

#### 3.4.1 Appearance
- **Color Theme** — pilih dari 7 preset palette industrial, atau custom via color picker (ColorPicker widget); pilihan diterapkan live pada root app
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
- Output folder disimpan pada key device-local yang sama dengan onboarding dan dipakai remover; perubahan dari kedua flow disinkronkan
- **Belum diekspos:** Folder Structure, Naming Template, dan Keep Original tersedia di model persistence saja. Originals tetap selalu dipertahankan oleh pipeline saat ini.

#### 3.4.3 Processing Options
- **Belum diekspos/di-wiring:** JPEG Quality (model range 70-100), Max Concurrent Files (1-8), dan Auto-confirm tersimpan pada model settings/import-export tetapi tidak memiliki kontrol UI dan tidak mengubah processing saat ini.
- Max Files per Session, Compute Hashes Automatically, dan Show Raw Metadata belum menjadi settings yang dapat dikonfigurasi.

#### 3.4.4 App Management
- **Clear App Cache** — action dan ukuran cache tersedia; saat ini no-op/0 byte karena cache thumbnail/temp belum digunakan
- **Reset All Data** — hapus app settings, tema, folder output, dan onboarding state (konfirmasi 2-step), lalu kembali ke onboarding. Clean copy dan output yang sudah dibuat tidak dihapus.
- **Export Settings** — export konfigurasi portabel ke JSON tanpa `outputFolderPath` yang device-local
- **Import Settings** — validasi dan import JSON sambil mempertahankan serta memvalidasi output folder perangkat saat ini

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

### 4.2 Data yang Disimpan Lokal
Persistent app configuration saat ini disimpan di `SharedPreferences`. SQLite history dan filesystem thumbnail cache masih planned dan belum disimpan oleh implementasi saat ini.

| Data | Storage | Purpose |
|------|---------|---------|
| `onboarding_completed` | SharedPreferences | Cek apakah onboarding sudah selesai |
| `output_folder_path` | SharedPreferences | Path folder output |
| `color_theme` | SharedPreferences | Tema warna yang dipilih |
| `app_settings` | SharedPreferences (JSON) | Semua setting lainnya |
| `processing_history` | Planned: SQLite (not currently stored) | Riwayat file yang pernah diproses (nama, tanggal, mode) |
| `thumbnail_cache` | Planned: file system (`app_cache_dir`; not currently stored) | Cache thumbnail untuk viewer |

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

1. RAW viewing/removal is planned and is not in the current allowlist, extractor registry, or remover registry
2. Encrypted PDF — tidak bisa diproses tanpa password
3. File di cloud storage (Google Drive, Dropbox) — hanya bisa diproses setelah download lokal
4. Beberapa format proprietary (e.g., Sony ARW advanced) mungkin tidak ter-support penuh
5. Video re-encoding (transcode) tidak dilakukan — hanya remux (metadata strip), sehingga codec/quality tetap sama
