# TermUL Mobile

Klien SSH pribadi untuk Android, dibuat dengan Flutter. Pendampingnya adalah TermUL desktop (repo `egateza/TermUL`, Java).

Baca dulu sebelum menulis kode:

- `docs/design/SUMBER.md`: asal dan versi dokumentasi desain.
- `docs/design/spike.md` dan `docs/design/spike-temuan.md`: hasil uji teknis, masalah yang sudah ketemu, dan kode yang terbukti jalan (lampiran A1 dan seterusnya).
- `docs/design/android.md`: rancangan menjaga koneksi di latar belakang (belum diuji).
- `docs/design/README.md`, `tokens.json`, `flutter.md`, `motion.md`, `streak.md`: desain visual dan perilaku.
- `docs/design/prototype/*.dc.html`: rujukan visual saja. Jangan memindahkan kodenya; aplikasinya Flutter.

## Keputusan tetap (jangan diubah tanpa alasan tertulis)

- **Platform:** Android saja. iOS tidak diuji sama sekali (tidak ada perangkat). Jangan membuat klaim atau kode yang mengandaikan iOS bekerja.
- **Paket SSH dan terminal:** `dartssh2` 4.1.0 dan `xterm` 4.0.0, versi dikunci. Jangan memakai `xterm3` (AGPL-3.0; membatasi publikasi). Tambah dependensi baru hanya setelah lisensinya dicek (MIT, BSD, atau Apache; tolak GPL dan AGPL).
- **SSH langsung dari perangkat.** Tanpa gateway atau server perantara.
- **`minSdk` 24.**
- **Host key:** tampilkan dan simpan sidik jari berformat `SHA256:…`, disimpan permanen. Host key berubah harus memblokir koneksi dengan peringatan tersendiri.
- **Koneksi putus itu normal.** Android menutup soket TCP aplikasi di latar belakang. Sambung ulang adalah alur utama, bukan penanganan galat. Gunakan pengawas keepalive seperti di lampiran spike-temuan.md, jangan hanya mengandalkan keepalive bawaan.
- **Rahasia:** kunci privat dan password hanya di Android Keystore dan selalu terenkripsi. Pembacaan dijaga biometrik, atau PIN/pola/sandi perangkat bila HP tanpa biometrik; bila HP tanpa penguncian layar, tampilkan peringatan tetapi tetap izinkan penyimpanan (diputuskan 2026-10-15, menggantikan "sidik jari saja" dari spike). Jangan menulisnya ke berkas, log, atau konsol.
- **Foreground service:** pengaturan opt-in, default mati. Rancangannya ada di `android.md`; efektivitasnya belum diuji, dan nama izin serta tipe service harus diverifikasi di dokumentasi resmi sebelum dipakai.

## Antarmuka

- Seluruh teks antarmuka dalam Bahasa Indonesia. Istilah teknis baku boleh Inggris (host key, keepalive, passphrase).
- Ikuti `tokens.json`. Satu warna aksen untuk semua aksi; tema gelap saja untuk sekarang.
- Target sentuh minimal 44 px. Pengecualian yang sudah ditetapkan: tombol cepat 36 dp dan tombol status 32 dp di mode landscape ringkas.
- Status selalu dengan kata, tidak hanya warna.
- Tanpa bayangan; pisahkan permukaan dengan tepi 1 px.
- Hormati pengaturan reduce motion di sistem.
- Warna tier api hanya untuk api streak.

## Cara kerja

1. **Usulkan rencana dulu, tunggu persetujuan, baru tulis kode.** Kerjakan per irisan vertikal, bukan semua layar sekaligus.
2. Tandai dengan jelas apa yang belum teruji. Jangan menulis "sudah berfungsi" untuk kode yang belum dijalankan di HP.
3. Uji di HP Android fisik untuk hal yang menyangkut jaringan, latar belakang, keyboard, dan biometrik. Emulator tidak mewakili itu.
4. Lisensi: sebelum menambah paket, periksa lisensinya dan catat di `docs/`.
5. Tulis kode produksi: tangani galat, tutup sumber daya (`SSHClient`, sesi, `Terminal`) di `dispose`, jangan memblokir thread UI saat keluaran deras.
6. Jangan memasukkan kredensial server, kunci privat, atau token ke repo, termasuk contoh dan tes.
7. Bila ada keputusan baru atau temuan baru, tulis di `docs/` dan beri tahu bahwa artifact desain perlu diperbarui.

## Dokumentasi desain

`docs/design/` adalah salinan dari dua artifact (lihat `SUMBER.md`). Bila artifact diperbarui, salin ulang dan perbarui tanggal serta versi di `SUMBER.md`. Jangan mengubah salinan secara lokal tanpa mencatatnya.