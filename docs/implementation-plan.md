# Rencana implementasi: irisan pertama

Status: **disetujui; langkah 0 dan 1 dikerjakan (lihat bagian 11).** Langkah 2 dan seterusnya menunggu laporan dua langkah ini.
Tanggal: 2026-10-15

## 0. Perubahan di revisi 3

- Jawaban pemilik atas pertanyaan terbuka revisi 2 sudah dimasukkan (bagian 10 sekarang mencatat keputusan).
- **Aturan penguncian rahasia diubah:** dari "sidik jari saja, tanpa PIN" (spike) menjadi tiga tingkat: biometrik, kredensial perangkat (PIN, pola, sandi), atau tanpa penguncian dengan peringatan (bagian 3.3 dan 3.4). Ini mengubah keputusan K15 di `spike.md` dan butir "Rahasia" di `CLAUDE.md`; keduanya perlu disesuaikan (usulan kalimat di bagian 10).
- **`profiles.json` asli dari desktop sudah dibaca** (23 profil). Temuannya mengubah model `authMethod`, fixture, dan risiko langkah 5 (bagian 3.2 dan 9).

Tujuan irisan pertama: tambah host, lihat daftar, ketuk lalu verifikasi host key, lalu terminal berjalan di HP Android.

Rujukan: `CLAUDE.md`, `docs/design/` (terutama `spike-temuan.md` lampiran A1 dan seterusnya, `flutter.md`, `tokens.json`, `components/`), dan repo desktop `egateza/TermUL` (commit `b3d7854150`, 2026-10-15): `docs/ARCHITECTURE.md`, `docs/adr/0002-vault-design.md`, `ProfileStore`, `ProfileSnapshot`, `HostProfile`, `StreakStore`, `KnownHostsStore`, `CredentialVault`.

## Cara membaca status

| Tanda | Arti |
|---|---|
| **[T]** | Terbukti di spike di HP Android (POCO 25053PC47G) |
| **[TO]** | Terbukti hanya lewat test otomatis di spike, belum di HP |
| **[B]** | Kode atau rancangan baru, belum pernah dijalankan |
| **[?]** | Asumsi yang belum diverifikasi |

Tidak ada klaim untuk iOS. iOS tidak diuji dan tidak dicakup rencana ini.

## 1. Keputusan yang berlaku

- `applicationId` dan namespace: `io.github.egateza.termul`.
- Android saja, `minSdk` 24. Folder `ios/` dihapus (riwayat git menyimpannya; commit awal `6a08a52`).
- Di luar irisan pertama: foreground service, SFTP, snippet, streak, widget layar utama, seleksi teks, dialog tempel, dan `FileCredentialVault` (`vault.bin`).
- A7 (tinggi tetap saat animasi keyboard) tidak dimasukkan; mulai dari A5.
- A9 dan alat ukur spike (`_FramePerf`, `KBPERF`, `K5`, `K10`) tidak masuk kode produksi (lihat bagian 8).

## 2. Struktur folder

```
lib/
  main.dart, app.dart               # ProviderScope, MaterialApp, tema, rute (Navigator bawaan)
  l10n/                             # app_id.arb dan hasil gen-l10n
  core/
    theme/                          # TermulColors, TermulSpacing, TermulSize, TermulRadius, TermulText
    io/
      atomic_file.dart              # tulis atomik, baca JSON, karantina berkas rusak
    models/                         # HostProfile, ProfileSnapshot, KnownHost, SecretType (menyerupai desktop)
    storage/
      host_repository.dart          # antarmuka HostRepository
      known_hosts_repository.dart   # antarmuka KnownHostsRepository
      json/                         # JsonHostRepository, JsonKnownHostsRepository (di atas atomic_file)
    vault/
      credential_vault.dart         # antarmuka CredentialVault
      keystore_credential_vault.dart
    ssh/                            # SshConnection, keepalive_watchdog, algoritma cipher
  features/
    hosts/                          # daftar host, form tambah/ubah, hapus
    connect/                        # alur sambung: host key, rahasia hilang, status menyambung
    terminal/                       # layar terminal, QuickKeyBar, mode ringkas
  shared/widgets/                   # Button, Card, HostRow, StatusDot, Banner, BottomSheet, KeyButton, ...
  debug/                            # alat ukur, hanya terhubung bila flag debug (bagian 8)
test/                               # mengikuti struktur lib/
docs/                               # termasuk licenses.md dan keputusan baru
assets/fonts/                       # IBM Plex Sans, JetBrains Mono (lisensi OFL belum diverifikasi, lihat bagian 6)
```

Dibuat saat dibutuhkan (bukan di irisan pertama): `streak.json` dan `settings.json`. Berkas `settings.json` baru dibuat ketika ada pengaturan pertama yang perlu disimpan.

## 3. Penyimpanan (disamakan dengan desktop)

### 3.1 Aturan umum

Semua berkas JSON ada di folder pribadi aplikasi (`path_provider`, `getApplicationSupportDirectory`). `allowBackup="false"` membuat folder ini tidak ikut backup.

- **Tulis atomik [B]:** tulis ke berkas sementara di folder yang sama, `flush`, lalu `rename` ke nama akhir (pola `AtomicFiles.write` desktop). `File.rename` di folder yang sama memakai `rename(2)`. [?] Belum diverifikasi: apakah `RandomAccessFile.flush()` di Android melakukan `fsync`, dan Dart tidak punya `fsync` untuk folder, jadi ketahanan terhadap mati daya sedikit di bawah desktop.
- Setiap berkas punya field `version` (atau `format` untuk streak). Properti tak dikenal diabaikan saat membaca.
- **Berkas rusak [B]:** dipindah ke `<nama>.corrupt-<epoch ms>`, lalu mulai dari kosong (pola `StreakStore` desktop). Catatan perbedaan: `ProfileStore` desktop justru melempar galat dan tidak menyentuh berkas. Mobile memakai karantina seperti permintaan, tetapi UI wajib menampilkan banner "Daftar host rusak, disimpan sebagai …" supaya mulai-dari-kosong tidak tampak seperti data hilang.
- Tidak memakai drift atau SQLite.
- Akses lewat antarmuka `HostRepository` dan `KnownHostsRepository` di atas satu helper (`atomic_file.dart`), sehingga implementasi bisa diganti.
- Mutasi menahan satu kunci per repository (setara `synchronized` desktop) dan menulis sebelum mengumumkan perubahan ke pendengar.

### 3.2 Berkas

| Berkas | Isi | Sumber desain |
|---|---|---|
| `profiles.json` | Skema desktop: `version` (1), `groups`, `profiles`, `favorites`, `recent` (maks. 5, terbaru di depan). Tanpa secret. UUID profil menjadi id rahasia. | `ProfileSnapshot`, `HostProfile` |
| `known_hosts.json` | Per `host:port`: daftar `{type, fingerprint}`, fingerprint `SHA256:…`. Permanen. Ditulis **sebelum** login dilanjutkan. | rancangan baru; desktop memakai berkas `known_hosts` format OpenSSH |
| `streak.json` | `{format: 1, count, lastDay}` dengan `lastDay` tanggal ISO (`2026-10-13`), sama dengan desktop. | `StreakStore` (nanti, di luar irisan) |
| `settings.json` | Pengaturan mobile sendiri. | nanti |

