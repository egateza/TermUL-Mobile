Ikon garis SVG inline, viewBox 24, tebal 1,75, warna mengikuti `currentColor`.

**Anda menyediakan:** `name` (salah satu dari `Icon.names`), `size` (bawaan 20) dan, untuk ikon yang berdiri sendiri, `label`.

- Pakai `Icon` untuk semua ikon; jangan menggambar ulang atau menambah emoji.
- Ikon tanpa `label` disembunyikan dari pembaca layar; ikon yang menjadi satu-satunya isi tombol memberi label pada tombolnya (`IconButton` melakukannya).
- Prop `fill` mengisi bentuk (api, bintang) dengan `currentColor`.
- Warna diatur lewat `color` pada pembungkus, bukan pada ikon.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `file` (selembar berkas dengan sudut terlipat, path `M6 3h8l5 5v13H6zM14 3v5h5`) untuk baris berkas di SFTP, sama dengan yang dipakai di prototipe 4. Belum ada di `Icon.names` kode web.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `upload` (`M12 16V5M7 10l5-5 5 5M5 19h14`) untuk tombol Unggah di SFTP dan ikon `download` (`M12 5v11M7 11l5 5 5-5M5 19h14`) untuk tombol Unduh; belum ada di `Icon.names` kode web.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `link` (`M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1`) sebagai lencana kecil (9 dp) di pojok ikon berkas atau folder yang berupa tautan simbolik (symlink) di SFTP; belum ada di `Icon.names` kode web.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `sftp` (`M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM9.5 16v-5.5M7.5 12.5l2-2 2 2M14.5 10.5V16M12.5 14l2 2 2-2`): folder dengan panah naik-turun di dalamnya untuk membuka SFTP (tombol di header terminal dan aksi "Sambung SFTP" di menu host). Dipakai supaya berbeda dari `folder` polos yang tampil sebagai ikon folder di daftar berkas; belum ada di `Icon.names` kode web.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `lock-open` (gembok dengan pengait terangkat di sisi kanan: persegi `5 11 14 9` radius 2 ditambah `M8 11V8a4 4 0 0 1 7.5-2`) untuk chip "Vault terbuka" di header Host; pasangan `lock` untuk "Vault terkunci". Belum ada di `Icon.names` kode web.
