# MetaStrip — Play Store Listing

**App name:** MetaStrip - Metadata Viewer & Remover  
**Short description:** Lihat dan bersihkan metadata file secara offline. Clean copy, original tetap aman.  
**Full description:** Lihat bagian di bawah.  
**Category:** Tools  
**Tags:** privacy, metadata, file manager, cleaner, security, offline  
**Content rating:** Everyone  
**Target audience:** Privacy-conscious users, journalists, photographers, activists, developers, general users

---

## Short Description

Lihat dan hapus metadata dari foto, audio, dokumen, dan arsip secara offline. MetaStrip membuat clean copy tanpa mengubah file asli.

---

## Full Description

**Strip the invisible. Own your files.**

MetaStrip adalah aplikasi tools untuk melihat metadata file dan membuat salinan bersih tanpa metadata sensitif. Semua pemrosesan terjadi di perangkat Anda. Tidak ada upload ke server, tidak ada iklan, tidak ada tracking.

### Mengapa MetaStrip

- **Privasi di perangkat**: semua ekstraksi dan penghapusan metadata dilakukan offline
- **Original tetap utuh**: MetaStrip hanya membuat clean copy, tidak pernah mengubah file asli
- **Transparan**: lihat dulu metadata apa yang akan dihapus sebelum memproses
- **Tidak ada iklan dan tracking**: tidak ada SDK analytics, tidak ada SDK iklan

### Fitur Utama

**Viewer**
- Buka file dari sistem picker dan lihat metadata dalam kelompok yang jelas
- Lihat metadata filesystem, EXIF, audio tags, properti dokumen, dan entri arsip
- Salin nilai metadata ke clipboard
- Tandai file atau field tertentu untuk penghapusan selective

**Remover**
- Buat clean copy untuk format yang didukung
- Penghapusan full cleanup dan selective removal untuk stable-ID metadata yang didukung
- Proses berurutan dengan progress, log per-file, dan cancel
- Hasil berupa file baru di folder output Anda; original tetap tidak diubah
- Nama output collision-safe dengan suffix `_clean`

**Selective Removal yang Sudah Terhubung**
- PNG text chunks: hapus keyword metadata yang Anda pilih
- PDF DocInfo: aksi selective untuk kunci DocInfo yang didukung
- FLAC Vorbis comments: hapus comment key yang dipilih
- WAV LIST INFO: hapus subchunk INFO yang diizinkan
- Open XML core/app properties: hapus properti standar yang didukung
- ODF meta.xml: hapus 10 ID namespace-aware standar yang didukung

**Settings**
- 7 preset tema + custom theme builder dengan 16 token warna
- Output folder dipilih sekali dan disinkronkan antar onboarding dan remover
- Portable JSON export/import untuk memindahkan konfigurasi
- Reset dua langkah yang menghapus settings dan onboarding state tanpa menghapus clean copy yang sudah dibuat
- About, version, licenses, dan cache status

### Format yang Didukung untuk Ekstraksi Viewer

Gambar: JPG, JPEG, PNG, WebP, GIF, BMP, TIFF, TIF, HEIC  
Video: MP4, MOV, AVI, MKV, WebM, 3GP, FLV, WMV  
Audio: MP3, FLAC, AAC, OGG, WAV, M4A, Opus, WMA, AIFF, AIF, AIFC  
Dokumen: PDF, DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF, TXT  
Arsip: ZIP, TAR, APK, EPUB

### Format yang Didukung untuk Clean Copy Removal

JPG/JPEG, PNG, PDF, BMP, MP3, FLAC, OGG, Opus, WAV, AIFF, DOCX, XLSX, PPTX, ODT, ODS, ODP, GIF, WebP, ZIP

### Batasan Versi Saat Ini

- PDF removal bersifat best-effort untuk DocInfo; XMP dan struktur lanjutan mungkin tetap ada
- BMP removal untuk subset kanonik 24/32-bit Windows BITMAPINFOHEADER
- ZIP cleanup bersifat container-only dan non-recursive
- Selective removal untuk format tertentu menggunakan ID stabil tertentu; properti custom dan legacy Office belum didukung
- Video dan HEIC/HEIF removal belum didukung pada versi ini
- Pemrosesan latar belakang dan notifikasi batch belum terhubung

### Komitmen Privasi

MetaStrip dirancang untuk meminimalkan data yang disimpan:
- Tidak ada server upload
- Tidak ada analytics
- Tidak ada iklan
- Metadata file hanya ditampilkan di memori sesaat
- Clean copy disimpan di folder yang Anda pilih
- File asli tidak diubah

---

## What's New

- CI workflow untuk lint, test, dan build debug APK
- Release signing checklist untuk Android dan iOS
- ZIP stress test automation untuk batas 32 MiB aggregate decompressed
- Zip preflight hardening: ZIP64, encryption, traversal path, excessive entries rejected
- PDF linear scan replacement untuk menghindari regex hang
- ODF selective cleanup untuk 10 exact namespace-aware standard IDs
- Open XML selective cleanup untuk standard core/app properties
- Output naming collision-safe dengan auto-increment
- SAF `content://` write support untuk output di Android

---

## Metadata Google Play Tambahan

- **Language:** Bahasa Indonesia, English
- **Contact email:** hello@bariskode.com
- **Privacy Policy URL:** https://github.com/bariskodeid/bariskode-metastrip/blob/main/PRIVACY.md
- **Website URL:** https://github.com/bariskodeid/bariskode-metastrip
- **App icon:** Lihat `android/app/src/main/res/mipmap-*`
- **Feature graphic:** Disarankan visual "before/after metadata removal"
- **Promo text:** Lihat metadata sensitif, lalu buat clean copy secara offline
- **Title keywords:** Metadata Viewer, Metadata Remover, Privacy Cleaner, File Metadata, Clean Copy, Offline Tool
- **Description keywords:** metadata, viewer, remover, privacy, offline, clean copy, no tracking, no ads, file metadata, photo metadata, exif, pdf metadata, zip metadata

---

## Catatan untuk Publisher

- Pastikan privacy policy URL aktual sebelum publish
- Isi contact email yang dimonitor
- Untuk release APK/AAB, ikuti `docs/RELEASE_SIGNING_CHECKLIST.md`
- Jangan minta permission broad storage jika tidak diperlukan; app sudah menggunakan system picker + SAF
- Jika menambahkan analytics/ads di kemudian hari, update listing dan privacy policy
