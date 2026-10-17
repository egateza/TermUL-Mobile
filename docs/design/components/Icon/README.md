Ikon garis SVG inline, viewBox 24, tebal 1,75, warna mengikuti `currentColor`.

**Anda menyediakan:** `name` (salah satu dari `Icon.names`), `size` (bawaan 20) dan, untuk ikon yang berdiri sendiri, `label`.

- Pakai `Icon` untuk semua ikon; jangan menggambar ulang atau menambah emoji.
- Ikon tanpa `label` disembunyikan dari pembaca layar; ikon yang menjadi satu-satunya isi tombol memberi label pada tombolnya (`IconButton` melakukannya).
- Prop `fill` mengisi bentuk (api, bintang) dengan `currentColor`.
- Warna diatur lewat `color` pada pembungkus, bukan pada ikon.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `file` (selembar berkas dengan sudut terlipat, path `M6 3h8l5 5v13H6zM14 3v5h5`) untuk baris berkas di SFTP, sama dengan yang dipakai di prototipe 4. Belum ada di `Icon.names` kode web.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `upload` (`M12 16V5M7 10l5-5 5 5M5 19h14`) untuk tombol Unggah di SFTP dan ikon `download` (`M12 5v11M7 11l5 5 5-5M5 19h14`) untuk tombol Unduh; belum ada di `Icon.names` kode web.