**`profiles.json`, field `profiles[]`** mengikuti komponen record desktop: `id`, `name`, `group`, `host`, `port`, `username`, `authMethod`, `privateKeyPath`, `jumpHostId`, `environment`, `initialDirectory`, `notes`, `autoSudo`, `os`, `terminalTheme`, `wslDistro`.

Pembedaan di mobile:

- `privateKeyPath` dan `wslDistro` **tidak dipakai** di mobile (disimpan apa adanya bila ada, tidak diisi oleh UI mobile).
- `authMethod`: model membaca ketiga nilai desktop (`KEY`, `PASSWORD`, `AGENT`) supaya berkas desktop tetap termuat, tetapi **UI mobile hanya menawarkan `KEY` dan `PASSWORD`**. Profil `AGENT` ditampilkan dengan keterangan "Perlu kunci atau password di HP" dan tidak bisa disambung sebelum diubah. (Di sampel desktop, 22 dari 23 profil memakai `AGENT`.) **[B]**
- `jumpHostId` boleh disimpan, belum dipakai (di sampel ada 1 profil yang memakainya).
- Field desktop lain (`environment`, `initialDirectory`, `notes`, `autoSudo`, `os`, `terminalTheme`) tetap ada di model supaya bolak-balik baca-tulis tidak menghilangkannya, walau UI mobile belum memakainya. [B]
- Validasi meniru `HostProfile`: nama, host, username wajib; port 1 sampai 65535; grup dinormalkan (segmen di-trim, pemisah `/`); id duplikat ditolak; `favorites` dan `recent` membuang id yang tidak ada. [B]

**Risiko kompatibilitas dengan desktop [?]:** `HostProfile` desktop menolak `authMethod: KEY` tanpa `privateKeyPath`. Jika mobile menulis profil `KEY` tanpa path, berkas itu **tidak bisa dimuat desktop sama sekali** (desktop melempar galat untuk seluruh berkas). Selama berkas tidak dibagikan antar perangkat ini tidak berdampak; ia berdampak begitu ada impor/ekspor. Keputusan sementara: mobile menulis `privateKeyPath: null` (keputusan 1, bagian 10); konversi dibahas saat impor/ekspor dibuat.

**Temuan dari `profiles.json` asli (dibaca manual, 23 profil):**

| Hal di berkas | Akibat untuk mobile |
|---|---|
| 22 profil `AGENT`, 1 `PASSWORD`, 0 `KEY` | Di HP tidak ada agen SSH, jadi profil desktop Anda tidak akan langsung bisa dipakai; kunci harus ditambahkan di HP (impor berkas) atau pakai password. |
| Grup `Development` dan grup kosong dipakai profil tetapi tidak ada di daftar `groups` (hanya `Production` dan `Sewa`) | Daftar grup yang tampil harus **dihitung** dari `groups` ditambah grup milik profil, seperti `allGroups()` desktop. Masuk test langkah 1. |
| Ada `jumpHostId` (profil "gapura08 jumphost …" lewat "rekon public") | Dipertahankan saat baca-tulis; sambungan lewat jump host belum didukung. Kebutuhan nyata, jadi layak jadi irisan berikutnya. |
| `wslDistro` terisi pada 1 profil dengan host `localhost` | Tidak bermakna di HP; ditampilkan sebagai tidak didukung, tidak dihapus. |
| 5 profil `os: null`, `terminalTheme` selalu null, `environment` hampir semuanya `NONE` (satu `DEV`, tidak ada `PROD`) | Model menerima `os` null; mobile tidak memakai `environment` untuk guard di irisan ini. |
| `favorites` berisi 1 id, `recent` 5 id, semuanya ada di daftar profil | Sesuai aturan `ProfileSnapshot` (id yang tidak ada dibuang). |
| Port tidak standar (2211), nama berisi spasi dan tanda kurung, karakter `.` pada nama | Tidak boleh ada asumsi format nama atau port. |
| Pemformatan Jackson (`"key" : nilai`) | Hanya soal tampilan; pembaca JSON Dart tidak terpengaruh. Mobile menulis format sendiri. |
| OS server: 7 × Ubuntu 14.04, 5 × 18.04, 1 × 22.04, 2 × 24.04, 3 × 26.04, 5 tak terdeteksi | Server lama jauh lebih banyak dari yang diuji spike (hanya 18.04 dan 24.04). Lihat risiko langkah 5. |

**Fixture:** berkas asli **tidak dimasukkan ke repo** (memuat nama server dan alamat IP internal serta satu IP publik; berkasnya juga tidak saya simpan ke disk). Fixture dibuat dengan data karangan (alamat dari blok dokumentasi `192.0.2.x`) dengan semua keunikan di tabel di atas.

**Status online host** adalah cache di memori (provider), tidak ditulis ke `profiles.json` dan tidak diperlakukan sebagai fakta. Di UI diberi label "belum diperiksa" sampai ada hasil, dengan waktu terakhir diperiksa.

**`known_hosts.json`:** dartssh2 hanya memberi tipe dan sidik jari, bukan blob kunci, jadi formatnya tidak kompatibel dengan OpenSSH `known_hosts`. Id entri `host:port` dengan host huruf kecil [B]. Aturan keputusan:

| Keadaan | Hasil |
|---|---|
| Tidak ada entri untuk `host:port` | Host baru: tampilkan dialog, simpan bila dipercaya |
| Ada entri dengan tipe dan sidik jari sama | Lanjut |
| Ada entri dengan tipe sama, sidik jari beda | **Host key berubah: blokir** dengan peringatan tersendiri |
| Ada entri, tetapi tidak satu pun bertipe sama | Tidak akan terjadi: untuk host yang sudah dikenal, algoritma host key yang diminta dibatasi ke tipe yang tersimpan (`SSHAlgorithms(hostkey: [...])`; parameter ini ada di `dartssh2` 4.1.0 dan berupa daftar urut preferensi, diperiksa di kode paket). Bila server tidak lagi punya tipe itu, sambungan gagal dengan pesan "host key berubah" |

### 3.3 Rahasia: `CredentialVault`

Antarmuka menyerupai `CredentialVault` desktop (ambil, simpan, hapus per id profil dan tipe), tetapi tanpa metode master password:

```dart
enum AuthLevel { biometric, deviceCredential, none }   // tingkat penguncian HP saat ini

abstract interface class CredentialVault {
  Future<AuthLevel> authLevel();                                   // dibaca ulang tiap kali, bukan di-cache lama
  Future<String?> get(String profileId, SecretType type);          // prompt sesuai tingkat; null = tidak ada
  Future<Map<SecretType, String>> getMany(String profileId, Set<SecretType> types); // satu prompt
  Future<bool> has(String profileId, SecretType type);             // tanpa biometrik
  Future<void> put(String profileId, SecretType type, String secret);
  Future<void> remove(String profileId, SecretType type);
  Future<void> removeProfile(String profileId);                    // semua tipe
}
```

