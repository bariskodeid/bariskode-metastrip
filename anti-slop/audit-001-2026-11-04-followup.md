# Tindak lanjut audit 001: landing page MetaStrip

- Tanggal: 2026-11-04
- Disetujui pemilik: sinkronisasi repo, lalu semua nomor (1 sampai 15).
- Dial: ENERGY 2 / RHYTHM 2 / MOTION 1 (dari `docs/DESIGN.md`, Industrial Minimalism).
- Badge resmi Google Play dipertahankan apa adanya (artwork, tinggi 56px, alt, catatan merek dagang).

## Prasyarat: sinkron

Versi live (`metastrip.bariskode.com`) disalin ke `docs/privacy-policy/site/`: dua halaman landing, dua halaman privasi, `site.css`, `llms.txt`, `sitemap.xml`, serta `img/google-play-badge-id.svg` dan `-en.svg`. Script yang disuntik Cloudflare (email obfuscation, challenge script) tidak ikut; link `mailto:` dari sumber repo dipakai lagi. `robots.txt` versi repo dipertahankan karena versi live berisi blok content-signal yang ditambahkan Cloudflare.

## Perbaikan per nomor

| No | Status | Yang diubah |
|----|--------|-------------|
| 1 | Selesai | `og:title`/`twitter:title` ID dan EN pakai titik dua. Em dash di `<title>`/`og:title` halaman privasi juga dihapus. |
| 2 | Selesai | Eyebrow section dihapus. Token baru `--rust-ink #a83c10` untuk teks/link rust kecil di latar terang: 5.43:1 di `#f3ede3`, 4.82:1 di `#e8e0d0`. |
| 3 | Selesai | Band CTA jadi rust solid `#c94b1a` full-width, teks putih penuh: 4.66:1. |
| 4 | Selesai | Label kartu EXIF `#5e564c` di `#e8e0d0`: 5.5:1. |
| 5 | Selesai | Ring fokus amber `#e8a040` di header, hero, band privasi, footer, ringkasan legal (7.5:1+); putih di band rust (4.66:1); steel blue tetap di permukaan terang (6.1:1+). |
| 6 | Selesai | `.icon-btn:disabled` pakai `cursor: not-allowed`; pemilih bahasa `role="group"` di keempat halaman. |
| 7 | Selesai | Tiga fitur inti tetap kartu; lima fitur pendukung jadi daftar ringkas "Juga ada di aplikasi". |
| 8 | Selesai | Efek naik dan shadow saat hover di kartu fitur dihapus. |
| 9 | Selesai | Gradient CTA diganti warna solid (lihat 3). |
| 10 | Selesai | Eyebrow section dan badge "Clean copy" dihapus; info "hasilnya selalu clean copy" pindah ke subjudul kartu Remover. Eyebrow hero ("Metadata viewer & remover offline" beserta kotak penandanya) juga dihapus atas permintaan pemilik; keyword tetap ada di `<title>` dan meta description. |
| 11 | Sebagian | HP kedua (layar Color Theme) dihapus dari hero; kartu contoh diberi label "Contoh"/"Example" dan digeser agar teks layar Viewer terbaca; galeri diberi caption. **Masih kurang:** screenshot asli layar detail metadata dan hasil clean copy. Aset ini harus diambil dari aplikasi. |
| 12 | Selesai | Urutan baru: hero, cara kerja, privasi, fitur, tampilan, format, FAQ, unduh. Komposisi divariasikan: cara kerja, privasi, dan FAQ memakai kolom judul di samping isi; fitur, tampilan, dan format tetap judul di tengah. Langkah 01-03 jadi daftar bergaris, bukan kartu. |
| 13 | Selesai | "Dapatkan" jadi "Unduh gratis" / "Download free"; "Lihat fitur" jadi "Lihat cara kerjanya" / "See how it works". |
| 14 | Selesai | CTA sekunder hero jadi link teks, badge Play satu-satunya tombol. Hero mobile rata kiri, poin centang bertumpuk. |
| 15 | Selesai | Frasa rust di H1 punya baris sendiri, H2 memakai `text-wrap: balance`. |

## Temuan tambahan saat verifikasi (masalah lama, ikut diperbaiki)

- Tombol "sebelumnya" di galeri tetap aktif setelah kembali ke awal karena snap berhenti di `scrollLeft` 4px. Diperbaiki dengan `scroll-padding-inline: 4px`.
- Halaman privasi di lebar 320px: tombol "Beranda" terpotong 17px. Diperbaiki dengan gap lebih rapat di bawah 360px.
- Target sentuh di HP: `btn-sm` 38-39px, pemilih bahasa sekitar 28px, link footer sekitar 22px. Sekarang semuanya 44px di bawah 900px.

## Delivery Gate

