# Temuan spike: masalah, perbaikan, dan kode yang bisa dipakai ulang

Dicatat dari spike 2026-10-15: `dartssh2` 4.1.0 dan `xterm` 4.0.0 di Android (POCO 25053PC47G, Android 16, HyperOS), melawan server Ubuntu 24.04 dan 18.04. Project spike-nya tidak dipakai lagi, jadi dokumen ini adalah satu-satunya rujukan: setiap masalah ditulis dengan gejala, penyebab, perbaikan, dan potongan kode yang sudah terbukti jalan.

Ditulis untuk: developer yang akan mengimplementasikan TermUL Mobile di project sesungguhnya. Daftar uji dan hasilnya ada di `spike.md`.

## Isi

1. Keputusan yang diambil
2. dartssh2
3. xterm
4. Tata letak, keyboard, dan animasi
5. Perilaku Android di latar belakang
6. Penyimpanan rahasia dan biometrik
7. Lingkungan uji dan perkakas
8. Kesalahan analisis selama spike
9. Yang tidak boleh dibawa mentah dari spike
10. Belum diuji atau belum terjawab
11. Lampiran: kode yang bisa dipakai ulang

---

## 1. Keputusan yang diambil

| Hal | Keputusan | Alasan singkat |
|---|---|---|
| Klien SSH dan SFTP | `dartssh2` 4.1.0 (MIT) | K1 sampai K4 dan K14 lulus |
| Emulator terminal | `xterm` 4.0.0 asli (MIT), **bukan** `xterm3` (AGPL) | K6, K7, K8 lulus; AGPL membatasi App Store |
| Urutan cipher | ChaCha20-Poly1305 dulu, AES-GCM paling akhir | AES-GCM di Dart murni hanya sekitar 1 MB/s |
| Keepalive | Pengawas buatan sendiri | Keepalive bawaan tidak mendeteksi sinyal hilang |
| Penyimpanan rahasia | `flutter_secure_storage` + `local_auth` | Terenkripsi di Keystore, terbuka lewat sidik jari |
| Seleksi teks | Dibuat sendiri | `xterm` tidak punya gagang dan tombol salin |
| Tata letak terminal | Layar pendek memakai mode ringkas | Landscape dengan keyboard hanya menyisakan sekitar 5 baris |

Lisensi (K16): semua dependensi langsung dan turunan MIT, BSD, atau Apache; tidak ada GPL atau AGPL. Paket tambahan yang dipakai: `flutter_secure_storage` 11.2.0, `local_auth` 3.0.2, `crypto` 3.0.7 (semuanya BSD). Periksa ulang bila menambah paket.

---

## 2. dartssh2

### 2.1 Sidik jari host key tampil sebagai hex dari teks (K4)

- **Gejala:** dialog "Host baru" menampilkan `53:48:41:32:35:36:3a:...`, tidak bisa dicocokkan dengan `ssh-keygen -lf`.
- **Penyebab:** callback `onVerifyHostKey(type, fingerprint)` sudah memberi `SHA256:<base64>` dalam bentuk byte UTF-8. Kode spike mengubah byte itu lagi menjadi hex.
- **Perbaikan:** `utf8.decode(fingerprint)`. Tervalidasi sama persis dengan `ssh-keygen -lf` di server. Kode: lampiran A1.

### 2.2 Penolakan host key dilaporkan sebagai `SSHAuthAbortError`

- **Gejala:** saat pengguna menekan Tolak, galat yang keluar bukan `SSHHostkeyError`, melainkan `SSHAuthAbortError: Connection closed before authentication`.
- **Penyebab:** `dartssh2` hanya melempar `SSHHostkeyError` untuk kegagalan verifikasi tanda tangan, bukan untuk penolakan oleh callback.
- **Perbaikan:** catat sendiri alasannya di callback (`_hostKeyRejected = true`), lalu tampilkan "Host key ditolak" bila galat apa pun muncul sesudahnya. Layar Verifikasi host key tidak boleh bergantung pada tipe galat. Kode: lampiran A1.

### 2.3 Keepalive bawaan tidak mendeteksi sambungan mati (K9)

- **Gejala:** saat soket mati diam-diam (tanpa FIN, seperti sinyal hilang), `client.done` tidak pernah selesai. Diuji 20 detik dengan `keepAliveInterval` 2 detik: tetap menggantung.
- **Penyebab:** `SSHKeepAlive` mengirim ping tanpa batas waktu balasan. Galat ping ditelan dan tidak ada yang menutup klien.
- **Perbaikan:** pengawas sendiri yang memanggil `client.ping().timeout(...)` dan menutup klien bila habis waktu. Dengan interval 2 detik dan batas 3 detik, terdeteksi dalam sekitar 5 detik. Aplikasi memakai 15 dan 10 detik, dengan `keepAliveInterval: null` agar tidak ganda. Kode: lampiran A2.
- **Cara menguji:** proxy TCP lokal yang berhenti meneruskan data tanpa menutup soket (meniru sinyal hilang).

### 2.4 Cipher bawaan sangat lambat (K8, K14)

- **Gejala:** unggah SFTP 100 MB butuh sekitar 120 detik (0,8 MB/s).
- **Penyebab:** urutan bawaan mendahulukan AES-GCM, yang di Dart murni hanya sekitar 1 MB/s.
- **Perbaikan:** `SSHAlgorithms(cipher: [chacha20poly1305, aes256ctr, aes128ctr, aes256gcm, aes128gcm])`. Hasil: PC 31 MB/s, unggah 100 MB sekitar 4 detik (22 MB/s). Kode: lampiran A3.
- **Angka di HP (mode profile):** ChaCha20 11,9 MB/s, AES-CTR sekitar 4 MB/s, AES-GCM 0,9 MB/s.
- **Jebakan pengukuran:** di mode **debug** ChaCha20 di HP hanya 1,7 MB/s (JIT). Jangan menyimpulkan kecepatan dari build debug; ukur di profile atau rilis.

### 2.5 Passphrase dan format kunci (K2, K3)

