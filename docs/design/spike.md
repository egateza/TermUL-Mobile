# Spike teknis: uji koneksi SSH di Flutter

Spike adalah proyek kecil sekali pakai untuk membuktikan bahwa tumpukan teknologi sanggup menjalankan fitur inti sebelum UI penuh dibangun. Hasilnya adalah keputusan lanjut atau ganti, plus daftar perubahan desain. Bukan produk jadi.

## Tumpukan yang diuji

- `dartssh2` (MIT): klien SSH dan SFTP.
- `xterm` asli atau `xterm2` versi dikunci 5.x (MIT): emulator terminal. **Jangan pakai `xterm3` (AGPL-3.0)**; lisensinya membatasi publikasi di App Store iOS.
- Tanpa gateway atau server tengah: SSH langsung dari perangkat ke server.

## Lingkungan uji

- Server nyata dengan OpenSSH (misalnya Ubuntu 24.04), tersedia akses password dan akses kunci. Siapkan juga satu server kedua yang lebih lama bila ada.
- Perangkat fisik: satu HP Android (POCO 25053PC47G, Android 16). Tidak ada iPhone, jadi iOS tidak diuji. Emulator tidak cukup untuk uji latar belakang, keyboard, dan jaringan.
- Jaringan: Wi-Fi dan seluler, termasuk berpindah di antaranya.
- Alat di server: `htop`, `vim`, `tmux`, `less`, `nano`, `mc`.

## Daftar uji

"Lulus bila" adalah syarat objektif. "Jika gagal" menunjukkan bagian desain yang ikut berubah.

| ID | Uji | Lulus bila | Jika gagal, dampak ke desain |
|---|---|---|---|
| K1 | Login password | Shell muncul, perintah dasar jalan, keluar bersih | Layar 1 dan 5 tetap; periksa pesan galat |
| K2 | Login kunci ed25519 (dengan dan tanpa passphrase) | Berhasil; passphrase salah ditolak dengan pesan jelas | Form tambah host (jenis kunci) |
| K3 | Login kunci RSA dan ECDSA | Berhasil, atau jenis yang tidak didukung ditandai jelas | Daftar jenis kunci di form dan Vault |
| K4 | Verifikasi host key | Koneksi pertama menampilkan sidik jari; sidik jari berubah memblokir koneksi | Layar 5 (Verifikasi host key); bahasa peringatan |
| K5 | PTY dan resize | Ukuran kolom dan baris benar setelah keyboard muncul, hilang, dan layar diputar | Layar 2: tinggi area terminal saat keyboard terbuka |
| K6 | Aplikasi layar penuh | `htop`, `vim`, `tmux`, `less`, `nano` tampil benar, warna benar, keluar normal | Mode Seleksi bebas dan tombol cepat |
| K7 | Teks | UTF-8, emoji, karakter lebar, garis kotak (`mc`, `htop`) sejajar | Pilihan font monospace |
| K8 | Throughput | `yes \| head -n 200000` dan `cat` berkas besar tidak membuat UI macet; tombol tetap responsif | Batas scrollback; throttle render |
| K9 | Jaringan putus | Wi-Fi ke seluler dan sinyal hilang ditangani: keepalive mendeteksi dalam waktu wajar, tidak menggantung | State "Menyambung ulang" (lihat bawah) |
| K10 | Latar belakang | Catat apa yang terjadi setelah 30 detik, 5 menit, 30 menit di iOS dan Android | Alur sambung ulang; anjuran memakai `tmux`; foreground service di Android |
| K11 | Tempel | Satu baris dan banyak baris; mode tempel berkurung (bracketed paste) benar di `vim` dan `bash` | Layar 2b dan 2c (menu Tempel dan dialog risiko) |
| K12 | Tombol khusus | Ctrl, Alt, Esc, Tab, panah, Fn, dan `Ctrl+C` berfungsi dari baris tombol cepat dan dari keyboard sistem | Layout baris tombol dan panel Semua Tombol |
| K13 | Seleksi dan scrollback | Ketuk kata, geser, salin, dan gulir 10.000 baris lancar | Layar Select text; ukuran scrollback |
| K14 | SFTP | Daftar folder, unduh, unggah, edit berkas jarak jauh, berkas besar (sekitar 100 MB) dengan progres dan pembatalan | Layar 4; Progress dan Toast |
| K15 | Penyimpanan rahasia | Kunci privat dan password tersimpan di Keychain atau Keystore; buka dengan biometrik | Layar 3 (Vault) dan alur pertama kali |
| K16 | Audit lisensi | Semua dependensi langsung dan turunan tercantum; tidak ada AGPL atau GPL | Ganti paket sebelum lanjut |

