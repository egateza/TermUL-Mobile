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
- **Orientasi: potret saja** (diputuskan pemilik 2026-10-17, supaya tampilan konsisten). Kode landscape dibiarkan tetapi tidak aktif; lihat `docs/implementation-plan.md` 11x.
- **Host key:** tampilkan dan simpan sidik jari berformat `SHA256:…`, disimpan permanen. Host key berubah harus memblokir koneksi dengan peringatan tersendiri.
- **Koneksi putus itu normal.** Android menutup soket TCP aplikasi di latar belakang. Sambung ulang adalah alur utama, bukan penanganan galat. Gunakan pengawas keepalive seperti di lampiran spike-temuan.md, jangan hanya mengandalkan keepalive bawaan.
- **Rahasia:** kunci privat dan password hanya di Android Keystore dan selalu terenkripsi. Pembacaan dijaga biometrik, atau PIN/pola/sandi perangkat bila HP tanpa biometrik; bila HP tanpa penguncian layar, tampilkan peringatan tetapi tetap izinkan penyimpanan (diputuskan 2026-10-15, menggantikan "sidik jari saja" dari spike). Jangan menulisnya ke berkas, log, atau konsol. Pengecualian (diputuskan pemilik 2026-10-16): selama layar menyala dan sesi hidup, rahasia boleh dipegang di memori supaya sambung ulang tidak meminta biometrik berulang; layar mati, sesi ditutup, atau galat yang tidak sembuh melepasnya (lihat `docs/implementation-plan.md` 11f). Pengecualian kedua (diputuskan pemilik 2026-10-17): **vault terbuka**. Chip "Vault" di daftar host membuka gerbang biometrik sampai layar mati atau aplikasi ditutup, dan saklar Pengaturan "Jangan kunci vault" (bawaan mati, dengan peringatan dan satu autentikasi saat menyalakan) membukanya permanen; penyimpanan tetap terenkripsi Keystore (lihat `docs/implementation-plan.md` 11aa).
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
3. Uji di HP Android fisik untuk hal yang menyangkut jaringan, latar belakang, keyboard, dan biometrik. Emulator tidak mewakili itu. Pemilik kadang meminta Claude menguji langsung lewat adb di HP (pasang, jalankan, baca log) demi kesesuaian pengujian; lakukan hanya saat diminta, dan prompt biometrik tetap disentuh pemilik.
   - **Jangan pernah menimpa aplikasi TermUL rilis di perangkat.** Sebelum memasang APK lewat adb, pastikan paket uji memakai `applicationId` berbeda dari `io.github.egateza.termul` (misalnya `io.github.egateza.termul.preview`) dan label yang jelas seperti “TermUL Preview”. Jangan memasang APK debug/profile dengan application ID rilis, sekalipun sertifikatnya sama; jangan menghapus atau mengganti aplikasi rilis. Jika belum ada varian uji dengan ID terpisah, siapkan varian itu terlebih dahulu atau batasi pengujian ke emulator. Setelah pemasangan, verifikasi paket rilis tetap terpasang dan paket uji muncul sebagai aplikasi terpisah.
   - **Uji SSH dari HP ke WSL Windows ini:** gunakan profil tersimpan **WSL Uji**. Username SSH-nya `termul_t`, akun uji yang sudah tersedia di Ubuntu-22.04 WSL (akun login default WSL adalah `ega`; jangan mengganti profil uji menjadi akun itu). Instans SSH uji tersedia di port 2222 dan 2224. Jangan menyalin atau mencatat password/kunci profil ke repo, log, atau konsol.
