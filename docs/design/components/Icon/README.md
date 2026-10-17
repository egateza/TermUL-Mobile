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
- Tambahan di aplikasi Flutter (2026-10-17): ikon `grip` (`M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01`: dua kolom titik) sebagai pegangan geser baris (urutan kategori dan snippet) dan ikon `sort` (`M7 4v16M4 17l3 3 3-3M17 20V4M14 7l3-3 3 3`: dua panah berlawanan) untuk tombol Urutkan snippet; belum ada di `Icon.names` kode web. Ikon `edit` dan `trash` yang sudah ada dipakai untuk Kelola kategori dan Hapus.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `flame` (api satu lidah bergaya garis, path `M12 3c.5 3.2 5.5 5.3 5.5 10.2a5.5 5.5 0 0 1-11 0c0-2.2 1-3.6 2.3-4.7.1 1.8.9 2.8 2 3.2C10 8.8 10.5 5.7 12 3z`) untuk tab Streak di `NavBar`. Ini ikon biasa, bukan komponen `Flame` (api berwarna tier yang berganti bentuk menurut state); belum ada di `Icon.names` kode web.
- Tambahan di aplikasi Flutter (2026-10-17): ikon `help` (lingkaran r9 ditambah `M9.6 9.4a2.5 2.5 0 1 1 3.5 2.3c-.7.3-1.1.8-1.1 1.6M12 17h.01`: tanda tanya) untuk tombol bantuan di header Streak dan baris "Cara kerja streak", sama dengan yang dipakai di prototipe 8; belum ada di `Icon.names` kode web.