- Passphrase salah atau kosong melempar `SSHKeyDecryptError` (pesan `Invalid passphrase` atau `Private key is encrypted`). `SSHKeyPair.isEncryptedPem` menanyakan perlunya passphrase.
- Format yang didukung `fromPem`: `OPENSSH PRIVATE KEY`, `RSA PRIVATE KEY` (PKCS#1), dan `EC PRIVATE KEY`. Selain itu melempar `UnsupportedError`, termasuk PKCS#8 (`PRIVATE KEY`). Form tambah host harus menandai jenis yang tidak didukung dengan pesan jelas.
- Teruji: ed25519 (dengan dan tanpa passphrase), RSA 3072 (`ssh-keygen -m PEM`), ECDSA P-256.

### 2.6 SFTP (K14)

- Teruji: daftar folder, unggah dan unduh 100 MB dengan progres, batal (`writer.abort()`), edit berkas jarak jauh.
- **Batal meninggalkan berkas parsial di server** (1 sampai 12 MB terlihat setelah `abort`). Implementasi nyata perlu menghapus berkas parsial atau menawarkan lanjutkan.
- Kecepatan unduh sedikit di bawah unggah (sekitar 17 sampai 20 MB/s di PC).

---

## 3. xterm

### 3.1 `TerminalView` mengurangi padding sistem dua kali (K5)

- **Gejala:** di landscape, `stty size` menunjukkan 2 baris (dengan keyboard) atau 14 baris (tanpa keyboard), padahal tampilan muat sekitar 5 dan 18.
- **Penyebab:** `TerminalView` mengurangi `MediaQuery.padding` dari tinggi barisnya (`_viewportHeight = size.height - padding.vertical`). Di potret, AppBar dari `Scaffold` sudah menghabiskan padding atas sehingga hampir benar. Tanpa AppBar, padding status bar (47 dp) dan bilah gesture (16 dp) terpotong lagi.
- **Perbaikan:** bungkus dengan `MediaQuery.removePadding(removeTop: true, removeBottom: true)`. Bonus: potret naik dari 43 ke 44 baris. Kode: lampiran A5.
- **Cara menguji:** bandingkan `terminal.viewHeight` dengan `floor(tinggi tampilan / lineHeight)`; lihat lampiran A10.

### 3.2 Banyak perubahan ukuran selama animasi keyboard (K5)

- **Gejala:** log mencatat belasan ukuran perantara (`19, 16, 12, 9, 7, 6, 5` baris) per animasi, dan semuanya sempat dikirim ke server.
- **Perbaikan:** kirim ukuran ke server setelah tampilan diam 150 ms, dan baca `terminal.viewWidth` dan `viewHeight` saat timer berbunyi (bukan nilai dari callback). Kode: lampiran A4.
- **Jangan:** mematikan `autoResize` sementara lalu menyalakannya lagi. Setter hanya memanggil `markNeedsLayout`, dan ukuran viewport sudah tercatat selama animasi, jadi ukuran **tidak** dihitung ulang dan terminal tertinggal di ukuran lama.

### 3.3 Seleksi teks: tidak ada gagang dan tidak ada Salin (K13)

- **Gejala:** tekan tahan hanya memilih satu kata dan hanya bisa melebar selama jari masih menempel. Setelah jari diangkat tidak ada gagang. Menyeret lagi memulai seleksi baru. Tidak ada tombol salin sama sekali.
- **Penyebab:** `xterm` 4.0.0 memang tidak punya gagang atau toolbar; hanya `selectWord` saat tekan tahan dan `selectCharacters` saat seret.
- **Perbaikan:** bungkus `TerminalView` dengan `Stack` berisi dua gagang yang bisa diseret dan bilah Salin/Batal, memakai `TerminalController.setSelection`. Matematikanya di lampiran A8.
- **Catatan implementasi:**
  - `RenderTerminal` tidak diekspor oleh paket. Akses lewat `TerminalViewState.renderTerminal` (butuh `GlobalKey<TerminalViewState>`) secara dinamis untuk `cellSize`, `getOffset`, `getCellOffset`, dan `lineHeight`. Rapuh terhadap versi `xterm`; kunci versinya.
  - Ujung seleksi bersifat eksklusif. Untuk batas antar-sel, geser setengah lebar sel sebelum memanggil `getCellOffset`.
  - **Belum ada gulir otomatis** saat gagang diseret ke tepi atas atau bawah.
  - Mengetuk terminal menghapus seleksi (perilaku bawaan `xterm`); gagang dan bilah berada di atas `TerminalView` sehingga ketukan pada keduanya tidak menghapusnya.
  - Pengenal gestur `xterm` menyimpan timer 300 ms untuk ketuk ganda; di test widget tunggu 400 ms setelah `tapAt` agar tidak ada timer sisa.
- **Status:** teruji otomatis (9 test: gagang muncul, geser memperluas dan menyempitkan, lintas baris, Salin mengisi clipboard, Batal, ketuk menghapus). Pengguna melaporkan hasil seleksi di HP sudah sesuai harapan.

### 3.4 Bracketed paste tergantung versi bash (K11)

- bash 5.1 ke atas menyalakan bracketed paste; bash 4.4 (Ubuntu 18.04) tidak. Di server lama, tempelan banyak baris **langsung dieksekusi**. `xterm` sudah benar (`terminal.paste` membungkus hanya bila mode menyala).
- **Implikasi desain:** dialog risiko tempel (layar 2c) wajib untuk tempelan banyak baris; jangan mengandalkan bracketed paste.
- Di `vim` bracketed paste menyala dan isi tempelan benar.

### 3.5 Hal kecil lain

- `Terminal(maxLines: 10000)` membatasi buffer tepat 10.000 baris. 300.000 baris `cat` (sekitar 2 MB) selesai sekitar 1 detik di PC.
- Ukuran awal `Terminal` adalah 80x24 sampai `TerminalView` melakukan layout. Dalam praktik PTY dibuat dengan ukuran layar yang benar (lihat 8.1).
- UTF-8: pakai `Utf8Decoder(allowMalformed: true)` pada aliran `stdout` dan `stderr` agar karakter multibyte yang terpotong antar paket tidak rusak. Karakter lebar menempati 2 kolom; emoji dan garis kotak benar.
- Ctrl+huruf: `terminal.charInput(c, ctrl: true)`. Ctrl pada panah: `keyInput(arrowLeft, ctrl: true)` menghasilkan `ESC [ 1 ; 5 D`.

---

## 4. Tata letak, keyboard, dan animasi

### 4.1 Landscape dengan keyboard: terminal hilang dan overflow (K5)

- **Gejala:** tulisan "BOTTOM OVERFLOWED BY 31 PIXELS", terminal 1 baris.
- **Penyebab:** sisa tinggi layar hanya sekitar 184 dp. AppBar (sekitar 80 dp) ditambah dua baris tombol (88 dp) sudah melebihi itu.
- **Perbaikan:** layar yang tingginya (di luar keyboard) kurang dari 480 dp memakai **mode ringkas**: tanpa AppBar, satu baris status 20 dp (32 dp bila keyboard tertutup, dengan tombol kembali dan sambung ulang), dan baris tombol cepat tunggal setinggi 36 dp yang bisa digeser. Kode: lampiran A5 dan A6.
- **Hasil di HP:** potret 44 baris (keyboard tertutup) dan 23 (terbuka); landscape 18 dan 5.
- **Keterbatasan fisik:** landscape dengan keyboard hanya menyisakan sekitar 5 baris. Itu batas layar, bukan bug.

### 4.2 Baris tombol cepat (K12)

- Tombol: Esc, Tab, Ctrl, Alt, `^C`, `^D`, panah, Home, End, PgUp, PgDn, `| ~ / -`, dan F1 sampai F12 lewat Fn.
- Ctrl dan Alt berlaku untuk satu ketukan berikutnya, **termasuk karakter dari keyboard sistem**, lewat pembungkus `terminal.onOutput` (lampiran A6).
- Tombol memakai `InkWell(canRequestFocus: false)` supaya tidak mengambil fokus dan **keyboard sistem tidak tertutup** saat tombol ditekan.
- Urutan yang terverifikasi di test: F1 = `ESC O P`, F5 = `ESC [ 15 ~`, Home = `ESC [ H`, PgUp = `ESC [ 5 ~`, panah atas = `ESC [ A`.
- **Belum terbukti di HP:** efek di program nyata (Ctrl+b lalu c di `tmux`, F10 di `htop`).

### 4.3 Animasi keyboard patah-patah (belum tuntas)

- **Gejala:** buka dan tutup keyboard terlihat seperti fps rendah.
- **Pengukuran** (mode profile, layar 60 Hz, selang antar-frame selama animasi): median 33,3 ms, artinya sekitar 30 fps.

| Varian | Animasi di 30 fps | Selang terburuk |
|---|---|---|
| Dasar (terminal berubah ukuran tiap frame) | 19 dari 26 | 83 ms |
| Tinggi tetap selama animasi | 19 dari 20 | 117 ms |
| Tinggi tetap + `RepaintBoundary` | 14 dari 17 | 117 ms |

- **Kesimpulan:** penghitungan ulang baris **bukan** penyebab utama. `RepaintBoundary` memperbaiki sedikit, tetapi tidak tegas (sampel kecil). Penyebab yang belum dipastikan: beban UI atau raster per frame, atau animasi keyboard Gboard sendiri.
- **Langkah berikutnya:** pisahkan waktu build dan raster lewat `FrameTiming`; coba build rilis (profile masih memuat overhead); periksa panggilan `TextInput.setEditableSizeAndTransform` per frame dari `RenderTerminal`; bandingkan dengan keyboard lain.
- **Cara mengukur:** catat `Duration` dari `SchedulerBinding.addPersistentFrameCallback` selama animasi (dari perubahan `viewInsets` pertama sampai tidak berubah 150 ms), lalu hitung median dan persentil selang antar-frame. Selang jauh di atas periode vsync (16,7 ms) berarti frame terlewat. Lampiran A9.

### 4.4 Bug dari upaya memperhalus animasi (sudah diperbaiki)

Percobaan "tinggi tetap selama animasi" memunculkan dua bug.

1. **Celah kosong di atas terminal saat keyboard menutup.** Terminal dibekukan di tinggi kecilnya sementara area membesar. Perbaikan: selama animasi, tinggi terminal = tinggi area + tinggi keyboard saat ini. Nilai itu **konstan sepanjang animasi**, naik maupun turun.
2. **Prompt hilang saat isi terminal hampir kosong.** Memotong dari atas (rata bawah) membuat prompt di baris atas ikut terpotong lalu muncul lagi. Perbaikan: `CursorShift` merata-atas lalu menggeser ke atas hanya sebanyak yang perlu supaya baris kursor terlihat.

**Pelajaran penting:** pergeseran **harus dihitung setelah anak di-layout**, bukan di `build()`. `xterm` mengubah ukuran terminal dan posisi kursor saat layout, jadi nilai dari `build()` selalu tertinggal satu frame. Percobaan pertama di `build()` membuat prompt tersembunyi 297 dp pada kasus layar penuh teks. Kode: lampiran A7.

**Cara menguji tanpa HP:** ubah `tester.view.viewInsets` bertahap per 16 ms, dan di tiap langkah periksa (a) tidak ada bagian area yang tidak tertutup terminal, (b) jumlah nilai `terminal.viewHeight` yang berbeda paling banyak 2, (c) baris kursor berada di dalam area. Uji untuk isi hanya prompt dan untuk layar penuh teks, naik dan turun.

---

## 5. Perilaku Android di latar belakang

### 5.1 Android mematikan soket aplikasi (K10)

Pengukuran (tekan Home, terminal tersambung):

| Jeda | Hasil |
|---|---|
| 13 s, 17 s, 50 s, 73 s | Masih hidup |
| 282 s (sekitar 5 menit) | **Putus** |

- **Bukti penyebab:** log sistem mencatat `Destroyed live tcp sockets for uids={<uid aplikasi>}` tepat 5 detik setelah aplikasi masuk latar belakang pada percobaan itu. Server tidak menutup sesinya. Dua percobaan sebelumnya selamat, jadi **waktunya tidak bisa diandalkan**.
- **Mekanisme (dokumentasi Android):** sejak Android 14, proses cached dibekukan 10 detik setelah masuk status itu, dan bila semua prosesnya beku, sistem menutup soket TCP aktifnya. Foreground service mencegah status cached. Lihat 5.3.
- **Implikasi:** sambung ulang harus menjadi alur utama, bukan kasus galat. Saat kembali ke aplikasi, periksa `client.isClosed`, lalu `client.ping().timeout(5 detik)`, sebelum menganggap sambungan hidup. Lampiran A4.
- **Belum diuji:** 30 menit (tidak ada gunanya setelah putus terbukti) dan iOS.

### 5.2 Sesi yatim di server

- Sesi yang soketnya dimatikan Android **tetap hidup di server** tanpa ada yang memakainya (`sshd: user@pts/N` berjalan berjam-jam).
- Pertimbangkan `ClientAliveInterval` dan `ClientAliveCountMax` di server, atau anjurkan `tmux` supaya sesi aman dilanjutkan dengan `tmux attach`.

### 5.3 Foreground service sebagai pengaturan opt-in (rancangan, belum diuji)

- Pengaturan "Pertahankan koneksi di latar belakang", default mati; bila menyala, service berjalan selama ada sesi. Biayanya baterai lebih banyak dan notifikasi permanen.
- Bukan jaminan: perpindahan jaringan atau sinyal hilang tetap memutus sesi, dan sambung ulang tetap alur utama.
- Izin dan deklarasi (`FOREGROUND_SERVICE`, tipe service dengan izinnya, `POST_NOTIFICATIONS`), teks antarmuka, perilaku notifikasi, dan cara menguji ada di `android.md`. Tipe service yang tepat (kandidat `specialUse`) dan syarat Play Store harus diverifikasi saat implementasi.
- Uji ulang K10 dengan service menyala di Wi-Fi tanpa kabel dan di baterai; periksa `dumpsys activity` bagian `Apps frozen` dan log `Destroyed live tcp`.

---

## 6. Penyimpanan rahasia dan biometrik

### 6.1 Rancangan (K15)

- Rahasia (password, kunci PEM, passphrase) disimpan lewat `flutter_secure_storage` (Android: RSA-OAEP + AES-GCM di Keystore).
- Pembacaan dijaga `local_auth` dengan `biometricOnly: true` (sidik jari saja, **tanpa jatuh ke PIN**). Menyimpan tidak meminta biometrik; yang dilindungi adalah pembacaan.
- Daftar host (host, port, user) bisa ditampilkan tanpa biometrik; hanya rahasianya yang meminta. Kode: lampiran A11.

### 6.2 Nama kunci penyimpanan terbaca di disk

- **Gejala:** `shared_prefs/FlutterSecureStorage.xml` memuat nama kunci apa adanya (`termul.secret.spike@10.0.2.2:2222`). Nilainya terenkripsi, tetapi siapa pun yang bisa membaca berkas itu tahu user dan host yang dipakai.
- **Perbaikan:** nama kunci memakai hash (`termul.secret.<32 hex pertama sha256>`). Paket `crypto` (BSD) menjadi dependensi langsung.

### 6.3 Konfigurasi Android yang wajib

- `MainActivity` harus `FlutterFragmentActivity` (bukan `FlutterActivity`) untuk `local_auth`.
- `AndroidManifest.xml`: izin `USE_BIOMETRIC` dan `android:allowBackup="false"`. Tanpa yang kedua, data terenkripsi bisa ikut ke backup cloud padahal kuncinya tidak ikut.
- `LaunchTheme` dan `NormalTheme` harus berinduk tema AppCompat (`Theme.AppCompat.DayNight.NoActionBar`) agar tidak crash di Android 8 ke bawah.
- `minSdk`: 23 untuk `flutter_secure_storage`, 24 untuk `local_auth`. Lampiran A12.

### 6.4 Cara memverifikasi di disk (jebakan)

- Periksa lewat `adb shell run-as <paket>` (hanya build debug). Cari teks rahasia di `shared_prefs`, `files`, dan `databases`.
- **Jangan** memeriksa seluruh direktori data: `flutter_assets/kernel_blob.bin` pada build debug memuat string literal dari kode (termasuk rahasia uji di file test) dan memberi hasil positif palsu.
- `flutter test` **meng-uninstall** aplikasi uji setelah selesai, sehingga data hilang sebelum bisa diperiksa. Gunakan `flutter drive --keep-app-running`.
- Hasil yang diperoleh: 0 berkas dengan teks biasa (password, PEM, passphrase, host, user); data bertahan setelah proses dimulai ulang; vault kosong setelah uninstall dan pasang ulang.

### 6.5 Belum diuji

- Jalur "biometrik dibatalkan" tidak terverifikasi dari log; hanya laporan pengguna bahwa prompt berfungsi.
- Perilaku bila sidik jari baru ditambahkan atau dihapus di pengaturan HP.
- Rancangan ini mengunci pembacaan di level aplikasi, **bukan** mengikat kunci Keystore ke biometrik. Pertimbangkan `AndroidOptions.biometric(enforceBiometrics: true)` bila butuh ikatan perangkat keras (belum dicoba).
- iOS: Keychain dan Face ID.

---

## 7. Lingkungan uji dan perkakas

| Masalah | Penyebab | Cara mengatasi |
|---|---|---|
| Gradle: `Android sdkmanager did not install NDK 28.2.13676358` | `sdkmanager` kini meneruskan ke Android CLI dan memecah nama paket di `;` | `android.exe --sdk=<path> sdk install ndk/28.2.13676358` (format `ndk/<versi>`) |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` di emulator | APK debug semua ABI 224 MB, penyimpanan AVD penuh | `--target-platform android-x64` (150 MB), hapus aplikasi lama, perbesar penyimpanan AVD |
| HP Xiaomi: `INSTALL_FAILED_USER_RESTRICTED` | Pembatasan pemasangan lewat USB HyperOS; kadang hanya sesaat | Aktifkan "Instal melalui USB"; ulangi beberapa kali dengan jeda |
| `adb shell input` dan `settings put` ditolak (`INJECT_EVENTS`, `WRITE_SETTINGS`) | HyperOS membatasi shell | Aktifkan "Debugging USB (Setelan keamanan)" bila ingin otomatisasi; opsional |
| `flutter test` menghapus aplikasi | Perilaku bawaan | `flutter drive --keep-app-running` |
| HP tidak bisa menjangkau sshd di PC | Jaringan terpisah | `adb reverse tcp:2222 tcp:2222`, lalu sambung ke `127.0.0.1:2222` |
| Variabel `$` hilang di perintah `wsl -c` | Shell perantara menelan `$` | Taruh perintah di berkas skrip dan jalankan dengan `wsl -e sh <skrip>` |
| Login password gagal di sshd uji | Konfigurasi `sshd_config.d` ikut `KbdInteractiveAuthentication` dan PAM | Pakai berkas konfigurasi sshd terpisah (`sshd -f`) di port lain agar `ssh.service` yang ada tidak terganggu |
| Tugas latar belakang dengan `&` mati saat skrip induk selesai | Proses anak ikut berhenti | Jadikan proses itu sendiri sebagai tugas latar belakang |
| Buffer logcat terlalu kecil untuk uji panjang | Bawaan 256 KB | `adb logcat -G 16M` (mengubah ukuran buffer **menghapus isinya**) |

Pola uji yang berguna:

- Uji SSH otomatis memakai variabel lingkungan atau `--dart-define` (`SPIKE_HOST`, `SPIKE_PORT`, `SPIKE_USER`, `SPIKE_PASSWORD`, dan seterusnya), jadi bisa dijalankan di PC dan di HP lewat `integration_test`. Kunci uji diambil dari `~/.spike_keys` di server lewat login password karena HP tidak bisa membaca folder di PC.
- Layout direproduksi di test widget dengan `tester.view.physicalSize`, `viewInsets`, dan `padding` meniru HP (landscape 853x393 dp, keyboard 209 dp, status bar 47 dp, bilah gesture 16 dp). Tulis test yang **gagal dulu** untuk memastikan reproduksi, baru perbaiki.
- Ukuran PTY diverifikasi dari **server** (`stty -F /dev/pts/N size`), bukan hanya dari ketikan di aplikasi.
- Waktu animasi dan kejadian latar belakang dicatat dengan `debugPrint` berawalan tetap (`K5`, `K10`, `KBPERF`) lalu dibaca dari `adb logcat -d`; ini lebih andal daripada ingatan pengguna.

---

## 8. Kesalahan analisis selama spike

Dicatat supaya tidak diulang.

1. **8.1 Dugaan "PTY dibuat 80x24 saat login" salah.** Pemotongan baris MOTD tampak seperti bukti, padahal MOTD Ubuntu adalah **teks cache** dari jam pembuatannya, bukan hasil PTY sesi itu. Pengukuran langsung (`stty size` dicatat dari `~/.bashrc` saat login) menunjukkan ukuran yang benar (`43 56`). Perubahan yang sudah dibuat untuk itu dibatalkan.
2. **8.2 Perekam ukuran PTY memantau terminal virtual yang salah.** Ada dua sesi dengan user yang sama: satu yatim dari uji K10, satu aktif. Pantau **semua** `pts` milik user.
3. **8.3 Hasil "0 berkas" pada pencarian teks biasa tidak valid** ketika aplikasi sebenarnya sudah ter-uninstall (`unknown package`). Pastikan targetnya ada sebelum menyimpulkan "tidak ditemukan".
4. **8.4 Menghitung posisi kursor di `build()`** (lihat 4.4): selalu tertinggal satu frame. Hitung setelah layout.
5. **8.5 Mematikan `autoResize` sementara** (lihat 3.2): tidak memicu penghitungan ulang saat dinyalakan lagi.
6. **8.6 Menduga penyebab fps rendah tanpa mengukur.** Dugaan "penghitungan ulang baris" ternyata bukan penyebab utama (lihat 4.3). Ukur dulu.

---

## 9. Yang tidak boleh dibawa mentah dari spike

- Daftar host tepercaya hanya di memori: sidik jari host harus **disimpan permanen** agar peringatan "host key berubah" bermakna antar sesi.
- Kolom kunci privat PEM **tidak disamarkan** dan tampil di layar. Tampilkan secukupnya atau sediakan impor dari berkas.
- Pengukur dan log (`_FramePerf`, `KBPERF`, `K5`, `K10`): alat ukur spike; buang sebelum rilis.
- Pembekuan tinggi terminal selama animasi keyboard memperbaiki tata letak (tanpa penghitungan ulang baris dan tanpa celah), tetapi **bukan** perbaikan fps. Putuskan ulang setelah penyebab patah-patah ditemukan.
- Akses `RenderTerminal` secara dinamis: rapuh; kunci versi `xterm` atau bungkus dalam satu kelas.
- Teks antarmuka tertulis langsung dalam Bahasa Indonesia; pindahkan ke lokalisasi.
- Tidak dibuat di spike: UI SFTP, alur sambung ulang otomatis, layar Vault penuh, gulir otomatis saat seleksi, dialog risiko tempel.
- Password uji, kunci uji, dan user `spike` di server hanya untuk spike; hapus setelah selesai.

---

## 10. Belum diuji atau belum terjawab

- **iPhone sama sekali:** K5 sampai K15, termasuk Keychain, Face ID, perilaku latar belakang iOS, dan lisensi App Store untuk tiap paket.
- **K9 dengan jaringan sungguhan:** pindah Wi-Fi ke seluler. Uji memakai `adb reverse` (USB), sehingga tidak terpengaruh perpindahan jaringan.
- **K10 selama 30 menit** dan dengan foreground service di Android.
- **K6 manual penuh:** warna `htop` dan tampilan `vim` oleh pengguna; K12 `tmux` Ctrl+b lalu c; tombol F di program nyata.
- **K13 di HP:** hasil seleksi dilaporkan sesuai harapan. Menempel hasil salin ke aplikasi lain tidak disebut secara terpisah.
- **Gulir otomatis** saat gagang diseret ke tepi.
- **Penyebab fps keyboard** (lihat 4.3).
- **Server lain:** distribusi yang lebih lama dari Ubuntu 18.04 dan OpenSSH tanpa ChaCha20.
- **Kunci PKCS#8** dan ECDSA P-384 atau P-521.

---

## 11. Lampiran: kode yang bisa dipakai ulang

Semua potongan di bawah berasal dari kode spike yang sudah dijalankan dan diuji. Sesuaikan nama dan gaya dengan project nyata.

### A1. Host key: sidik jari dan alasan penolakan

```dart
// callback sudah memberi "SHA256:<base64>" dalam byte UTF-8 (sama dengan ssh-keygen -lf)
String formatFingerprint(Uint8List bytes) => utf8.decode(bytes);

Future<bool> _verifyHostKey(String type, Uint8List fingerprint) async {
  final fp = formatFingerprint(fingerprint);
  final id = '${host}:${port}';
  final known = knownHosts[id];            // di project nyata: penyimpanan permanen
  if (known != null) {
    if (known == fp) return true;
    _hostKeyRejected = true;               // dartssh2 melaporkan SSHAuthAbortError, bukan SSHHostkeyError
    return false;                          // tampilkan peringatan "host key berubah"
  }
  final ok = await showTrustDialog(type, fp); // tampilkan fp, jenis kunci, id
  if (ok) { knownHosts[id] = fp; return true; }
  _hostKeyRejected = true;
  return false;
}

// saat menangkap galat:
} catch (e) {
  status = _hostKeyRejected ? 'Host key ditolak; koneksi dibatalkan' : 'Gagal: $e';
}
```

### A2. Pengawas keepalive dengan batas waktu

```dart
Timer startKeepAliveWatchdog(
  SSHClient client, {
  Duration interval = const Duration(seconds: 15),
  Duration timeout = const Duration(seconds: 10),
  void Function()? onDead,
}) {
  var pinging = false;
  return Timer.periodic(interval, (timer) async {
    if (pinging) return;
    pinging = true;
    try {
      await client.ping().timeout(timeout);
    } on TimeoutException {
      timer.cancel();
      onDead?.call();
      client.close();                      // memicu client.done
    } catch (_) {
      timer.cancel();
    } finally {
      pinging = false;
    }
  });
}

