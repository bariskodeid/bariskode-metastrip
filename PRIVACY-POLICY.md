# Privacy Policy — MetaStrip

**Terakhir diperbarui:** 2026-08-10  
** Berlaku untuk:** MetaStrip - Metadata Viewer & Remover (selanjutnya disebut "Aplikasi")

---

## Ringkasan

MetaStrip dirancang untuk privasi. Semua pemrosesan file terjadi di perangkat Anda. Kami tidak mengumpulkan, menyimpan, atau membagikan data pribadi Anda.

---

## 1. Data yang Dikumpulkan

### 1.1 Data Pribadi
MetaStrip **tidak mengumpulkan data pribadi** seperti nama, email, nomor telepon, atau identitas lain.

### 1.2 File dan Metadata
- Aplikasi **tidak mengupload** file atau metadata Anda ke server manapun.
- File diproses sepenuhnya di memori perangkat untuk ekstraksi dan penghapusan metadata.
- Hasil pemrosesan disimpan sebagai clean copy di folder output yang **Anda pilih**.
- File asli **tidak diubah** atau dipindahkan.

### 1.3 Data Aplikasi Lokal
MetaStrip menyimpan konfigurasi berikut secara lokal di perangkat Anda melalui SharedPreferences:
- Status onboarding (sudah/selesai)
- Path folder output yang Anda pilih
- Preferensi tema warna
- Pengaturan aplikasi lain (format JSON portabel)

Data ini **tidak pernah dikirim ke server**.

---

## 2. Izin yang Digunakan

### 2.1 Android
- **System File Picker / SAF (Storage Access Framework)**: untuk memilih file dan folder output secara eksplisit. Tidak memerlukan broad storage permission seperti `READ_MEDIA_*` atau `MANAGE_EXTERNAL_STORAGE`.
- Tidak meminta akses kamera, kontak, lokasi, atau identitas perangkat untuk tujuan ekstraksi metadata.

### 2.2 iOS
- **File Picker / Files app integration**: untuk memilih file dan menentukan lokasi output.
- Tidak meminta akses foto perangkat atau library media secara luas.

---

## 3. Bagaimana Data Digunakan

- File yang Anda pilih hanya digunakan untuk:
  - Ekstraksi metadata untuk ditampilkan di Viewer
  - Penghapusan metadata untuk membuat clean copy di Remover
- Metadata yang diekstrak hanya ditampilkan di memori aplikasi, tidak disimpan permanen.
- Clean copy disimpan di lokasi yang Anda pilih; folder ini dikelola oleh sistem file perangkat Anda.

---

## 4. Berbagi Data

MetaStrip **tidak membagikan data kepada pihak ketiga** karena:
- Tidak ada server backend
- Tidak ada analytics SDK (seperti Firebase Analytics, Google Analytics, dll.)
- Tidak ada SDK iklan (seperti AdMob, Unity Ads, dll.)
- Tidak ada integrasi sosial media yang mengirim data
- Tidak ada layanan cloud pihak ketiga

---

## 5. Retensi Data

- File asli Anda **tidak pernah disentuh** oleh Aplikasi.
- Clean copy disimpan di perangkat Anda sesuai kontrol sistem file standar.
- Konfigurasi aplikasi (SharedPreferences) bertahan di perangkat sampai Anda:
  - Menghapus Aplikasi
  - Melakukan reset data melalui Settings -> Reset All Data
  - Menghapus data aplikasi melalui pengaturan sistem

---

## 6. Keamanan

- Pemrosesan file terjadi sepenuhnya di perangkat Anda.
- Tidak ada transmisi data melalui jaringan.
- File asli dilindungi oleh sistem operasi; Aplikasi hanya membaca file yang Anda pilih secara eksplisit.
- Clean copy ditulis ke lokasi baru; original tidak dimodifikasi.
- SHA-256 untuk file dihitung on-device untuk file hingga 100MB (opsional).

---

## 7. Layanan Pihak Ketiga

MetaStrip **tidak menyertakan SDK pihak ketiga** yang mengumpulkan data. Dependensi utama:
- Flutter SDK (framework UI)
- Dart standard library
- Package: archive, xml, exif, image, path, mime, crypto, file_picker, file_selector, saf, shared_preferences

Semua package di atas menjalankan kode di perangkat Anda dan tidak mengirim data keluar.

---

## 8. Hak Pengguna

Anda memiliki kontrol penuh atas:
- File mana yang diproses (melalui system picker)
- Lokasi output clean copy (folder yang Anda pilih)
- Metadata apa yang ditampilkan dan dihapus
- Penghapusan semua data aplikasi melalui reset atau uninstall

---

## 9. Perubahan pada Kebijakan Privasi

Kebijakan ini mungkin diperbarui seiring perkembangan Aplikasi. Perubahan signifikan akan didokumentasikan dengan jelas. Versi terbaru selalu tersedia di repository proyek.

---

## 10. Kontak

Untuk pertanyaan tentang privasi atau Aplikasi ini:
- Repository: https://github.com/bariskodeid/bariskode-metastrip
- Email: hello@bariskode.com

---

## Catatan Penting

- Aplikasi ini tidak dirancang untuk anak di bawah 13 tahun.
- Tidak ada pengumpulan data lokasi, identitas, atau perilaku pengguna.
- Jika Anda menginstall Aplikasi melalui Google Play, Google menerapkan kebijakan privasi mereka sendiri yang di luar kontrol MetaStrip.

---

**MetaStrip adalah software open source. Lihat LICENSE untuk detail distribusi.**