### Block 1: Hard Gate

- R-02 PASS: `grep '—'` di keempat HTML kosong.
- R-03 PASS: tidak ada overflow di 320, 360, 375, 390, 414, 600, 768, 900, 1000, 1080, 1280, 1440px (diukur `scrollWidth` dan bounding box per elemen); target sentuh header/footer 44px, badge 56px, link hero 48px.
- R-17 / R-18 / R-36 / R-38 PASS: tidak ada statistik, testimoni, atau klaim baru. Data EXIF di hero diberi label "Contoh"/"Example".
- R-23 PASS: tidak ada aset baru yang dibuat; badge resmi dan screenshot yang sudah ada dipakai ulang.
- R-24 / R-26 PASS: 6 anchor (`#main`, `#cara-kerja`, `#privasi`, `#fitur`, `#format`, `#faq`) semua punya target; link eksternal ke Play, `/privacy`, `/en/`, `mailto:`.
- R-25 PASS: semua pasangan diukur dengan contrast checker (angka di tabel di atas).
- R-27: tidak berlaku (halaman statis tanpa data dinamis).
- R-28 PASS: FAQ tidak berubah dan spesifik produk.
- R-32 PASS: Tab berjalan sesuai urutan visual di ID dan EN (32 langkah dicatat), ring terlihat di setiap permukaan, tombol galeri yang disabled terlewati.
- R-33 PASS: semua perubahan ditulis di sumber HTML/CSS. Script sinkron hanya dipakai sekali di scratchpad dan tidak masuk repo.
- R-34: tidak berlaku (tidak ada toggle tema; tema mengikuti DESIGN.md).
- R-35 PASS: dijalankan lewat `python -m http.server` dan Playwright. Hasil klik: toggle menu mobile membuka (`aria-expanded=true`), link "Privasi" menggulir ke #privasi dan menutup menu; "Lihat cara kerjanya" menggulir ke #cara-kerja; galeri "berikutnya" menggeser 283px dan menonaktifkan diri di akhir, "sebelumnya" kembali ke 0 dan menonaktifkan diri; FAQ ke-4 terbuka; 0 error console dan 0 respons 4xx di keempat halaman.
- R-39 PASS: cursor pointer di kontrol, `not-allowed` saat disabled; semua gambar punya `alt`; transisi dan smooth scroll mati di `prefers-reduced-motion: reduce` (dicek: `scroll-behavior: auto`, transisi 0s).
- R-40 PASS: semua `<img>` punya width/height; gambar hero tetap `fetchpriority="high"` dengan preload yang `imagesizes`-nya disamakan; galeri lazy; tidak ada script pihak ketiga. Skor performa tidak diukur.

### Block 2: Purpose-Gate

- R-01 PASS: satu-satunya gradient tersisa adalah slab hero, dengan alasan tertulis di CSS.
- R-04 PASS: ikon hanya di 3 fitur inti dan 4 poin privasi, masing-masing sesuai isinya (search, copy, sliders, wifi-off, eye-off, folder, file-lock).
- R-06 PASS: monospace sesuai DESIGN.md; uppercase lebar hanya di eyebrow hero, label grup format, dan judul footer.
- R-07 PASS: grid hero punya alasan tertulis.
- R-09 PASS: badge dekoratif dihapus.
- R-10 / R-12 / R-13 PASS: blur hanya di header; shadow hanya di HP hero, kartu contoh, dan kartu Remover (alasan tertulis di CSS).
- R-14 PASS: hierarki fitur 3 kartu + daftar ringkas, alasan tertulis di CSS.
- R-19 PASS: MOTION 1, hanya transisi hover warna dan smooth scroll.

### Block 3: Liveliness

- Dial dinyatakan: ENERGY 2 / RHYTHM 2 / MOTION 1. Komposisi section bervariasi antara kolom samping dan judul tengah, sesuai RHYTHM 2.
- Fokus per layar: badge Play di hero, nomor langkah, pernyataan privasi, band rust di akhir.
- Aksen tunggal: rust (slab hero, nomor langkah, band unduh).
- Motif identitas: coretan rust pada nilai metadata contoh, nomor mono 01-03, tipografi monospace.

### Block 4: Craftsmanship & Quality Locks

- R-05 PASS: tidak ada kartu "3 langkah", grid kartu seragam, atau footer 4 kolom.
- R-11 PASS: radius 4/8/12px seperti sebelumnya.
- R-15 PASS: CTA spesifik.
- R-16 PASS: tidak ada buzzword.
- R-29 PASS: rust + amber + netral, hijau hanya untuk status sukses (sesuai DESIGN.md).

## Yang belum

- Screenshot asli layar detail metadata dan hasil clean copy (sisa nomor 11).
- Belum di-deploy dan belum di-commit.