// membuat klien: matikan keepalive bawaan
final client = SSHClient(
  socket,
  username: user,
  onPasswordRequest: password.isEmpty ? null : () => password,
  identities: identities,
  onVerifyHostKey: _verifyHostKey,
  algorithms: spikeAlgorithms,
  keepAliveInterval: null,
);
final watchdog = startKeepAliveWatchdog(client, onDead: () => keepAliveDead = true);
```

### A3. Urutan cipher

```dart
const spikeAlgorithms = SSHAlgorithms(cipher: [
  SSHCipherType.chacha20poly1305,   // 31 MB/s di PC, 11,9 MB/s di HP (profile)
  SSHCipherType.aes256ctr,
  SSHCipherType.aes128ctr,
  SSHCipherType.aes256gcm,          // bawaan dartssh2 mendahulukan ini: ~1 MB/s
  SSHCipherType.aes128gcm,
]);
```

### A4. Shell, ukuran terminal terdebounce, dan pemeriksaan setelah latar belakang

```dart
final session = await client.shell(
  pty: SSHPtyConfig(width: terminal.viewWidth, height: terminal.viewHeight),
);

// UTF-8 streaming agar karakter multibyte yang terpotong antar paket tidak rusak
void pipe(Stream<Uint8List> s) => s
    .cast<List<int>>()
    .transform(const Utf8Decoder(allowMalformed: true))
    .listen(terminal.write);
