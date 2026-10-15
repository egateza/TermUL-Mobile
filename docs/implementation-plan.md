# Rencana implementasi: irisan pertama

Status: **usulan, menunggu persetujuan.** Belum ada kode aplikasi yang ditulis.
Tanggal: 2026-10-15

Tujuan irisan pertama: tambah host, lihat daftar, ketuk lalu verifikasi host key, lalu terminal berjalan di HP Android.

Rujukan: `CLAUDE.md`, `docs/design/` (terutama `spike-temuan.md` lampiran A1 dan seterusnya, `flutter.md`, `tokens.json`, `components/`).

## 1. Keadaan project sekarang

Folder berisi hasil `flutter create` bawaan (Flutter 3.47.7), masih contoh counter, belum ada git. Tiga hal belum sesuai `CLAUDE.md`:

| Hal | Sekarang | Seharusnya |
|---|---|---|
| `applicationId` dan namespace | `com.example.termul_mobile` | id organisasi sendiri (lihat pertanyaan terbuka) |
| `minSdk` | `flutter.minSdkVersion` | 24 (dikunci) |
| Folder `ios/` | ada | dihapus; Android saja (bisa dibuat ulang dengan `flutter create`) |

## 2. Struktur folder

```
lib/
  main.dart, app.dart            # MaterialApp, tema, rute
  core/
    theme/                       # TermulColors, TermulSpacing, TermulSize, TermulRadius, TermulText
    ssh/                         # SshConnection, keepalive_watchdog, algoritma cipher
    storage/                     # host_store (daftar host), known_hosts_store (sidik jari), vault (rahasia)
  features/
    hosts/                       # daftar host dan form tambah host (data, state, ui)
    host_key/                    # layar verifikasi host key
    terminal/                    # layar terminal, QuickKeyBar, mode ringkas
  shared/widgets/                # Button, Card, HostRow, StatusDot, Banner, BottomSheet, KeyButton, ...
test/                            # mengikuti struktur lib/
assets/fonts/                    # IBM Plex Sans, JetBrains Mono (periksa lisensi OFL)
```

Di luar irisan pertama: seleksi teks, SFTP, snippet, streak, widget layar utama, foreground service, dialog tempel.

## 3. Langkah irisan pertama

| # | Langkah | Sumber kode atau desain |
|---|---|---|
| 0 | Rapikan project (bagian 1). Dependensi dikunci: `dartssh2` 4.1.0, `xterm` 4.0.0, `flutter_secure_storage`, `local_auth`, `crypto`. Konfigurasi Android: `FlutterFragmentActivity`, `USE_BIOMETRIC`, `allowBackup="false"`, tema AppCompat. Catat lisensi tiap paket di `docs/`. | A12, bagian 6.3 |
| 1 | Tema: token warna, jarak, ukuran, radius, gaya teks, dan font. | `flutter.md`, `tokens.json` |
| 2 | Widget bersama yang dipakai irisan ini. | `components/*/README.md`, prototipe `Main` |
| 3 | Daftar host: kelompok, cari, filter. Kolom status tampil "belum diperiksa" (pengecekan online belum ada). | prototipe `Main`, A11 (daftar tanpa biometrik) |
| 4 | Form tambah host (password atau kunci privat). Rahasia disimpan di Vault, dibuka dengan biometrik. Format kunci yang tidak didukung (PKCS#8) ditandai jelas. | A11, bagian 2.5 |
| 5 | Sambungan SSH: ChaCha20 didahulukan, pengawas keepalive, `keepAliveInterval: null`, sidik jari disimpan permanen. | A1, A2, A3 |
| 6 | Layar verifikasi host key: host baru, dan host key berubah yang memblokir koneksi dengan peringatan tersendiri. Penolakan punya pesan "Host key ditolak". | prototipe `HostKey`, A1 |
| 7 | Layar terminal: tata letak potret dan mode ringkas, ukuran PTY terdebounce 150 ms, baris tombol cepat (Ctrl dan Alt sekali pakai), UTF-8 streaming, `maxLines` 10.000. | A4, A5, A6 |
| 8 | Banner "Menyambung ulang", sambung ulang, dan pemeriksaan sambungan setelah kembali dari latar belakang. | A4, `spike.md` |

Urutan kerja: 0 dan 1, lalu 5 dan 6 (logika dan test dulu), lalu 3 dan 4, lalu 7 dan 8. Tiap langkah berhenti di titik yang bisa diuji.

## 4. Aturan yang berlaku (ringkas dari CLAUDE.md)

- Teks antarmuka Bahasa Indonesia; hanya token dari `tokens.json`, tanpa warna atau ukuran tertulis langsung di widget.
- Status selalu dengan kata; target sentuh minimal 44 px; tanpa bayangan; hormati reduce motion.
- Rahasia tidak ditulis ke berkas, log, atau konsol. Tidak ada kredensial server di repo, termasuk contoh dan tes.
- Tutup `SSHClient`, sesi, `Terminal`, timer, dan pengawas di `dispose`. Jangan memblokir thread UI saat keluaran deras.
- Hal yang menyangkut jaringan, latar belakang, keyboard, dan biometrik diuji di HP fisik, bukan emulator.

## 5. Yang belum teruji

- **Seluruhnya belum dijalankan di project ini.** Kode lampiran terbukti di spike, bukan di project baru; tiap fitur diuji ulang di HP setelah dipindahkan.
- **Sebagian uji spike belum lengkap di HP:** Ctrl dan tombol F di program nyata (`tmux`, `htop`), jalur biometrik dibatalkan, dan responsivitas tombol saat keluaran deras.
- **Animasi keyboard sekitar 30 fps, penyebabnya belum diketahui.** Pembekuan tinggi terminal (A7) memperbaiki tata letak, bukan fps, jadi **tidak dimasukkan** ke irisan ini. Dimulai dari tata letak biasa (A5). Ukur ulang di project nyata (bagian 4.3 dan A9).
- **Akses `RenderTerminal`** (A7, A8) rapuh terhadap versi `xterm`; dipakai hanya di seleksi dan A7, yang di luar irisan ini.
- **Jaringan sungguhan:** pindah Wi-Fi ke seluler belum diuji (spike memakai USB lewat `adb reverse`).
- **Sambung ulang otomatis (langkah 8) kode baru.** Hanya pemeriksaan sambungan (A4) yang terbukti.
- **Penyimpanan sidik jari permanen (langkah 5 dan 6) kode baru.** Di spike hanya di memori.
- **Pengecekan online di daftar host** belum ada rancangan teknisnya.
- **Perilaku sidik jari baru atau dihapus di pengaturan HP** terhadap Vault belum diuji.
- **iOS tidak diuji sama sekali.** Tidak ada klaim atau kode untuk iOS.

## 6. Pertanyaan terbuka

1. Id organisasi/`applicationId`: usulan `id.co.pelangi.termul` atau `com.termul.mobile`.
2. Setuju folder `ios/` dihapus?
3. Server Ubuntu 24.04 dari spike: user `spike` di server itu belum dibersihkan (tidak ada akses dari sesi ini). Perintah: `sudo pkill -u spike; sudo userdel -r spike`, lalu hapus `spike_sshd_config` bila ada. User `spike`, kunci uji, dan konfigurasi sshd uji di dua distro WSL (Ubuntu-18.04 dan 22.04) sudah dihapus pada 2026-10-15.
4. Setuju urutan dan isi irisan di atas?