4. Lisensi: sebelum menambah paket, periksa lisensinya dan catat di `docs/`.
5. Tulis kode produksi: tangani galat, tutup sumber daya (`SSHClient`, sesi, `Terminal`) di `dispose`, jangan memblokir thread UI saat keluaran deras.
6. Jangan memasukkan kredensial server, kunci privat, atau token ke repo, termasuk contoh dan tes.
7. Bila ada keputusan baru atau temuan baru, tulis di `docs/` dan beri tahu bahwa artifact desain perlu diperbarui.
8. **Desain sistem dan prototipe adalah acuan yang harus diikuti.** Warna, ukuran, tata letak, teks, dan perilaku di aplikasi mengikuti artifact desain (`docs/design/`). Jangan mengubah desain supaya cocok dengan kode.
   - **Tambahan** (layar, komponen, varian, atau perilaku baru yang tidak bertentangan dengan desain) dimasukkan ke kedua artifact di irisan yang sama: design system (`README.md`, berkas komponen, `tokens.json`) dan prototipe (`prototype/*.dc.html` dan `canvas.json`; layar atau varian baru dibuat sebagai contoh baru di kanvas).
   - **Kondisi yang tidak bisa atau belum bisa diterapkan** (batasan paket, platform, atau belum dibuat) tidak mengubah desain: desain tetap seperti semula, dan yang ditambahkan hanya catatan di README bagian "Catatan dari implementasi Flutter" (apa yang berbeda, alasannya, dan apa yang perlu agar bisa sesuai). Catat juga di `docs/implementation-plan.md`.
   - Bila ragu apakah sesuatu tambahan atau penyimpangan, tanyakan sebelum menulis kode atau mengubah artifact.
9. **Alur artifact desain: staging dulu, publish setelah siap** (publish sudah disetujui pemilik untuk perubahan semacam ini; diperketat 2026-10-27).
   1. **Staging.** Setiap perubahan atau tambahan desain ditulis dulu di `docs/design/.staging/<nama-irisan>/`, bukan langsung di `docs/design/`. Isinya salinan utuh berkas yang diubah atau ditambah (nama sama seperti di artifact, mis. `prototype/Settings.dc.html`, `README.md`, `canvas.json`) dan `README-change.md` (apa yang berubah, alasannya, artifact mana, status). Staging boleh diperbarui berkali-kali selama irisan berjalan.
   2. **Siap publish** bila desainnya sudah final untuk irisan itu, prototipe yang diubah sudah dirender di Chrome tanpa galat, dan `README-change.md` lengkap.
   3. **Sebelum publish:** baca berkas yang sama dari artifact lewat `read` dengan `path` dan bandingkan dengan `docs/design/`. Bila artifact lebih baru, gabungkan dulu ke staging; jangan menimpa perubahan orang lain.
   4. **Publish** isi staging ke artifact. Jangan mengklaim artifact sudah sinkron sebelum publish berhasil.
   5. **Setelah publish berhasil:** salin berkas dari staging ke `docs/design/`, catat versi baru dan isi perubahan di `docs/design/SUMBER.md` dan `docs/implementation-plan.md`, lalu hapus folder staging irisan itu.
   6. **Bila artifact tidak terjangkau** (mis. login ke organisasi lain): perubahan tetap di staging, jangan dipindah ke `docs/design/`. Sebutkan bahwa artifact belum diperbarui.
10. **Commit setiap update yang sudah sesuai** (izin tetap dari pemilik; tidak perlu menunggu diminta lagi). Sebuah update "sesuai" bila: `flutter analyze` bersih, `flutter test` lulus, dokumentasi tercatat di `docs/implementation-plan.md` (termasuk apa yang belum teruji di HP), dan bagian desainnya selaras (tambahan sudah masuk ke artifact, atau kondisi yang belum bisa diterapkan sudah dicatat di README sesuai butir 8). Satu commit per irisan yang utuh, pesan dalam Bahasa Indonesia mengikuti gaya riwayat yang ada, ditutup dengan baris atribusi dari harness. Jangan memasukkan kredensial, kunci, atau berkas uji (mis. folder `ssh_test`) ke commit. Yang boleh otomatis hanya commit lokal: **`git push`, ubah riwayat (`--amend`, `rebase`, `reset`), dan hapus cabang tetap menunggu perintah pemilik.** Bila sebuah update belum sesuai (mis. artifact desain belum diperbarui), jangan commit; sebutkan apa yang masih kurang.

## Dokumentasi desain

`docs/design/` adalah salinan dari dua artifact (lihat `SUMBER.md`). Bila artifact diperbarui, salin ulang dan perbarui tanggal serta versi di `SUMBER.md`. Jangan mengubah salinan ini langsung: perubahan desain lewat `docs/design/.staging/` dan baru masuk ke sini setelah publish berhasil (butir 9).