pipe(session.stdout);
pipe(session.stderr);

terminal.onOutput = (data) {
  final out = applyModifiers(data, ctrl: _ctrl, alt: _alt);   // lihat A6
  _releaseModifiers();
  session.write(Uint8List.fromList(utf8.encode(out)));
};

// kirim ukuran setelah tampilan diam; baca nilai terbaru saat timer berbunyi
Timer? _resizeTimer;
terminal.onResize = (w, h, pw, ph) {
  _resizeTimer?.cancel();
  _resizeTimer = Timer(const Duration(milliseconds: 150), () {
    session.resizeTerminal(terminal.viewWidth, terminal.viewHeight);
  });
};

// pemeriksaan sambungan setelah kembali dari latar belakang (WidgetsBindingObserver)
Future<void> _checkAfterBackground(int secs) async {
  final c = _client;
  String result;
  if (c == null) {
    result = 'belum ada sambungan';
  } else if (c.isClosed) {
    result = 'sudah putus (soket ditutup)';
  } else {
    try {
      await c.ping().timeout(const Duration(seconds: 5));
      result = 'masih hidup';
    } on TimeoutException {
      result = 'mati (ping tidak dibalas)';
    } catch (e) {
      result = 'putus ($e)';
    }
  }
  // tampilkan status; jika putus, tawarkan sambung ulang / tmux attach
}
```

### A5. Tata letak halaman terminal: mode ringkas dan padding

```dart
static const _compactBelowDp = 480.0;