- **Enkripsi tidak bergantung pada biometrik.** Semua rahasia selalu terenkripsi lewat `flutter_secure_storage` (Keystore). Yang berbeda antar HP hanyalah **gerbang di aplikasi saat membaca** (tabel di bawah). Gerbang ini adalah penjaga di tingkat aplikasi, bukan ikatan kriptografis ke sidik jari atau PIN (`spike-temuan.md` 6.5).
- Tingkat penguncian (keputusan 2, **mengubah keputusan K15 spike**):

  | `AuthLevel` | Kondisi HP | Saat membaca rahasia | Saat menyimpan |
  |---|---|---|---|
  | `biometric` | Ada sidik jari atau wajah terdaftar | Prompt sistem; bila pengguna memilih, boleh dengan PIN/pola/sandi perangkat | Boleh |
  | `deviceCredential` | Tanpa biometrik, tetapi ada PIN, pola, atau sandi layar kunci | Prompt sistem dengan PIN, pola, atau sandi yang dipakai pengguna | Boleh |
  | `none` | Tidak ada penguncian layar sama sekali | **Tanpa prompt** (tetap terenkripsi) | **Boleh dengan peringatan** |

- Implementasi `KeystoreCredentialVault`: `flutter_secure_storage` (Keystore) dan `local_auth` dengan `biometricOnly: false`, yang di Android menambahkan `DEVICE_CREDENTIAL` ke `BiometricPrompt` (diperiksa di kode `local_auth_android` 2.3.0). Penentuan tingkat: `getAvailableBiometrics()` tidak kosong → `biometric`; kalau kosong dan `isDeviceSupported()` benar (mampu biometrik **atau** jatuh ke kredensial perangkat, menurut dokumentasi `local_auth`) → `deviceCredential`; selain itu `none`. Pola ini hanya sebagian **[T]** (A11 memakai `biometricOnly: true`); jalur PIN/pola/sandi dan ketepatan deteksi `none` **[?]** belum pernah dijalankan di HP.
- Nama kunci ber-hash dan injeksi `Authenticator` untuk test tetap dari A11 **[T]**.
- Berbeda dari A11: satu entri per `(profileId, tipe)`, bukan satu JSON per host; nama kunci `termul.secret.<32 hex pertama sha256("<uuid>|<TIPE>")>` **[B]**. `getMany` dibuat supaya satu sambungan (mis. kunci privat dan passphrase) hanya satu prompt sidik jari **[B]**.
- `SecretType`: `LOGIN_PASSWORD`, `KEY_PASSPHRASE`, `SUDO_PASSWORD`, `ROOT_PASSWORD` dengan kode 1 sampai 4 sama dengan desktop (jangan diubah urutannya), ditambah `PRIVATE_KEY_PEM` kode **5, khusus mobile** (desktop menyimpan kunci sebagai berkas lewat `privateKeyPath`, jadi tidak punya padanannya). Bila nanti `FileCredentialVault` dibuat, desktop harus mentoleransi kode 5 (`SecretType.fromCode` desktop melempar untuk kode asing) **[?]**.
- Di irisan pertama hanya `LOGIN_PASSWORD`, `KEY_PASSPHRASE`, dan `PRIVATE_KEY_PEM` yang dipakai.
- Rahasia hanya sebagai `String` sementara di memori. Dart tidak bisa menimpa memori `String` dengan nol seperti `char[]` di desktop, jadi **sifat zero-out desktop tidak bisa disamai [?]**; mitigasinya: jangan simpan di field berumur panjang, jangan log.

**`FileCredentialVault` yang kompatibel dengan `vault.bin`: di luar irisan, hanya risikonya yang dicatat.**

- Format desktop (ADR 0002): master password → Argon2id (default m=64 MiB, t=3, p=1, salt 16 byte) → KEK; KEK membungkus DEK; tiap rahasia AES-256-GCM dengan nonce 12 byte dan AAD `profileId|secretType`; header `MYTV`, big-endian.
- Padanan DPAPI di Android: DEK dibungkus kunci Keystore yang dibuka biometrik (rancangan). [B]
- Risiko performa: Argon2id 64 MiB di Dart murni belum pernah diukur di HP. Spike mengukur AES-GCM Dart murni hanya sekitar 1 MB/s (`spike-temuan.md` 2.4), jadi untuk vault kecil tidak masalah, tetapi waktu Argon2id dan tekanan memori 64 MiB di HP kelas bawah **belum diukur [?]**.
- Risiko paket: `pointycastle` 4.0.0 (MIT, sudah menjadi dependensi turunan `dartssh2`) memuat `Argon2BytesGenerator` dan `GCMBlockCipher` (diperiksa di arsip paket, belum dijalankan). Alternatif yang dilihat di pub.dev: `cryptography` 2.9.0 (Apache-2.0) dan `hashlib` 2.4.2 (BSD-3-Clause); belum dievaluasi.
- Risiko kompatibilitas: parameter Argon2 harus identik dan diverifikasi dengan vektor uji dari vault desktop yang nyata **[?]**; bila meleset, vault tidak terbuka tanpa pesan galat yang berguna.
- Risiko keamanan: master password dan DEK di memori Dart (lihat atas); desktop sendiri mengakui trade-off serupa pada opsi DPAPI.

### 3.4 Perilaku yang dirancang (semuanya **[B]**, belum teruji)

| Situasi | Perilaku |
|---|---|
| HP tanpa biometrik, dengan PIN/pola/sandi (`deviceCredential`) | Rahasia tetap bisa disimpan; membukanya meminta PIN, pola, atau sandi yang dipakai pengguna. Tidak ada peringatan khusus. |
| HP tanpa penguncian sama sekali (`none`) | Form menampilkan banner peringatan di dekat kolom rahasia: "HP ini tidak punya kunci layar. Siapa pun yang memegang HP bisa membuka server ini tanpa kata sandi. Menyimpan kredensial di sini berbahaya." Penyimpanan **tetap diizinkan** (hanya peringatan, tanpa kotak centang). Rahasia tetap terenkripsi; hanya tidak ada gerbang saat dibaca. Peringatan juga muncul di layar yang memakai rahasia tersimpan. |
| Tingkat penguncian berubah setelah rahasia disimpan (mis. kunci layar dihapus atau sidik jari diganti) | `authLevel()` dibaca ulang saat membaca; gerbang mengikuti keadaan terbaru. Apakah rahasia lama tetap terbaca di Android (kunci Keystore tidak diikat ke autentikasi) belum diuji **[?]**. |
| Rahasia tidak ditemukan (Keystore tidak berlaku, atau baris host ada tanpa rahasia) | `get` mengembalikan null atau melempar galat platform → layar "Rahasia hilang" yang meminta rahasia dimasukkan ulang, lalu menyimpan dan melanjutkan sambungan. Galat dari Keystore (mis. kunci tidak berlaku lagi) diperlakukan sama dengan tidak ditemukan. |
| Hapus host | Urutan: (1) `removeProfile`, (2) hapus baris host, (3) hapus sidik jari `host:port` **hanya bila tidak ada profil lain yang memakai `host:port` itu**. Gagal di tengah → keadaan berikutnya tetap aman: baris tanpa rahasia (jatuh ke "Rahasia hilang") atau sidik jari yatim (tidak berbahaya). |
| Rahasia yatim | Dibersihkan saat aplikasi mulai. Daftar nama kunci yang valid dihitung dari `sha256(id|tipe)` untuk semua profil; entri `termul.secret.*` di luar daftar itu dihapus. **Syarat keselamatan:** pembersihan tidak dijalankan bila `profiles.json` dikarantina pada start yang sama, karena semua rahasia akan tampak yatim padahal berkas yang rusak mungkin masih bisa dipulihkan. Daftar entri yang ada dibaca dari berkas indeks `vault_index.json` (nama kunci ber-hash, bukan rahasia), yang ditulis **sebelum** rahasia disimpan dan dihapus **setelah** rahasia dihapus (keputusan 3). Perilaku ini baru dan belum teruji. |
| Sidik jari HP berubah | Dengan `biometricOnly` di level aplikasi, rahasia tetap bisa dibaca setelah sidik jari ditambah atau dihapus (kunci Keystore tidak terikat biometrik). Perilaku sebenarnya di HP belum diuji (`spike-temuan.md` 6.5). |