## Hipotesis dan statusnya

- **Android mematikan soket aplikasi di latar belakang: terbukti.** Log sistem mencatat soket dimatikan 5 detik setelah masuk latar belakang pada satu percobaan, sedangkan sesi di server tetap hidup. Penyebabnya sesuai dokumentasi Android 14 ke atas: proses cached dibekukan dan soket TCP-nya ditutup. Waktunya tidak bisa diandalkan (percobaan sebelumnya selamat sampai 73 detik). Rinciannya di `android.md`.
- **Foreground service menahan koneksi lebih lama: belum diuji.** Dirancang sebagai pengaturan opt-in (`android.md`, prototipe 6b). Biayanya notifikasi permanen dan baterai.
- **iOS menangguhkan aplikasi tak lama setelah masuk latar belakang: belum diuji.** Tidak ada perangkat iOS. Anggap dugaan sampai ada hasil.
- **Kesimpulan yang dipakai desain:** sesi putus akan sering terlihat, jadi sambung ulang menjadi alur utama dan bukan kasus galat.
- **Catatan K10:** diuji lewat `adb reverse` (soket loopback lewat USB) dan kondisi baterai atau pengisian daya tidak dicatat. Doze dan pembatasan aplikasi latar belakang bisa berbeda di Wi-Fi tanpa kabel dengan layar mati. Hasil ini diterima apa adanya untuk keputusan sekarang; ulangi bila perilaku di lapangan berbeda.

## Keputusan desain dari spike