Widget build(BuildContext context) {
  final mq = MediaQuery.of(context);
  final compact = mq.size.height - mq.viewInsets.bottom < _compactBelowDp;
  final keyboardOpen = mq.viewInsets.bottom > 0;

  return Scaffold(
    appBar: compact ? null : AppBar(/* judul, status, tombol sambung ulang */),
    body: Column(children: [
      if (compact)
        SafeArea(                               // pengganti AppBar: satu baris
          bottom: false,
          child: SizedBox(
            height: keyboardOpen ? 20 : 32,
            child: /* [kembali] status satu baris [sambung ulang] (tombol hanya saat keyboard tertutup) */,
          ),
        ),
      Expanded(
        // TerminalView mengurangi MediaQuery.padding dari tinggi barisnya.
        // Buang padding atas dan bawah supaya tidak terpotong dua kali.
        child: SafeArea(                        // sisi kiri-kanan (lekukan layar)
          top: false,
          bottom: false,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: TerminalView(terminal, autofocus: true),
          ),
        ),
      ),
      QuickKeyBar(/* ..., compact: compact */),
    ]),
  );
}
```

### A6. Tombol cepat dan Ctrl/Alt sekali pakai

```dart
/// Ctrl+huruf menjadi kode kontrol (Ctrl+C = 0x03); Alt memberi awalan ESC.
String applyModifiers(String data, {required bool ctrl, required bool alt}) {
  if (data.length != 1 || (!ctrl && !alt)) return data;
  var c = data.codeUnitAt(0);
  var out = data;
  if (ctrl) {
    if (c >= 0x61 && c <= 0x7a) c -= 0x20;            // a-z menjadi A-Z
    if (c >= 0x40 && c <= 0x5f) out = String.fromCharCode(c - 0x40);
  }
  return alt ? '\x1b$out' : out;
}