### 3.5 Input kunci privat

Usulan: **impor dari berkas** lewat `file_selector` 1.1.0 (BSD-3-Clause, paket resmi flutter.dev; di Android memakai `file_selector_android` 0.5.2+11 yang berlisensi BSD-3-Clause dan Apache-2.0 bersama). Isi berkas dibaca sebagai byte, divalidasi, disimpan ke Keystore sebagai `PRIVATE_KEY_PEM`, lalu tidak disimpan path-nya. Tempel dari papan klip tidak disediakan: isi papan klip bisa dibaca aplikasi lain dan riwayat papan klip tidak terkendali. Kolom yang menampilkan kunci di layar (seperti spike) **tidak dibawa**.

- Format didukung (`spike-temuan.md` 2.5, **[T]**): `OPENSSH PRIVATE KEY`, `RSA PRIVATE KEY` (PKCS#1), `EC PRIVATE KEY`.
- PKCS#8 (`PRIVATE KEY`) dan jenis lain: ditolak dengan pesan khusus, mis. "Format kunci ini belum didukung (PKCS#8). Ubah dengan `ssh-keygen -p -m PEM -f <berkas>` atau pakai kunci OpenSSH." **[B]** (teks akhir ditentukan saat implementasi; perintah `ssh-keygen` perlu diverifikasi).
- Passphrase salah atau kosong: `SSHKeyDecryptError` → pesan jelas. **[T]**
- Pemilih berkas di HP (SAF, URI konten) belum diuji **[?]**; berkas kunci dengan izin berlebih tidak berlaku di Android.

## 4. Langkah irisan pertama

Setiap langkah berhenti di titik yang bisa diuji. "Uji" memisahkan apa yang bisa di PC dari apa yang wajib di HP fisik.

### Langkah 0. Rapikan project

- Ganti `applicationId` dan namespace menjadi `io.github.egateza.termul`; pindahkan `MainActivity.kt` ke paket baru dan ubah ke `FlutterFragmentActivity`. **[T]** untuk `FlutterFragmentActivity` (A12), **[B]** untuk pemindahan paket.
- Hapus `ios/` dan bersihkan referensi iOS di `.metadata`. Kunci `minSdk` 24 (sekarang `flutter.minSdkVersion`).
- Manifest: izin `USE_BIOMETRIC`, `android:allowBackup="false"`. Tema `LaunchTheme` dan `NormalTheme` berinduk AppCompat. **[T]** (A12, 6.3).
- `pubspec.yaml` dengan versi persis (bagian 6), `l10n.yaml`, `analysis_options.yaml` (`flutter_lints` 6.0.0), `docs/licenses.md`.
- **Uji:** `flutter analyze`, `flutter build apk --debug --target-platform android-arm64`, pasang di HP dan buka aplikasi kosong.

### Langkah 1. Lapisan data (Dart murni)

- `atomic_file.dart`, model (`HostProfile`, `ProfileSnapshot`, `KnownHost`), `HostRepository` dan `KnownHostsRepository` beserta implementasi JSON (bagian 3).
- **Uji (PC, `flutter test`):** bolak-balik baca-tulis; properti tak dikenal diabaikan; berkas rusak dikarantina dan mulai kosong; kegagalan di tengah tulis tidak merusak berkas lama (suntik galat sebelum rename); validasi sama dengan desktop (port test `HostProfileTest` dan `ProfileStoreTest` desktop sebagai acuan); `favorites` dan `recent` dibersihkan.
- **Fixture:** `profiles.json` karangan yang menyalin semua keunikan sampel asli (bagian 3.2): `AGENT`, `PASSWORD` dengan `wslDistro`, `jumpHostId`, grup tidak terdaftar di `groups`, `os` null, port 2211, nama berkas tanda kurung, `favorites` dan `recent`. Test tambahan: memuat berkas dengan 23 profil, grup dihitung benar, dan baca-tulis bolak-balik tidak menghilangkan field.
- **Belum teruji di HP:** `rename`, `flush`, dan folder `path_provider` di Android (di HP, uji manual: simpan lalu matikan paksa aplikasi lalu buka lagi).

### Langkah 2. Tema, lokalisasi, dan widget bersama

- Token → `ThemeData` dan `ThemeExtension` (`flutter.md`, `tokens.json`); font IBM Plex Sans dan JetBrains Mono sebagai aset.
- Lokalisasi sesuai bagian 7.
- Widget yang dipakai irisan ini: `Button`, `IconButton`, `Card`, `Chip`, `TextField`, `Banner`, `BottomSheet`, `StatusDot`, `HostRow`, `KeyButton`, `Switch` (rujukan: `components/*/README.md`, prototipe `Main` dan `HostKey`).
- **Uji:** test widget (fokus 2 px `accent`, target sentuh minimal 44 px, status dengan kata, reduce motion); lihat di HP untuk kontras dan ukuran nyata.
- **[B]:** seluruh widget baru. **[?]:** lisensi font OFL belum diverifikasi (bagian 6).

### Langkah 3. Vault

- `CredentialVault`, `KeystoreCredentialVault`, perilaku di bagian 3.4, dan impor kunci (bagian 3.5).
- **Uji PC:** vault dengan penyimpanan dan autentikator palsu (pola A11 **[T]** untuk injeksi `Authenticator`); `getMany` hanya meminta autentikasi sekali; urutan hapus; perhitungan nama kunci yatim.
- **Uji HP (wajib), untuk tiap tingkat `AuthLevel`:** (1) `biometric`: simpan, mulai ulang, baca dengan sidik jari; batalkan prompt; (2) `deviceCredential`: hapus sidik jari dari HP lalu baca dengan PIN atau pola; (3) `none`: hapus kunci layar lalu pastikan peringatan muncul, simpan tetap berhasil, baca tanpa prompt; pindah antar tingkat setelah rahasia tersimpan; setelah uninstall data hilang; tidak ada teks biasa di `shared_prefs` (cara memeriksa: `spike-temuan.md` 6.4, jangan memeriksa `kernel_blob.bin`).
- **Belum teruji:** jalur "dibatalkan" (spike hanya laporan pengguna), sidik jari ditambah atau dihapus, kunci Keystore tidak berlaku, pembersihan yatim, dan semua yang baru di bagian 3.4.

### Langkah 4. Daftar host dan form

- Daftar dengan grup, cari, filter Semua/Favorit/Online; status "belum diperiksa"; form tambah dan ubah host (password atau kunci), hapus host (urutan 3.4). Rujukan: prototipe `Main`, README `HostRow`, `TextField`, `Switch`, A11.
- **Uji PC:** state (Riverpod) dengan repository palsu; filter dan pencarian; hapus host memanggil urutan yang benar.
- **Uji HP:** tambah, ubah, hapus host; tutup paksa lalu buka lagi; banner HP tanpa biometrik; banner berkas rusak.
- **[B]:** seluruh UI dan state. Pengecekan online belum ada; kolom status hanya penampung.

### Langkah 5. Sambungan SSH dan host key (logika)

- `SshConnection`: soket, `SSHClient` dengan ChaCha20 didahulukan **[T]** (A3), `keepAliveInterval: null` dan pengawas keepalive **[T]** (A2), pengambilan rahasia dari vault, `onVerifyHostKey` memakai `KnownHostsRepository` (aturan 3.2) dengan pola A1 **[T]**. Penulisan sidik jari ke `known_hosts.json` dilakukan **di dalam** callback sebelum mengembalikan `true`; bila penulisan gagal, kembalikan `false` dan laporkan galatnya. **[B]**
- Alasan penolakan dicatat sendiri (`SSHAuthAbortError` tidak spesifik). **[T]** (A1)
- Autentikasi: password, kunci (dengan atau tanpa passphrase). **[T]** (K1, K2, K3)
- **Uji PC:** server uji sementara di WSL (user dan kunci uji dibuat baru, dihapus setelah selesai, **kredensial lewat `--dart-define`, tidak masuk repo**); `known_hosts.json` ditulis sebelum login; sidik jari berubah memblokir; tipe berbeda sesuai keputusan 5; keepalive mendeteksi proxy yang berhenti meneruskan (cara di `spike-temuan.md` 2.3).
- **Uji HP:** login password dan kunci via `adb reverse`.
- **Belum teruji:** penyimpanan sidik jari yang permanen (spike hanya memori) dan seluruh aturan 3.2, termasuk pembatasan `SSHAlgorithms(hostkey: …)` ke tipe tersimpan (jenis galat bila server tidak punya tipe itu belum diketahui); perpindahan jaringan sungguhan (K9).
- **Kompatibilitas server lama [?]:** 7 dari 23 profil Anda berjalan di Ubuntu 14.04 (OpenSSH sekitar 6.6) dan 5 di 18.04; spike hanya menguji 18.04 dan 24.04. Daftar algoritma bawaan `dartssh2` 4.1.0 membuang algoritma lama (SHA-1, CBC, grup DH lama). Server 14.04 mungkin tidak mau bernegosiasi. Ini harus diuji di salah satu server 14.04 sungguhan (atau distro 14.04 di WSL) di langkah 5, sebelum UI dibangun di atasnya; bila gagal, opsi algoritma lama per host perlu dirancang.

### Langkah 6. Layar alur sambung

- Verifikasi host key (host baru dan host key berubah dengan konfirmasi dan pilihan aman sebagai tombol utama), layar "Rahasia hilang", status menyambung dengan kata. Rujukan: prototipe `HostKey` dan README `Banner`, `BottomSheet`, `Button`; A1.
- Teks penolakan "Host key ditolak" terpisah dari galat lain. **[T]** (logika), **[B]** (UI).
- **Uji PC:** test widget untuk tiga keadaan; tombol "Ganti key dan sambung" menunggu konfirmasi eksplisit.
- **Uji HP:** host baru, host key diganti (ubah kunci di server uji), penolakan, rahasia dihapus.
- **Belum teruji:** semua UI di langkah ini di HP, dan perilaku bila host key berubah selagi layar terkunci.

### Langkah 7. Layar terminal

- `Terminal(maxLines: 10000)`, shell dengan ukuran PTY sebenarnya, UTF-8 streaming (`allowMalformed`), ukuran terdebounce 150 ms, `MediaQuery.removePadding`, mode ringkas di bawah 480 dp, dan `QuickKeyBar` (Esc, Tab, Ctrl dan Alt sekali pakai termasuk dari keyboard sistem, `^C`, `^D`, panah, Home, End, PgUp, PgDn, simbol, F1 sampai F12). Dari A4, A5, A6 **[T]**; A7 tidak dipakai.
- **Uji PC:** A10 (layout tanpa HP) dan test kode tombol (`applyModifiers`, urutan F-key, Home, PgUp, panah).
- **Uji HP:** `htop`, `vim`, `tmux`, `nano`; potret 44 baris tanpa keyboard dan 23 dengan keyboard; landscape 18 dan 5; `stty size` dari server cocok dengan layar; `yes | head -n 200000` tidak membuat UI macet.
- **Belum teruji (dari spike, tetap berlaku):** Ctrl dan tombol F di program nyata (`tmux`, `htop`); responsivitas tombol saat keluaran deras; warna `htop` dan tampilan `vim` dikonfirmasi pengguna.
- **Belum diketahui:** penyebab animasi keyboard sekitar 30 fps (`spike-temuan.md` 4.3). Tanpa A7, animasi mengikuti perilaku `xterm` dan mungkin sama patah-patahnya atau lebih; perlu diukur setelah langkah ini.

### Langkah 8. Menyambung ulang

- Banner "Menyambung ulang" dengan kata, tombol "Sambung sekarang", riwayat layar tetap terlihat; pemeriksaan sambungan setelah kembali dari latar belakang (`isClosed` lalu `ping` dengan batas 5 detik) **[T]** (A4); sambung ulang otomatis **[B]** (belum ada di spike).
- **Uji PC:** proxy yang memutus; sambung ulang berhasil dan gagal; pembersihan sumber daya (`SSHClient`, sesi, `Terminal`, timer, pengawas) di `dispose`.
- **Uji HP:** tekan Home 13 detik dan 5 menit; matikan Wi-Fi; sambung ulang berhasil.
- **Belum teruji:** sambung ulang otomatis; perpindahan Wi-Fi ke seluler; Android mematikan soket tidak bisa diprediksi waktunya (K10), jadi uji ulang beberapa kali.

## 5. Daftar langkah dan status ringkas

| Langkah | Terbukti di spike | Kode baru |
|---|---|---|
| 0 | konfigurasi Android (A12) | pemindahan paket, hapus iOS |
| 1 | pola atomik dan karantina ada di desktop | seluruh lapisan data |
| 2 | – | seluruh tema dan widget |
| 3 | A11 (Keystore + biometrik) | satu entri per tipe, `getMany`, kunci 5, impor, yatim, HP tanpa biometrik |
| 4 | – | seluruh UI dan state |
| 5 | A1, A2, A3 | penyimpanan sidik jari permanen, aturan tipe |
| 6 | logika A1 | seluruh UI |
| 7 | A4, A5, A6 | integrasi, test A10 di project baru |
| 8 | pemeriksaan sambungan A4 | sambung ulang otomatis |

## 6. Dependensi

Versi persis, tanpa `^`, sama dengan spike untuk lima paket yang diminta. Tanggal verifikasi: **2026-10-15**.

**Metode verifikasi.** Dependensi diselesaikan di project percobaan terpisah (`flutter pub get` dengan Flutter 3.47.7, di luar repo). Untuk **89 paket hosted** (langsung dan turunan) saya (1) membaca berkas `LICENSE` di arsip paket, dan (2) membandingkannya dengan tag `license:` dari API pub.dev (`/api/packages/<nama>/score`). Hasilnya cocok untuk 89 dari 89 setelah satu pengulangan (satu permintaan API `flutter_lints` gagal sekali lalu berhasil). Tidak ada GPL, LGPL, AGPL, atau MPL. Paket SDK (`flutter`, `flutter_test`, `flutter_localizations`, `flutter_web_plugins`) berlisensi BSD-3-Clause mengikuti SDK; `sky_engine` memuat Apache-2.0. Klasifikasi dari berkas `LICENSE` memakai pencocokan teks, jadi bukan pembacaan hukum; yang mendasarinya adalah tag pub.dev.

### Langsung (di `pubspec.yaml`)

| Paket | Versi | Lisensi | Jenis | Verifikasi | Alasan |
|---|---|---|---|---|---|
| `dartssh2` | 4.1.0 | MIT | dependency | LICENSE + pub.dev | klien SSH (keputusan tetap) |
| `xterm` | 4.0.0 | MIT | dependency | LICENSE + pub.dev | emulator terminal (keputusan tetap; bukan `xterm3`) |
| `flutter_secure_storage` | 11.2.0 | BSD-3-Clause | dependency | LICENSE + pub.dev | rahasia di Keystore |
| `local_auth` | 3.0.2 | BSD-3-Clause | dependency | LICENSE + pub.dev | biometrik |
| `crypto` | 3.0.7 | BSD-3-Clause | dependency | LICENSE + pub.dev | hash nama kunci |
| `path_provider` | 2.1.6 | BSD-3-Clause | dependency | LICENSE + pub.dev | folder pribadi aplikasi |
| `uuid` | 4.6.0 | MIT | dependency | LICENSE + pub.dev | UUID profil |
| `flutter_riverpod` | 3.4.3 | MIT | dependency | LICENSE + pub.dev | state management (bagian 6.1) |
| `file_selector` | 1.1.0 | BSD-3-Clause | dependency | LICENSE + pub.dev | impor kunci dari berkas (bagian 3.5) |
| `intl` | 0.20.3 | BSD-3-Clause | dependency | LICENSE + pub.dev | dibutuhkan lokalisasi ARB; dibatasi oleh `flutter_localizations` |
| `flutter_localizations` | SDK | BSD-3-Clause | dependency (SDK) | LICENSE akar SDK | lokalisasi |
| `flutter_lints` | 6.0.0 | BSD-3-Clause | dev | LICENSE + pub.dev | analisis |
| `flutter_test` | SDK | BSD-3-Clause | dev (SDK) | LICENSE akar SDK | test |

Catatan: `file_selector_android` 0.5.2+11 (turunan) memuat dua lisensi dalam satu berkas: BSD-3-Clause dan Apache-2.0; keduanya permisif. `intl` menyesuaikan versi SDK; versi 0.20.3 adalah yang terselesaikan di Flutter 3.47.7, bisa berubah saat SDK diperbarui.

### Turunan (ringkas, semuanya diverifikasi dua arah)

| Lisensi | Jumlah | Paket |
|---|---|---|
| MIT | 7 | `equatable` 2.1.0, `pinenacl` 0.6.0, `pointycastle` 4.0.0, `riverpod` 3.4.3, `state_notifier` 1.0.0, `yaml` 3.1.4, `zmodem` 0.0.6 |
| BSD-2-Clause | 1 | `asn1lib` 1.6.5 |
| Apache-2.0 | 4 | `clock` 1.1.3, `fake_async` 1.3.3, `material_color_utilities` 0.13.0, `quiver` 3.2.2 |
| BSD-3-Clause | sisanya | `args`, `async`, `boolean_selector`, `characters`, `code_assets`, `collection`, `convert`, `cross_file`, `ffi`, `ffi_leak_tracker`, `fixnum`, `hooks`, `http`, `http_parser`, `jni`, `jni_flutter`, `jni_util`, `leak_tracker*`, `lints`, `listen`, `logging`, `matcher`, `meta`, `objective_c`, `package_config`, `path`, `platform`, `plugin_platform_interface`, `pub_semver`, `record_use`, `source_span`, `stack_trace`, `stream_channel`, `string_scanner`, `term_glyph`, `test_api`, `typed_data`, `vector_math`, `vm_service`, `web`, `win32`, `xdg_directories`, serta paket antarmuka dan platform `*_android`, `*_darwin`, `*_ios`, `*_linux`, `*_macos`, `*_windows`, `*_web`, `*_platform_interface` milik `flutter_secure_storage`, `local_auth`, `path_provider`, `file_selector`, dan `flutter_plugin_android_lifecycle` |

Daftar lengkap 89 paket beserta versi dihasilkan dari `pubspec.lock` dan akan disalin ke `docs/licenses.md` pada langkah 0 (bukan sekarang; saya belum mengubah `pubspec.yaml`).

Catatan: paket platform non-Android (`*_darwin`, `*_ios`, `*_linux`, `*_macos`, `*_windows`, `*_web`, `objective_c`, `win32`, `xdg_directories`) ikut terselesaikan oleh pub, tetapi saya belum memeriksa apakah ada yang masuk ke APK Android; dugaan saya tidak. **[?]**

### Yang belum diverifikasi

- **Lisensi font:** IBM Plex Sans dan JetBrains Mono. Dugaan OFL (`flutter.md`), tetapi berkas lisensi dan versi font yang akan dibundel belum saya baca. Harus dicek saat langkah 2, dan berkas lisensinya ikut dibundel.
- **Tag `license:` pub.dev bukan nasihat hukum**, dan belum ada pemeriksaan hak paten atau merek dagang.
- **Apakah ada paket yang berubah versi** antara hari ini dan saat langkah 0 jalan: `pubspec.lock` di repo adalah acuan; ulangi verifikasi bila ada pembaruan.
- Paket yang **tidak** ditambahkan: `drift`, `sqflite`, `go_router`, `freezed`, `riverpod_generator`, `build_runner`, `shared_preferences`.

### 6.1 State management: usulan `flutter_riverpod` 3.4.3 (MIT)

Alasan:

- Aplikasi punya objek yang hidup lebih lama dari layar: sesi SSH (tab "Sesi"), repository, vault. Provider bisa memegangnya tanpa `BuildContext`, jadi bisa dites dan dibuang rapi (`ref.onDispose` untuk `SSHClient`, sesi, `Terminal`, timer).
- Status asinkron (memuat, galat, kosong) punya padanan langsung (`AsyncValue`), sesuai kebutuhan layar daftar host, "Rahasia hilang", dan status menyambung.
- Pengganti repository di test cukup dengan `ProviderContainer(overrides: …)`.
- Tanpa generator kode: hanya `flutter_riverpod`, tanpa `build_runner`, supaya rantai build dan dependensi turunan tetap kecil.

Alternatif yang dipertimbangkan: `provider` (lebih sederhana, tetapi tidak menangani status asinkron dan objek berumur panjang sebaik itu) dan `flutter_bloc` (lebih banyak kode upacara untuk ukuran aplikasi ini; belum dicek lisensinya). Riverpod 3 mengubah API dibanding 2 (API lama dipindah ke `flutter_riverpod/legacy`, dan `state_notifier` ikut sebagai dependensi turunan); tim perlu mengikuti dokumentasi 3.x. **[?]** Belum dipakai di project ini.

## 7. Lokalisasi

Usulan: **ARB sejak awal**, dengan satu bahasa (`id`).

- `flutter_localizations` (SDK) dan `intl`, `l10n.yaml`, `lib/l10n/app_id.arb`, kode hasil `flutter gen-l10n`.
- Alasan: salinan desain memuat banyak kalimat dengan angka dan nama ("Tempel 3 baris?", "N sesi tersambung", "Sisa 2 ketukan lagi"); ARB memberi placeholder dan format jamak bertipe sehingga tidak ada penyambungan string. Memindahkan ratusan string tersebar di kemudian hari lebih mahal daripada memulai dengan ARB (`spike-temuan.md` bagian 9 sudah mencatat hal ini).
- Biaya: setiap teks butuh `BuildContext` (`AppLocalizations.of(context)`), jadi lapisan non-UI (repository, `SshConnection`) tidak boleh membawa teks; ia mengembalikan galat bertipe dan UI yang memetakannya ke teks. Itu juga mencegah rahasia atau detail teknis tidak sengaja masuk pesan. **[B]**
- Alternatif yang ditolak: konstanta teks di satu berkas. Lebih ringan hari ini, tetapi tanpa jamak dan placeholder bertipe, dan harus dimigrasi bila bahasa kedua pernah dibutuhkan.

## 8. Tes dan alat ukur

- **A10 (test layout tanpa HP)** masuk rencana tes langkah 7 **[TO]**: ukuran fisik, `viewInsets`, dan `padding` meniru HP (landscape 853x393 dp, keyboard 209 dp, status bar 47 dp, bilah gesture 16 dp); bandingkan `terminal.viewHeight` dengan `floor(tinggi / lineHeight)`; tulis test yang gagal dulu sebelum memperbaiki.
- Tes lain: data (langkah 1), vault dengan autentikator palsu (langkah 3), state dengan repository palsu (langkah 4), `applyModifiers` dan kode tombol (langkah 7), dan integrasi SSH melawan server uji sementara (`integration_test`, kredensial lewat `--dart-define`, tidak pernah di repo).
- **Alat ukur spike** (`_FramePerf`/A9, `KBPERF`, `K5`, `K10`) tidak boleh ada di build rilis. Bila dibutuhkan lagi, hanya di `lib/debug/` dan diaktifkan oleh `const bool.fromEnvironment('TERMUL_PERF')`, yang membuat kompilator membuang kodenya di rilis. **[B]**
- A7 (tinggi tetap saat animasi keyboard) tetap tidak dimasukkan; mulai dari A5.
- Tidak ada `debugPrint` dengan isi rahasia, host, atau sidik jari pengguna di log.

## 9. Risiko dan yang belum teruji, per langkah

| Langkah | Risiko atau belum teruji |
|---|---|
| 0 | Pemindahan paket Kotlin dan `applicationId` sering meninggalkan sisa di `.idea` dan `GeneratedPluginRegistrant`; build dari kosong perlu diuji. NDK dan toolchain Gradle pernah bermasalah di spike (`spike-temuan.md` bagian 7). `jni`/`jni_flutter` adalah dependensi turunan `path_provider_android`; belum diuji di HP. Paket platform non-Android ikut terselesaikan; efek ke ukuran APK belum diukur. |
| 1 | `rename` dan `flush` di Android belum diverifikasi; tidak ada `fsync` folder; karantina bisa menyembunyikan kehilangan data bila banner tidak muncul; kompatibilitas `profiles.json` dengan desktop diuji hanya dengan fixture karangan yang meniru satu sampel asli (bukan berkas asli); `KEY` tanpa `privateKeyPath` tidak termuat di desktop; 22 dari 23 profil sampel `AGENT` sehingga alur nyata di HP (tambah kunci atau password) tidak tercakup fixture. |
| 2 | Lisensi font belum diverifikasi; ukuran dan kontras nyata di HP; widget baru semua; font mono untuk karakter lebar dan emoji belum dipilih (K7 menguji dengan font bawaan). |
| 3 | Jalur PIN, pola, dan sandi perangkat belum pernah dijalankan (spike hanya sidik jari); deteksi HP tanpa kunci layar belum diuji; peringatan `none` hanyalah peringatan, jadi pemilik HP tanpa kunci layar bisa menyimpan semua kredensial server; jalur biometrik dibatalkan belum terverifikasi; sidik jari ditambah atau dihapus; kunci Keystore tidak berlaku; zero-out rahasia tidak mungkin di Dart; satu kali nama kunci dihitung dengan format baru (tidak kompatibel dengan nama spike); `getMany` belum ada; pembersihan yatim bergantung pada `vault_index.json` baru dan syarat keselamatan karantina; impor berkas via SAF belum diuji; HP tanpa biometrik belum diuji. |
| 4 | Seluruh UI dan state baru; pengecekan online belum dirancang secara teknis; hapus host dengan kegagalan di tengah hanya diuji lewat injeksi galat di PC. |
| 5 | Penyimpanan sidik jari permanen dan aturan tipe kunci baru; penulisan dalam callback dapat menahan handshake bila disk lambat; K9 dengan jaringan sungguhan (pindah Wi-Fi ke seluler) tidak diuji di spike; server lama tanpa ChaCha20 belum dicoba; kunci PKCS#8, ECDSA P-384 dan P-521 tidak didukung atau belum diuji. |
| 6 | UI baru; perilaku bila host key berubah saat layar terkunci; teks "Host key berubah" perlu dibaca ulang terhadap `README.md` desain ("jelaskan akibat"); pilihan aman sebagai tombol utama. |
| 7 | Animasi keyboard sekitar 30 fps tanpa A7: penyebab tidak diketahui (4.3); Ctrl dan F-key di program nyata; responsivitas tombol saat keluaran deras; akses `RenderTerminal` secara dinamis tidak dipakai di langkah ini (hanya di seleksi dan A7), sehingga tidak ada kerapuhan terhadap versi `xterm` dari langkah ini; warna `htop` dan tampilan `vim`. |
| 8 | Sambung ulang otomatis belum ada di spike; Android menutup soket di latar belakang dengan waktu tak terduga; sesi yatim di server (`ClientAliveInterval`); tombol sambung ulang manual sebagai jalur cadangan. |

## 10. Keputusan dan sisa pertanyaan

### 10.1 Jawaban pemilik (2026-10-15)

| # | Topik | Status | Isi |
|---|---|---|---|
| 2 | Penguncian rahasia | **Diputuskan** | Tiga tingkat: biometrik, kredensial perangkat (PIN, pola, sandi), atau tanpa penguncian dengan peringatan tetapi tetap boleh menyimpan. Enkripsi default tidak bergantung pada biometrik. Rincian di 3.3 dan 3.4. |
| 4 | Contoh `profiles.json` | **Diterima** | Dibaca; temuannya di 3.2. Berkas asli tidak masuk repo. |
| 8 | Impor kunci | **Diputuskan** | Hanya impor berkas lewat `file_selector` 1.1.0, tanpa tempel. |
| 10 | Server uji | **Diizinkan** | Boleh membuat user dan sshd uji sementara di WSL, kredensial acak per sesi, dihapus segera setelah selesai. Dilakukan di langkah 5, bukan sekarang. |
| 11 | Urutan langkah 0 sampai 8 | **Diterima** | Dengan penambahan uji server lama di langkah 5. |

### 10.2 Perlu penjelasan lalu konfirmasi (default yang saya pakai bila tidak ada keberatan)

| # | Topik | Default |
|---|---|---|
| 1 | `privateKeyPath` untuk profil `KEY` | **Syarat dari pemilik:** profil bisa diekspor dan diimpor dua arah antara desktop dan mobile; bagian yang belum lengkap dilengkapi di aplikasi tujuan sesuai kemampuannya. Rahasia tidak pernah ada di berkas, jadi diisi ulang di perangkat tujuan. Berkas internal mobile menulis `privateKeyPath: null` dan mempertahankan semua field desktop. Cara ekspor mobile ke desktop belum dipilih: (a) desktop dilonggarkan agar memuat `KEY` tanpa path sebagai "perlu dilengkapi" (rekomendasi; perubahan di repo desktop, milik pemilik), atau (b) mobile mengisi path penanda saat ekspor. Impor/ekspor di luar irisan pertama; keputusan ini tidak menahannya. |
| 3 | Pelacakan rahasia yatim | Berkas `vault_index.json` berisi nama kunci ber-hash (tanpa rahasia). |
| 5 | Tipe host key berbeda dari yang tersimpan | Algoritma host key dibatasi ke tipe yang tersimpan; selain itu dianggap "host key berubah". |
| 6 | ARB | Dipakai sejak awal, satu bahasa (Indonesia). |
| 7 | State management | `flutter_riverpod` 3.4.3. |
| 9 | `SecretType` ke-5 | `PRIVATE_KEY_PEM` kode 5, khusus mobile. |

### 10.3 Pertanyaan baru

1. **Menguji server Ubuntu 14.04.** 7 dari 23 profil Anda berjalan di 14.04 dan spike tidak pernah mengujinya. Cara yang paling bermakna adalah satu kali login percobaan ke salah satu server 14.04 sungguhan (hanya login dan `exit`, tanpa perubahan apa pun), memakai kredensial yang Anda ketik sendiri di HP. Alternatifnya WSL dengan distro 14.04, yang tidak ada di daftar distro Anda saat ini. Pilih yang mana, atau lewati dan terima risikonya?
2. **Server Ubuntu 24.04 dari spike**: user `spike` di sana belum dibersihkan (tidak ada akses dari sesi ini). Perintah: `sudo pkill -u spike; sudo userdel -r spike`, hapus `spike_sshd_config` bila ada.
3. **Perubahan keputusan tetap.** Usulan kalimat baru untuk `CLAUDE.md` (butir "Rahasia") bila Anda setuju: "Rahasia: kunci privat dan password hanya di Android Keystore dan selalu terenkripsi. Pembacaan dijaga biometrik, atau PIN/pola/sandi perangkat; bila HP tanpa penguncian layar, tampilkan peringatan tetapi tetap izinkan penyimpanan. Jangan menulis rahasia ke berkas, log, atau konsol." Catatan K15 di `spike.md` ("tanpa jatuh ke PIN") tidak lagi berlaku; salinan desain tidak saya ubah lokal, perubahan ini dicatat di dokumen ini dan artifact desain perlu diperbarui.

## 11. Catatan pelaksanaan

### Langkah 0 (selesai, commit `0087831`)

- Terbukti otomatis: `flutter analyze` bersih, `flutter test` lulus, `flutter build apk --debug` berhasil (sekitar 166 detik). Isi APK diperiksa dengan `aapt2`: paket `io.github.egateza.termul`, `minSdk` 24, izin `INTERNET`, `USE_BIOMETRIC`, `allowBackup=false`, aktivitas `MainActivity`.
- **Belum dilakukan:** memasang dan membuka APK di HP. Tidak ada perangkat yang terhubung lewat adb saat dikerjakan. Uji manual: pasang dan buka; layar yang muncul kosong gelap.
- **Temuan di luar rencana:** izin `INTERNET` hanya ada di manifest debug/profile bawaan Flutter, jadi build rilis tidak bisa SSH. Ditambahkan ke manifest utama.
- Jendela awal aplikasi memakai warna token `ground` (`#0F1316`) lewat `values/colors.xml`; `values-night/styles.xml` dihapus karena identik. Tema `LaunchTheme` dan `NormalTheme` berinduk `Theme.AppCompat.DayNight.NoActionBar`; apakah `local_auth` menarik AppCompat sampai tidak crash di Android 8 ke bawah belum diuji (build berhasil).
- `docs/licenses.md` dihasilkan dari `pubspec.lock`: 89 paket hosted, 89 cocok dengan tag pub.dev, 0 copyleft. Skrip pembuatnya ada di luar repo; hasil perlu dibuat ulang bila `pubspec.lock` berubah.
- `lib/l10n/app_localizations*.dart` hasil `flutter gen-l10n` ikut di repo (ARB di `lib/l10n/app_id.arb`).
- Belum diverifikasi: lisensi font IBM Plex Sans dan JetBrains Mono (langkah 2).

### Langkah 1 (selesai di PC; belum diuji di HP)

Isi: `lib/core/io/` (tulis atomik, karantina, kunci async), `lib/core/models/` (`HostProfile`, `ProfileSnapshot`, `OsInfo`, `AuthMethod`, `EnvironmentTag`, `KnownHost`, `evaluateHostKey`), `lib/core/storage/` (antarmuka `HostRepository` dan `KnownHostsRepository`, implementasi JSON). 71 tes, termasuk fixture karangan 23 profil bergaya desktop.

Keputusan kecil yang dibuat saat implementasi:

- Nilai enum asing (`authMethod`, `environment`) dan tipe field yang salah membuat berkas dianggap rusak (dikarantina), sama ketatnya dengan desktop. Konsekuensinya: berkas dari desktop versi mendatang dengan enum baru akan dikarantina seluruhnya.
- Bila berkas rusak **tidak bisa dipindahkan**, memuat melempar `StorageException` dan tidak lanjut, supaya simpan berikutnya tidak menimpa berkas rusak (desktop `StreakStore` hanya mencatat log lalu lanjut).
- `KnownHostsRepository.add` melempar `StateError` bila sudah ada sidik jari bertipe sama yang berbeda; penggantian hanya lewat `replace`, supaya penambahan biasa tidak menggandakan pin yang membuat `evaluateHostKey` menganggap kunci lama masih sah.
- `known_hosts.json` rusak berarti semua host kembali "baru" sampai dipercaya lagi; UI wajib menampilkan `LoadResult.hadCorruptFile`.
- Tes menemukan satu bug nyata: UTF-8 tidak sah muncul sebagai `FileSystemException`, bukan `FormatException`, sehingga berkas tidak dikarantina. Diperbaiki dengan decode sendiri (`utf8.decode`).

Belum teruji (tetap berlaku dari bagian 9): `rename` dan `flush` di Android, folder `path_provider` di HP, ketahanan terhadap mati daya sungguhan, dan alur di HP sungguhan.