- **Menyambung ulang (layar 2):** state baru di tab sesi Terminal. Pakai `Banner` ("Koneksi terputus, menyambung ulang...") dengan status dalam kata, tombol "Sambung sekarang", dan riwayat layar tetap terlihat. Saat kembali dari latar belakang, periksa sambungan dulu (`isClosed`, lalu `ping` dengan batas 5 detik) sebelum menganggapnya hidup. Status tidak boleh hanya warna.
- **Sesi persisten:** tawarkan opsi per host "Mulai di dalam tmux" dan jelaskan satu kalimat di Pengaturan, karena sesi yang soketnya dimatikan tetap hidup di server. Sebutkan `ClientAliveInterval` di server sebagai saran untuk sesi yatim.
- **Verifikasi host key (layar 5):** sidik jari tampil sebagai `SHA256:…`, sama dengan `ssh-keygen -lf`. Penolakan harus punya pesan sendiri ("Host key ditolak"), karena `dartssh2` melaporkannya sebagai `SSHAuthAbortError`. Host key yang berubah memakai bahasa peringatan terpisah, dan daftar host tepercaya disimpan permanen.
- **Terminal landscape (layar 2):** layar yang tingginya (di luar keyboard) kurang dari 480 dp memakai mode ringkas: tanpa AppBar, status satu baris, tombol cepat satu baris yang bisa digeser. Landscape dengan keyboard hanya menyisakan sekitar 5 baris; itu batas layar.
- **Select text (layar Seleksi):** dua gagang yang bisa digeser dan bilah Salin/Batal di dekat seleksi. Gulir otomatis ke tepi belum dibuat.
- **Tempel (layar 2b dan 2c):** dialog risiko wajib untuk tempelan banyak baris, karena bash sebelum 5.1 tidak melindungi tempelan.
- **Form tambah host dan Vault (layar 3):** jenis kunci yang didukung adalah `OPENSSH`, RSA (PKCS#1), dan EC; PKCS#8 ditandai dengan pesan jelas. Rahasia dibuka dengan sidik jari saja (tanpa jatuh ke PIN); sediakan state biometrik dibatalkan dan tidak tersedia.
- **SFTP (layar 4):** pembatalan unggah meninggalkan berkas parsial di server, jadi tawarkan hapus atau lanjutkan.
- **Android (Pengaturan, bagian Koneksi):** saklar "Pertahankan koneksi di latar belakang", default mati, dengan teks bahwa memakai baterai lebih banyak dan menampilkan notifikasi permanen. Bukan jaminan: perpindahan jaringan tetap memutus sesi dan sambung ulang tetap berjalan. Izin yang dibutuhkan dan teksnya ada di `android.md`; prototipe 6b. Efektivitasnya belum diuji.

## Kriteria keputusan

- **Lanjut dengan tumpukan ini** bila K1, K2, K4, K5, K6, K8, K15, dan K16 lulus.
- K9 dan K10 tidak menentukan lanjut atau ganti; hasilnya menentukan desain sambung ulang.
- Bila K6 atau K8 gagal pada `xterm`, uji `xterm2` 5.x sebelum menyimpulkan bahwa Flutter tidak cocok.
- Bila K16 gagal karena paket ber-lisensi tertutup, ganti paketnya atau tunda publikasi iOS.

## Lembar hasil

Isi setelah uji. Satu baris per uji per perangkat.

Server: Ubuntu 24.04 (OpenSSH 9.6) dan Ubuntu 18.04 (OpenSSH 7.6). Uji otomatis berjalan di Android dan diulang di PC terhadap kedua server. iPhone belum diuji.

| ID | Perangkat | Tanggal | Hasil (lulus, gagal, sebagian) | Catatan |
|---|---|---|---|---|
| K1 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus | Shell, perintah, `exit 0` bersih; password salah ditolak |
| K2 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus | Dengan dan tanpa passphrase; passphrase salah atau kosong memberi pesan jelas |
| K3 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus | RSA (PKCS#1) dan ECDSA P-256 |
| K4 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus setelah perbaikan | Sidik jari sekarang tampil `SHA256:…`, sama dengan `ssh-keygen -lf`. Penolakan memblokir koneksi |
| K5 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus setelah perbaikan | Diukur di HP lewat `stty size` dan log: potret 44 baris (keyboard tertutup) dan 23 (terbuka); landscape 18 dan 5. Sebelum perbaikan landscape dengan keyboard hanya 2 baris (lihat Temuan). Ukuran terkirim ke server sama dengan ukuran tampilan. iPhone belum diuji |
| K6 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Sebagian | Otomatis: `htop`, `vim`, `less`, `nano`, `tmux`, `mc` masuk dan keluar normal, warna ada. Manual: `tmux` tampil benar (bilah status hijau terbaca); `vim` dan `htop` dijalankan dan keluar normal tanpa keluhan. Warna `htop` dan tampilan `vim` belum dikonfirmasi pengguna |
| K7 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus | UTF-8, emoji, karakter lebar 2 kolom, garis kotak |
| K8 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Sebagian | `yes \| head -n 200000` sekitar 1,3 s, `cat` 2 MB sekitar 2,9 s (mode debug). Manual: keluaran `yes` memenuhi layar tanpa macet dan tombol cepat tetap tampil; responsivitas tombol saat keluaran mengalir belum dikonfirmasi pengguna |
| K9 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus setelah perbaikan | Keepalive bawaan `dartssh2` tidak pernah mendeteksi sinyal hilang; pengawas aplikasi mendeteksi dalam sekitar 5 s. Pindah Wi-Fi ke seluler belum diuji |
| K10 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Selesai: sambungan tidak bertahan | 13 s, 17 s, 50 s, dan 73 s: sambungan masih hidup. 282 s (sekitar 5 menit): putus. Log sistem mencatat Android mematikan soket aplikasi 5 detik setelah masuk latar belakang; sesi di server tetap hidup. Percobaan sebelumnya dengan jeda lebih pendek selamat, jadi waktunya tidak pasti. 30 menit tidak diuji karena sambungan sudah terbukti bisa putus. iOS belum diuji |
| K11 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus, dengan temuan | Bracketed paste benar di `vim` dan bash 5. bash 4.4 (Ubuntu 18.04) tidak menyalakannya, sehingga tempelan banyak baris langsung dijalankan |
| K12 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Sebagian | Baris tombol cepat dibuat (Esc, Tab, Ctrl dan Alt sekali pakai, `^C`, `^D`, panah, Home, End, PgUp, PgDn, simbol, F1 sampai F12 lewat Fn). Manual: `^C` membatalkan perintah dan memunculkan prompt baru; baris Fn terbuka di potret dan di layar ringkas landscape. Urutan tombol F dan Ctrl+huruf terbukti lewat test otomatis, tetapi efeknya di program (misalnya Ctrl+b lalu c di `tmux`) belum terbukti di HP |
| K13 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus setelah perbaikan, tanpa gulir otomatis | Scrollback dibatasi tepat 10.000 baris. Seleksi bawaan `xterm` hanya memilih satu kata tanpa gagang dan tanpa Salin; gagang yang bisa digeser dan bilah Salin/Batal dibuat sendiri dan lulus 9 test otomatis. Pengguna melaporkan hasil seleksi di HP sudah sesuai harapan. Gulir otomatis saat gagang diseret ke tepi layar belum dibuat |
| K14 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus | Daftar, unggah, unduh 100 MB dengan progres, batal, edit berkas. Kecepatan tergantung cipher (lihat Temuan). Angka 100 MB (sekitar 4 s) diukur di PC; angka SFTP di HP belum diukur |
| K15 | Android 16 (POCO 25053PC47G) | 2026-10-15 | Lulus di Android | Password dan kunci privat disimpan lewat Keystore dan hanya dibaca setelah biometrik (sidik jari saja, tanpa PIN). Diperiksa langsung di disk HP: tidak ada teks biasa untuk password, kunci PEM, passphrase, host, maupun user; data bertahan setelah aplikasi dimulai ulang dan hilang setelah uninstall. Prompt sidik jari diuji manual oleh pengguna; jalur "dibatalkan" belum terverifikasi dari log. Keychain dan Face ID di iPhone belum diuji |
| K16 | Semua | 2026-10-15 | Lulus | `dartssh2` 4.1.0 dan `xterm` 4.0.0 MIT; turunan MIT, BSD, Apache. Tidak ada GPL atau AGPL |

## Temuan dari spike

Catatan lengkap setiap masalah, penyebab, perbaikan, dan potongan kode yang sudah terbukti jalan ada di `spike-temuan.md`. Project spike tidak dipakai lagi, jadi dokumen itu adalah rujukan untuk implementasi di project sesungguhnya. Di bawah ini hanya ringkasan yang memengaruhi desain.

- **Seleksi teks butuh gagang dan toolbar.** `xterm` hanya memilih satu kata saat tekan tahan, tanpa gagang dan tanpa tombol salin. Layar Select text perlu dua gagang yang bisa digeser dan bilah Salin/Batal di dekat seleksi, seperti seleksi teks di Android dan iOS. Gulir otomatis saat gagang diseret ke tepi belum dibuat.
- **Landscape dengan keyboard hanya menyisakan sekitar 5 baris.** Layar terminal perlu mode ringkas untuk layar pendek: tanpa AppBar, status satu baris, dan baris tombol cepat satu baris yang bisa digeser. Potret: 44 baris (keyboard tertutup) dan 23 (terbuka).
- **Animasi keyboard sekitar 30 fps di layar 60 Hz**, bahkan di mode profile. Menghentikan penghitungan ulang baris selama animasi dan menambah `RepaintBoundary` tidak mengubah itu. Penyebabnya belum ditemukan; ini perlu diselidiki lebih lanjut di project nyata (lihat bagian 4.3 di `spike-temuan.md`).
- **Cipher menentukan kecepatan.** Urutan bawaan `dartssh2` mendahulukan AES-GCM, yang di Dart murni hanya sekitar 1 MB/s. Di Android mode profile, ChaCha20-Poly1305 mencapai 11,9 MB/s dan AES-CTR sekitar 4 MB/s. Aplikasi kini mendahulukan ChaCha20; unggah 100 MB lewat SFTP turun dari sekitar 120 s menjadi sekitar 4 s (diukur di PC).
- **Keepalive harus dibuat sendiri.** Keepalive bawaan menunggu balasan tanpa batas waktu, jadi sesi menggantung saat sinyal hilang. Ini menguatkan hipotesis bahwa sambung ulang harus menjadi alur utama.
- **Galat host key tidak spesifik.** `dartssh2` melaporkan penolakan host key sebagai `SSHAuthAbortError`; aplikasi harus mencatat alasannya sendiri supaya layar 5 bisa memberi pesan yang tepat.
- **Server lama tidak melindungi tempelan.** bash sebelum 5.1 tidak menyalakan bracketed paste, sehingga dialog risiko di layar 2c dibutuhkan untuk tempelan banyak baris.
- **Android mematikan soket di latar belakang.** Pada percobaan ketiga (sekitar 5 menit), log sistem mencatat soket aplikasi dimatikan 5 detik setelah masuk latar belakang, sedangkan server tidak menutup sesinya. Dua percobaan sebelumnya selamat, jadi waktunya tidak bisa diandalkan. Menguatkan hipotesis bahwa sambung ulang harus menjadi alur utama, dan bahwa `tmux` di server menjaga sesi tetap hidup.
- **Sesi server tertinggal setelah sambungan dimatikan.** Sesi yang soketnya dimatikan Android tetap hidup di server tanpa ada yang memakainya. Pengaturan keepalive di sisi server (`ClientAliveInterval`) perlu dibahas.
- **`TerminalView` memotong padding sistem dua kali.** `xterm` mengurangi `MediaQuery.padding` dari tinggi barisnya. Tanpa AppBar (layar ringkas landscape) jumlah baris terhitung kurang sekitar 4; di landscape dengan keyboard hanya 2 baris padahal tampilan muat sekitar 5. Perbaikannya membuang padding atas dan bawah untuk `TerminalView`. Keterbatasan fisik tetap ada: landscape dengan keyboard hanya menyisakan sekitar 5 baris, sehingga layar terminal perlu tata letak ringkas (tanpa AppBar, status satu baris, tombol cepat satu baris yang bisa digeser).
- **Ukuran dikirim setelah tampilan diam.** Keyboard dan rotasi memicu belasan perubahan ukuran selama animasi (misalnya 19, 16, 12, 9, 7, 6, 5 baris). Aplikasi menunda 150 ms dan mengirim ukuran terakhir saja.
- **Nama kunci penyimpanan terbaca di disk.** `flutter_secure_storage` hanya mengenkripsi nilainya; nama kunci ditulis apa adanya. Id host (`user@host:port`) dipakai sebagai nama kunci sehingga terbaca; sekarang dipakai hash. `allowBackup` Android dimatikan supaya data terenkripsi tidak ikut ke backup.
- **Biometrik di Android butuh persiapan.** `local_auth` memerlukan `FlutterFragmentActivity`, izin `USE_BIOMETRIC`, dan tema AppCompat; `minSdk` efektif 24 (23 untuk `flutter_secure_storage`, 24 untuk `local_auth`).

**Keputusan:** lanjut dengan `dartssh2` 4.1.0 dan `xterm` 4.0.0 untuk **Android**. K1, K2, K4, K5, K15, dan K16 lulus. K6 dan K8 lulus di uji otomatis dan sebagian di uji manual (warna `htop`, tampilan `vim`, dan responsivitas tombol saat keluaran deras belum dikonfirmasi pengguna). Tidak ada perangkat iOS, jadi iOS tidak diuji sama sekali (termasuk K9, K10, dan K15 dengan Keychain dan Face ID): publikasi iOS ditunda sampai ada perangkat dan hasil uji, dan klaim dukungan iOS jangan dibuat sebelum itu.

## Di luar lingkup spike

Tema terang, landscape dan tablet, state error dan kosong yang menyeluruh, streak, dan widget. Semuanya menunggu hasil spike.