// tombol: jangan ambil fokus supaya keyboard sistem tidak tertutup
InkWell(canRequestFocus: false, onTap: onTap, child: ...);

// pemetaan
terminal.keyInput(TerminalKey.escape, ctrl: ctrl, alt: alt);   // Esc, Tab, panah, Home, End, PgUp, PgDn, F1..F12
terminal.charInput('c'.codeUnitAt(0), ctrl: true);             // tombol ^C
terminal.textInput(applyModifiers('|', ctrl: ctrl, alt: alt)); // simbol sulit diketik

// mode ringkas: semua tombol dalam satu baris setinggi 36 dp yang bisa digeser
SizedBox(
  height: 36,
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [for (final k in keys) SizedBox(width: 56, child: k)]),
  ),
);
```

### A7. Tinggi tetap selama animasi keyboard, dengan baris kursor tetap terlihat

```dart
// di build(): selama animasi (inset berubah) terminal diberi tinggi tanpa keyboard
// = tinggi area + tinggi keyboard saat ini (konstan sepanjang animasi).
// _insetSettled menjadi false saat viewInsets berubah dan true lagi setelah diam 150 ms.
LayoutBuilder(builder: (context, c) {
  final animating = !_insetSettled;
  final h = animating ? c.maxHeight + mq.viewInsets.bottom : c.maxHeight;
  return ClipRect(
    child: CursorShift(
      childHeight: h,
      cursorBottom: () {
        final dynamic r = _termViewKey.currentState?.renderTerminal;
        if (r == null) return null;
        final row = CellOffset(0, terminal.buffer.absoluteCursorY);
        return (r.getOffset(row) as Offset).dy + (r.lineHeight as double);
      },
      child: /* SafeArea + removePadding + RepaintBoundary + TerminalView */,
    ),
  );
});

