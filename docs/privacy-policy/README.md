# Situs MetaStrip

Situs statis MetaStrip (halaman utama + Privacy Policy), untuk di-host di
**Cloudflare Pages** (project `metastrip`) dengan custom domain
`metastrip.bariskode.com`. Struktur dan aturannya mengikuti situs Hasteo
(`wa-autoresponder/docs/privacy-policy/`).

| URL | Isi |
|---|---|
| `https://metastrip.bariskode.com/` | Halaman utama (Indonesia) |
| `https://metastrip.bariskode.com/en/` | Landing page (English) |
| `https://metastrip.bariskode.com/privacy` | Kebijakan Privasi (Bahasa Indonesia) — URL untuk Play Console |
| `https://metastrip.bariskode.com/en/privacy` | Privacy Policy (English) |

## File

| File | Deskripsi |
|---|---|
| `site/index.html`, `site/en/index.html` | Halaman utama ID + EN; isinya harus identik. Teks diambil dari `docs/PLAY_STORE_LISTING.md` dan batasan di `AGENTS.md` |
| `site/privacy.html`, `site/en/privacy.html` | Kebijakan privasi ID (versi utama) + terjemahan EN; isi harus identik |
| `site/assets/site.css`, `site/assets/site.js` | Gaya (palet tema Dark Industrial dari `lib/core/theme/app_colors.dart`) + JS kecil (menu mobile, tombol galeri). Hanya font sistem, tanpa request pihak ketiga |
| `site/img/shot-1..5.webp` | Screenshot app 540x1170, dipakai untuk galeri dan mockup hero. UI app berbahasa Inggris, jadi satu set dipakai untuk ID dan EN |
| `site/img/shot-*-360.webp` | Varian kecil untuk `srcset` (HP) |
| `site/img/og-image.jpg` | Gambar preview link 1200x630 (og:image/twitter:image), dari feature graphic `MetaStrip-features.png` |
| `site/icon.png`, `site/favicon.ico`, `site/apple-touch-icon.png` | Ikon 256, favicon, dan ikon iOS 180 dari paket ikon MetaStrip |
| `site/robots.txt`, `site/sitemap.xml` | Sitemap dengan hreflang ID/EN/x-default; **perbarui `<lastmod>`** saat isi halaman berubah |
| `site/llms.txt` | Ringkasan fakta app untuk mesin pencari berbasis AI; samakan saat fitur atau format berubah |
| `site/_headers` | Header keamanan, cache (`/assets/*` 1 tahun immutable, `/img/*` 30 hari), dan `X-Robots-Tag: noindex` untuk `*.metastrip.pages.dev` |
| `site/_redirects` | Aturan redirect Cloudflare Pages (kosong) |

Sumber kanonik kebijakan privasi tetap `PRIVACY-POLICY.md` di root repo.

## Deploy

Deploy langsung dari folder `site/` dengan Wrangler (tidak lewat Git
integration):

```powershell
npx --yes wrangler@4 login                      # sekali saja per mesin
npx wrangler@4 pages deploy docs/privacy-policy/site --project-name metastrip --branch main
```

Setup awal (sekali saja):

1. `npx wrangler@4 pages project create metastrip --production-branch main --force`
   (`--force` hanya saat membuat project; deploy berikutnya tanpa `--force`.)
2. Cloudflare dashboard → Workers & Pages → `metastrip` → Custom domains →
   tambah `metastrip.bariskode.com`. Zona `bariskode.com` ada di Cloudflare,
   jadi record DNS dan sertifikat TLS dibuat otomatis.
3. Privacy Policy URL dan Website URL di `docs/PLAY_STORE_LISTING.md` /
   `.txt` sudah menunjuk ke domain ini; samakan juga di Play Console.

## Link Google Play

Tombol di hero, CTA `#unduh` / `#download`, footer, `installUrl` di JSON-LD,
dan `llms.txt` memakai `https://play.google.com/store/apps/details?id=com.bariskode.metastrip`
(tanpa parameter `pcampaignid`). Samakan semuanya jika link berubah.

## Update Privacy Policy

1. Edit `PRIVACY-POLICY.md` (sumber kanonik).
2. Samakan `site/privacy.html` dan `site/en/privacy.html`, termasuk tanggal
   "Terakhir diperbarui" / "Last updated".
3. Perbarui `<lastmod>` di `site/sitemap.xml`, commit, lalu deploy.

## SEO: aturan saat mengubah situs

- CSS/JS dirujuk dengan `?v=<tanggal>` dan di-cache 1 tahun: **naikkan nilai
  `v`** di semua halaman HTML setiap kali `assets/site.css` atau
  `assets/site.js` berubah.
- Halaman utama punya JSON-LD (`Organization`, `WebSite`, `WebPage`,
  `SoftwareApplication`, `FAQPage`). FAQ di JSON-LD harus sama dengan FAQ
  yang terlihat di halaman.
- Setiap halaman wajib: `title` dan `meta description` unik, `canonical`,
  `hreflang` id/en/x-default, tag Open Graph.
- Klaim fitur, format, dan batasan harus cocok dengan `AGENTS.md` dan
  `FormatRegistry.standard`. Jika format removal bertambah, perbarui hitungan
  "21 format", daftar chip, FAQ, dan `llms.txt`.