// didChangeMetrics (WidgetsBindingObserver): tandai animasi
void didChangeMetrics() {
  final inset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
  if (inset == _lastInset) return;
  _lastInset = inset;
  if (_insetSettled) setState(() => _insetSettled = false);
  _insetTimer?.cancel();
  _insetTimer = Timer(const Duration(milliseconds: 150), () {
    if (mounted) setState(() => _insetSettled = true);
  });
}
```

```dart
// CursorShift: memberi anak tinggi tetap yang boleh melebihi ruang, lalu menggesernya
// ke atas hanya sebanyak yang perlu supaya baris kursor terlihat.
// Dihitung SETELAH anak di-layout (xterm mengubah ukuran dan posisi kursor saat layout).
class CursorShift extends SingleChildRenderObjectWidget {
  const CursorShift({super.key, required this.childHeight, required this.cursorBottom, super.child});
  final double childHeight;
  final double? Function() cursorBottom;   // batas bawah baris kursor dalam koordinat anak

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCursorShift(childHeight, cursorBottom);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCursorShift)
      ..childHeight = childHeight
      ..cursorBottom = cursorBottom;
  }
}

class _RenderCursorShift extends RenderShiftedBox {
  _RenderCursorShift(this._childHeight, this.cursorBottom) : super(null);
  double _childHeight;
  set childHeight(double v) {
    if (v == _childHeight) return;
    _childHeight = v;
    markNeedsLayout();
  }
  double? Function() cursorBottom;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(BoxConstraints.tightFor(width: size.width, height: _childHeight));
    final overflow = _childHeight - size.height;
    var shift = 0.0;
    if (overflow > 0) {
      final cb = cursorBottom();
      if (cb != null) shift = (cb - size.height).clamp(0.0, overflow);
    }
    (child.parentData! as BoxParentData).offset = Offset(0, -shift);
  }
}
```

### A8. Seleksi dengan gagang (inti perhitungan)

```dart
// Struktur: Stack(fit: expand) { TerminalView(key, controller, scrollController), overlay }
// Overlay mendengarkan controller, scrollController, dan terminal; setState ditunda
// ke akhir frame bila pendengar terpanggil saat layout (gulir).

final range = controller.selection!.normalized;      // begin inklusif, end eksklusif
final start = render.getOffset(range.begin) as Offset;   // pojok kiri atas sel
final end   = render.getOffset(range.end)   as Offset;
final cell  = render.cellSize as Size;
// gagang: bulatan di bawah sel; area sentuh 44x44
final center = Offset(anchor.dx, anchor.dy + cell.height + 14);

// saat seret: jari ada di bulatan, sel yang dimaksud ada di atasnya
void updateDrag(Offset global, CellOffset fixed) {
  final local = overlayBox.globalToLocal(global);
  final p = local - Offset(0, 14 + cell.height / 2);
  final hit = render.getCellOffset(Offset(p.dx + cell.width / 2, p.dy)) as CellOffset; // batas antar-sel
  final target = CellOffset(
    hit.x.clamp(0, terminal.viewWidth),
    hit.y.clamp(0, terminal.buffer.lines.length - 1),
  );
  controller.setSelection(
    terminal.buffer.createAnchorFromOffset(fixed),   // sisi yang tidak digeser
    terminal.buffer.createAnchorFromOffset(target),
  );
}
// gagang awal: fixed = range.end; gagang akhir: fixed = range.begin
// Salin:
final text = terminal.buffer.getText(range);
await Clipboard.setData(ClipboardData(text: text));
controller.clearSelection();
```

### A9. Pengukur kehalusan animasi

```dart
class _FramePerf {
  _FramePerf._() {
    SchedulerBinding.instance.addPersistentFrameCallback((t) {
      if (_recording) _frames.add(t);
    });
  }
  static final instance = _FramePerf._();
  bool _recording = false;
  final List<Duration> _frames = [];

  void start() { _frames.clear(); _recording = true; }

  String stop() {
    _recording = false;
    if (_frames.length < 3) return 'terlalu sedikit';
    final gaps = [for (var i = 1; i < _frames.length; i++)
        (_frames[i] - _frames[i - 1]).inMicroseconds / 1000]..sort();
    double pct(double p) => gaps[((gaps.length - 1) * p).round()];
    final median = pct(0.5);
    return 'frame=${_frames.length} median=${median.toStringAsFixed(1)}ms '
        'p90=${pct(0.9).toStringAsFixed(1)}ms maks=${gaps.last.toStringAsFixed(1)}ms';
  }
}
// panggil start() saat viewInsets mulai berubah, stop() setelah diam 150 ms, cetak dengan debugPrint
```

### A10. Test layout (tanpa HP)

```dart
const dpr = 3.0;
tester.view.devicePixelRatio = dpr;
tester.view.physicalSize = Size(853 * dpr, 393 * dpr);                   // landscape HP uji
tester.view.viewInsets = FakeViewPadding(bottom: 209 * dpr);             // keyboard
tester.view.padding = const FakeViewPadding(top: 47 * dpr, bottom: 16 * dpr);
addTearDown(tester.view.reset);

await tester.pumpWidget(MaterialApp(home: TerminalPage(/* host yang tidak terjangkau */)));
await tester.pump();
// ... baca tinggi tampilan dan jumlah baris:
final view = tester.widget<TerminalView>(find.byType(TerminalView));
final render = tester.allRenderObjects.firstWhere((r) => r.runtimeType.toString() == 'RenderTerminal');
final lineHeight = (render as dynamic).lineHeight as double;
final h = tester.getSize(find.byType(TerminalView)).height;
expect(view.terminal.viewHeight, (h / lineHeight).floor());              // tidak boleh kurang
await tester.pump(const Duration(seconds: 11));                          // biarkan timeout sambungan habis

// animasi keyboard: ubah viewInsets bertahap
for (var i = 1; i <= 10; i++) {
  tester.view.viewInsets = FakeViewPadding(bottom: (from + (to - from) * i / 10) * dpr);
  await tester.pump(const Duration(milliseconds: 16));
  // periksa celah, jumlah nilai viewHeight yang berbeda, dan baris kursor di dalam area
}
```

### A11. Vault (rahasia di Keystore, dibuka dengan biometrik)

```dart
class Vault {
  Vault({FlutterSecureStorage? storage, Authenticator? authenticate})
      : _storage = storage ?? const FlutterSecureStorage(),
        _authenticate = authenticate ?? _biometric;       // bisa diganti di test

  // nama kunci ditulis apa adanya di disk (hanya nilainya yang terenkripsi): pakai hash
  static String _secretKey(String id) =>
      'termul.secret.${sha256.convert(utf8.encode(id)).toString().substring(0, 32)}';

  // sidik jari saja, tanpa jatuh ke PIN atau pola
  static Future<bool> _biometric(String reason) => LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

  static Future<bool> biometricAvailable() async {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return false;
    return (await auth.getAvailableBiometrics()).isNotEmpty;
  }

  // daftar (id, host, port, user) tidak rahasia: dibaca tanpa biometrik
  Future<List<HostSummary>> list() async { /* baca kunci 'termul.hosts' (JSON) */ }

  // menyimpan tidak meminta biometrik; yang dilindungi adalah pembacaan
  Future<HostSummary> save({required String host, required int port,
      required String user, required HostSecrets secrets}) async {
    final id = '$user@$host:$port';
    await _storage.write(key: _secretKey(id), value: jsonEncode(secrets.toJson()));
    // perbarui indeks (ganti entri dengan id sama, jangan menggandakan)
  }

  Future<HostSecrets> load(String id) async {
    final bool ok;
    try {
      ok = await _authenticate('Buka kredensial $id');
    } catch (e) {
      throw VaultLockedException('Biometrik tidak bisa dipakai: $e');
    }
    if (!ok) throw VaultLockedException('Biometrik dibatalkan atau gagal');
    final raw = await _storage.read(key: _secretKey(id));
    if (raw == null) throw VaultLockedException('Kredensial $id tidak ditemukan');
    return HostSecrets.fromJson(jsonDecode(raw));
  }
}
```

### A12. Konfigurasi Android

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity()      // bukan FlutterActivity (local_auth)
```

```xml
<!-- AndroidManifest.xml -->
<!-- foreground service (belum diuji): lihat android.md untuk izin, tipe, dan service -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<application android:allowBackup="false" ...>       <!-- data terenkripsi tidak ikut backup -->
```

```xml
<!-- res/values/styles.xml: induk harus AppCompat -->
<style name="LaunchTheme" parent="Theme.AppCompat.DayNight.NoActionBar">...</style>
<style name="NormalTheme" parent="Theme.AppCompat.DayNight.NoActionBar">...</style>
```

```yaml
# pubspec.yaml
dependencies:
  dartssh2: ^4.1.0
  xterm: ^4.0.0          # kunci versi: seleksi dan tata letak bergantung pada internalnya
  flutter_secure_storage: ^11.2.0
  local_auth: ^3.0.2
  crypto: ^3.0.7
```
