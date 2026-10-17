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

**Risiko kompatibilitas dengan desktop [?]:** `HostProfile` desktop menolak `authMethod: KEY` tanpa `privateKeyPath`. Jika mobile menulis profil `KEY` tanpa path, berkas itu **tidak bisa dimuat desktop sama sekali** (desktop melempar galat untuk seluruh berkas). Selama berkas tidak dibagikan antar perangkat ini tidak berdampak; ia berdampak begitu ada impor/ekspor. Keputusan sementara: mobile menulis `privateKeyPath: null` (keputusan 1, bagian 10); **Terjawab 2026-10-17 (11ad):** ekspor menulis profil `KEY` sebagai `AGENT` tanpa path (keputusan pemilik, opsi A), jadi desktop tetap memuat seluruh berkas dan profil itu dilengkapi dengan kunci di desktop; impor membuang path perangkat asal (11ab). Desktop tidak perlu diubah.

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

Status per 2026-10-16. "Emulator" = Android 14 dengan Keystore dan server SSH sungguhan; "HP" = Xiaomi 25053PC47G, Android 16.

| Langkah | Terbukti di spike | Kode baru | Status |
|---|---|---|---|
| 0 | konfigurasi Android (A12) | pemindahan paket, hapus iOS | selesai |
| 1 | pola atomik dan karantina ada di desktop | seluruh lapisan data | selesai (PC, emulator) |
| 2 | – | seluruh tema dan widget | selesai (PC, emulator) |
| 3 | A11 (Keystore + biometrik) | satu entri per tipe, `getMany`, kunci 5, impor, yatim, HP tanpa biometrik | selesai (PC, emulator); pola di HP berhasil (dilaporkan pengguna); PIN/sandi dan tanpa kunci layar belum |
| 4 | – | seluruh UI dan state | selesai (PC, emulator, HP) |
| 5 | A1, A2, A3 | penyimpanan sidik jari permanen, aturan tipe | selesai (OpenSSH 9.6 dan 7.6, HP: Ubuntu 14.04 dan 18.04) |
| 6 | logika A1 | seluruh UI | selesai (PC, emulator, HP) |
| 7 | A4, A5, A6 | integrasi, test A10 di project baru | selesai (PC, emulator, HP: `htop`, F10, landscape) |
| 8 | pemeriksaan sambungan A4 | sambung ulang otomatis | selesai (PC, emulator); di HP baru banner terlihat, hasilnya belum dikonfirmasi |
| tambahan | – | `settings.json` (ukuran huruf, tinggi baris) | selesai, diuji di HP; menu setting selesai (PC, HP) |
| tambahan (11b) | log logcat HP: soket dihancurkan OS (`Destroyed live tcp sockets`) | foreground service opsional, pengaturan Koneksi | selesai (PC, emulator, HP); di HP sambungan bertahan di latar belakang sekitar 9 menit dengan saklar menyala (lihat "Hasil uji HP" di 11e); layar mati sekitar 25 menit dengan kabel (sesi tetap hidup) dan "Putuskan semua" dari notifikasi teruji 2026-10-17; tanpa kabel dan HyperOS belum diuji |
| tambahan (11c) | K11: bash di bawah 5.1 tanpa tempel aman | tombol Tempel, dialog konfirmasi, karakter kontrol dibuang | selesai (PC); **belum dicoba di HP** |
| tambahan (11d) | K13: gagang dan bilah Salin (hasil di HP sesuai) | gagang berbentuk tetesan, segitiga, atau bulatan (pilihan di Pengaturan) dengan ujung dinamis, kaca pembesar, bilah Salin dan Semua, seleksi berakhir saat mengetik | selesai (PC, HP: gagang, kaca pembesar, tepi layar, mengetik); **belum dicoba di HP:** tempel hasil salin di aplikasi lain, `vim` dan `tmux` |
| tambahan (11e) | log logcat HP: soket dihancurkan OS | "Tetap terhubung di latar belakang", layar Sesi aktif, `SessionController` dan `SessionManager` | selesai (PC, 356 tes, HP); di HP: multi sesi, Tetap terhubung, Putuskan semua, dan putus/pulih saat mode pesawat teruji; layar mati lama belum |

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
| 1 | `privateKeyPath` untuk profil `KEY` | **Syarat dari pemilik:** profil bisa diekspor dan diimpor dua arah antara desktop dan mobile; bagian yang belum lengkap dilengkapi di aplikasi tujuan sesuai kemampuannya. Rahasia tidak pernah ada di berkas, jadi diisi ulang di perangkat tujuan. Berkas internal mobile menulis `privateKeyPath: null` dan mempertahankan semua field desktop. Cara ekspor mobile ke desktop belum dipilih: (a) desktop dilonggarkan agar memuat `KEY` tanpa path sebagai "perlu dilengkapi" (rekomendasi; perubahan di repo desktop, milik pemilik), atau (b) mobile mengisi path penanda saat ekspor. Impor/ekspor di luar irisan pertama; keputusan ini tidak menahannya. **Terjawab 2026-10-17:** impor 11ab, ekspor 11ad (`KEY` menjadi `AGENT` di berkas ekspor; pilihan (a) dan (b) tidak dipakai). |
| 3 | Pelacakan rahasia yatim | Berkas `vault_index.json` berisi nama kunci ber-hash (tanpa rahasia). |
| 5 | Tipe host key berbeda dari yang tersimpan | Algoritma host key dibatasi ke tipe yang tersimpan; selain itu dianggap "host key berubah". |
| 6 | ARB | Dipakai sejak awal, satu bahasa (Indonesia). |
| 7 | State management | `flutter_riverpod` 3.4.3. |
| 9 | `SecretType` ke-5 | `PRIVATE_KEY_PEM` kode 5, khusus mobile. |

### 10.3 Pertanyaan baru

1. **[Terjawab 2026-10-16: login ke Ubuntu 14.04.6 (OpenSSH 6.6) dari HP berhasil dan terminalnya bekerja.]** ~~**Menguji server Ubuntu 14.04.** 7 dari 23 profil Anda berjalan di 14.04 dan spike tidak pernah mengujinya. Cara yang paling bermakna adalah satu kali login percobaan ke salah satu server 14.04 sungguhan (hanya login dan `exit`, tanpa perubahan apa pun), memakai kredensial yang Anda ketik sendiri di HP. Alternatifnya WSL dengan distro 14.04, yang tidak ada di daftar distro Anda saat ini. Pilih yang mana, atau lewati dan terima risikonya?~~
2. **Server Ubuntu 24.04 dari spike**: user `spike` di sana belum dibersihkan (tidak ada akses dari sesi ini). Perintah: `sudo pkill -u spike; sudo userdel -r spike`, hapus `spike_sshd_config` bila ada.
3. **Perubahan keputusan tetap.** Usulan kalimat baru untuk `CLAUDE.md` (butir "Rahasia") bila Anda setuju: "Rahasia: kunci privat dan password hanya di Android Keystore dan selalu terenkripsi. Pembacaan dijaga biometrik, atau PIN/pola/sandi perangkat; bila HP tanpa penguncian layar, tampilkan peringatan tetapi tetap izinkan penyimpanan. Jangan menulis rahasia ke berkas, log, atau konsol." Catatan K15 di `spike.md` ("tanpa jatuh ke PIN") tidak lagi berlaku; salinan desain tidak saya ubah lokal, perubahan ini dicatat di dokumen ini dan artifact desain perlu diperbarui.

## 11. Catatan pelaksanaan

### Langkah 0 (selesai, commit `0087831`)

- Terbukti otomatis: `flutter analyze` bersih, `flutter test` lulus, `flutter build apk --debug` berhasil (sekitar 166 detik). Isi APK diperiksa dengan `aapt2`: paket `io.github.egateza.termul`, `minSdk` 24, izin `INTERNET`, `USE_BIOMETRIC`, `allowBackup=false`, aktivitas `MainActivity`.
- **Dipasang dan dibuka di emulator** (Android 14, x86_64; build `--target-platform android-x64`): proses hidup, tidak ada crash di logcat, layar gelap kosong sesuai harapan. **HP fisik belum.** APK arm64 yang dibangun lebih dulu tidak bisa dipakai di emulator x86_64.
- **Temuan di luar rencana:** izin `INTERNET` hanya ada di manifest debug/profile bawaan Flutter, jadi build rilis tidak bisa SSH. Ditambahkan ke manifest utama.
- Jendela awal aplikasi memakai warna token `ground` (`#0F1316`) lewat `values/colors.xml`; `values-night/styles.xml` dihapus karena identik. Tema `LaunchTheme` dan `NormalTheme` berinduk `Theme.AppCompat.DayNight.NoActionBar`; apakah `local_auth` menarik AppCompat sampai tidak crash di Android 8 ke bawah belum diuji (build berhasil).
- `docs/licenses.md` dihasilkan dari `pubspec.lock`: 89 paket hosted, 89 cocok dengan tag pub.dev, 0 copyleft. Skrip pembuatnya: `tool/gen_licenses.py`; hasil perlu dibuat ulang bila `pubspec.lock` berubah.
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

Uji di Android: `integration_test/storage_test.dart` (7 tes, dependensi dev `integration_test` dari SDK) lulus di **emulator** Android 14 x86_64, memakai folder `path_provider` asli: tulis atomik, timpa, galat sebelum rename, 50 simpanan serentak lalu muat ulang, karantina, kegagalan tulis, dan `known_hosts`. Jalankan dengan `flutter test integration_test -d <perangkat>`.

Belum teruji (tetap berlaku dari bagian 9): semuanya di **HP fisik**; apakah `flush` benar-benar `fsync` di Android; ketahanan terhadap mati daya atau proses dimatikan paksa (tes hanya memeriksa kegagalan yang disuntik, bukan kematian proses); emulator memakai disk virtual, jadi bukan bukti untuk penyimpanan flash HP.

### Langkah 2 (selesai di PC dan emulator)

- Token dihasilkan dari `docs/design/tokens.json` (`lib/core/theme/termul_tokens.g.dart`, skrip pembuat di `tool/gen_tokens.py`), dan `test/core/theme/tokens_test.dart` membandingkan Dart dengan JSON (93 warna, 27 ukuran, 16 gaya teks, kontras utama). Tema memakai konstanta statis, bukan `ThemeExtension` seperti saran `flutter.md`, karena hanya ada tema Gelap.
- Font IBM Plex Sans dan JetBrains Mono (variabel, OFL 1.1) dibundel; lisensi dan sha256 ada di `docs/licenses.md`. Paket tambahan: `path_drawing` 1.0.1 (MIT) untuk menggambar ikon dari data path SVG.
- Widget: `TermulButton`, `TermulIconButton`, `TermulCard`, `FilterChipButton`, `TermulTag`, `TermulTextField`, `TermulBanner`, `showTermulSheet`, `StatusDot`, `HostRow`, `SwitchRow`, `KeyButton`, `showTermulToast`, `TermulIcon`. 37 tes widget (target sentuh, status dengan kata, fokus papan ketik, banner peringatan, dan seterusnya).
- Galeri visual: `lib/debug/widget_gallery.dart`, aktif hanya dengan `--dart-define=TERMUL_GALLERY=true`. Diperiksa di emulator: font dan token tampil sesuai desain.
- **Bukan perbandingan piksel dengan prototipe.** Berkas `.dc.html` tidak bisa dirender (butuh `support.js` yang tidak tersalin); bentuk ikon dan susunan layar `Main` dan `HostKey` diambil dari kodenya. Ikon hapus, ubah, kunci, bintang, muat ulang, dan lainnya dibuat sendiri dengan gaya yang sama dan belum ditinjau.
- Belum dibuat: `NavBar` lima tab (hanya Host dan Sesi yang akan ada di irisan pertama), `Switch` sudah ada tetapi `Segmented`, `Progress`, dan `Flame` belum (streak di luar irisan).

### Langkah 3 (selesai di PC dan emulator)

- Kode: `lib/core/vault/` (`CredentialVault`, `KeystoreCredentialVault`, `DeviceAuth`/`LocalAuthDeviceAuth`, `SecretStore`, `JsonVaultIndex`, `SecretType` dengan kode 5 khusus mobile), `lib/core/keys/private_key_inspector.dart`, dan `lib/features/hosts/host_service.dart` (urutan simpan dan hapus, pembersihan rahasia yatim saat mulai). Aturan penguncian tiga tingkat sudah tertulis di `CLAUDE.md` (butir "Rahasia").
- Tes otomatis: 33 tes vault dan kunci (kunci uji dibuat saat tes berjalan dengan `ssh-keygen`; tidak ada kunci privat di repo) dan 17 tes `HostService`.
- Di emulator Android 14 (`integration_test/vault_test.dart`): Keystore sungguhan (simpan, ada, hapus, pembersihan yatim) lulus; deteksi tingkat memberi `biometric` pada AVD `hp_besar_pin_121212_` (sudah punya sidik jari terdaftar); **prompt biometrik nyata dijawab dengan sidik jari virtual (`adb emu finger touch 1`) dan rahasia terbaca**.
- **Di HP fisik (dilaporkan pengguna, 2026-10-16): membuka rahasia dengan pola layar kunci berhasil.** Rincian belum dicatat: apakah HP punya sidik jari terdaftar saat itu (jalur `biometric` dengan pilihan pola, atau `deviceCredential` murni) dan apakah penyimpanan juga lewat pola.
- **Belum teruji:** jalur PIN dan sandi, dan deteksi HP tanpa kunci layar (`none`). Percobaan di AVD bersih `termul_uji_bersih` terhenti karena memori mesin habis dengan dua emulator berjalan; ulangi dengan satu emulator bersih. Jalur "biometrik dibatalkan", sidik jari ditambah atau dihapus, dan semuanya di HP fisik juga belum.

### Langkah 4 (selesai di PC dan emulator)

- Kode: `lib/bootstrap.dart`, `lib/app_providers.dart` (Riverpod 3), `lib/features/hosts/` (`host_list_screen`, `host_form_screen`, `host_list_model`), `lib/shared/widgets/termul_segmented.dart` dan `termul_action_sheet.dart`, `lib/core/keys/key_file_picker.dart` (`file_selector`), `lib/boot_error_app.dart`. 77 string di `lib/l10n/app_id.arb`.
- Daftar host: grup, pencarian, filter Semua dan Favorit, status "belum diperiksa", banner bila berkas rusak dikarantina, aksi lewat tekan-tahan (Sambung, Ubah, Favorit, Hapus dengan konfirmasi), profil agen dari desktop diarahkan ke form untuk dilengkapi. Form: password atau impor kunci dari berkas, passphrase diverifikasi sebelum simpan, peringatan bila HP tanpa kunci layar.
- Tes: 188 tes otomatis (termasuk 13 tes layar daftar dan 16 tes form dengan repository dan vault di memori). Di emulator: `integration_test/host_flow_test.dart` (tambah host, restart lewat `bootstrap()` ulang, hapus; berkas rusak dikarantina) lulus dengan berkas dan Keystore sungguhan.
- Perbandingan visual: tangkapan layar daftar host dirender dengan font asli dan dibandingkan dengan `Main.dc.html` di prototipe; sangat dekat. Bedanya yang disengaja: tanpa bar navigasi lima tab, tanpa chip streak dan vault, tanpa filter Online (belum ada pengecekan status).
- Bukan bagian rencana awal tetapi dikerjakan: `support.js` prototipe disalin (lihat `SUMBER.md`) supaya prototipe bisa dirender lokal.
- **Belum teruji:** semuanya di HP fisik; impor kunci lewat pemilih berkas Android (`file_selector`) belum dijalankan di perangkat; lama simpan ke Keystore terasa beberapa detik di emulator dan form belum punya indikator kemajuan.

### Langkah 5 (logika selesai dan teruji terhadap server sungguhan; belum dipakai UI)

- Kode: `lib/core/ssh/` (`ssh_connector.dart`, `host_key_policy.dart`, `ssh_failure.dart`, `keepalive_watchdog.dart`). Isi: ChaCha20 didahulukan, `keepAliveInterval: null` dengan pengawas sendiri, verifikasi host key lewat `KnownHostsRepository` (sidik jari baru ditulis permanen **sebelum** login lanjut; gagal tulis membatalkan koneksi), host key berubah memblokir kecuali "ganti dan sambung", pilihan "sambung sekali saja" tidak sah untuk host key berubah, algoritma host key dibatasi ke keluarga tersimpan, tipe `rsa-sha2-*` dan `ssh-rsa` dilipat menjadi satu keluarga `ssh-rsa`, galat dipetakan ke `SshFailure` bertipe (termasuk penolakan host key yang oleh `dartssh2` dilaporkan sebagai `SSHAuthAbortError`).
- Tes: `test/core/ssh/ssh_connector_test.dart` (21 tes) berjalan terhadap server nyata bila `--dart-define=SSH_TEST_CONFIG=<config.json>` diisi, dan dilewati bila tidak. **Lulus terhadap OpenSSH 9.6 (WSL Ubuntu-22.04) dan OpenSSH 7.6 (WSL Ubuntu-18.04)**: login password, kunci ed25519 (dengan dan tanpa passphrase), RSA PEM, ECDSA, passphrase salah, PKCS#8 (dilewati di 7.6), password salah, user tidak ada, host baru, host key berubah, ganti dan sambung, gagal simpan sidik jari, host yang dikenal dibatasi ke tipe tersimpan, port tertutup, `checkAlive`, dan keepalive memakai proxy yang membisu (terdeteksi `keepAliveTimeout`).
- **Belum teruji:** (Ubuntu 14.04 sudah dicoba pengguna di HP dan berhasil, lihat bagian uji HP fisik) jaringan sungguhan (Wi-Fi ke seluler), semuanya di HP fisik, dan `keyboard-interactive` (server tanpa metode password, belum ditangani). Waktu pengguna memutuskan host key dihitung di luar batas waktu aplikasi, tetapi `LoginGraceTime` sshd (bawaan 120 detik) tetap bisa menutup koneksi bila pengguna terlalu lama.

### Langkah 6 (selesai di PC dan emulator, terhadap server SSH sungguhan)

- Kode: `lib/features/connect/` (`connect_flow.dart` mesin keadaan tanpa UI; `host_key_prompt.dart` dua varian sesuai `HostKey.dc.html`; `connect_screen.dart` status menyambung, layar "Rahasia hilang", galat per jenis kegagalan, keterangan sementara setelah tersambung). `sshConnectorProvider` dan `connectFunctionProvider` di `app_providers.dart`; `HostListScreen.onConnect` membuka `ConnectScreen`. `SshConnection.forTest` hanya untuk tes.
- Perilaku: pilihan aman jadi tombol utama pada host key berubah, "Ganti key dan sambung" baru aktif setelah kotak persetujuan dicentang; tombol kembali pada layar host key sama dengan menolak (berujung layar galat "Host key ditolak"); sambungan yang selesai setelah pengguna batal ditutup; layar ditutup saat tersambung = sambungan ditutup (sementara, sampai terminal ada).
- Tes: 18 tes `ConnectFlow` dan 12 tes layar (218 tes otomatis seluruhnya, `flutter analyze` bersih). Di emulator Android 14 dengan Keystore, jaringan, dan OpenSSH 9.6 sungguhan (`integration_test/connect_flow_test.dart`, server dari `--dart-define`, alamat `10.0.2.2:2222`): tambah host lewat form, host key baru tampil dengan sidik jari `SHA256:`, dipercayai dan tersimpan, tersambung, sambung kedua langsung tanpa pertanyaan; password salah memberi "Login ditolak". Prompt sidik jari dijawab dengan `adb emu finger touch 1`.
- **Belum teruji:** semuanya di HP fisik; layar host key berubah dan "Rahasia hilang" hanya lewat tes widget (belum di emulator); tampilan visual layar-layar ini belum dibandingkan dengan prototipe lewat tangkapan layar.

### Langkah 7 (selesai di PC dan emulator, terhadap server SSH sungguhan)

- Kode: `lib/features/terminal/` (`terminal_session.dart` sesi xterm tanpa UI: UTF-8 streaming `allowMalformed`, Ctrl/Alt sekali pakai termasuk dari keyboard sistem, ukuran terdebounce 150 ms dibaca saat timer berbunyi, semua sumber daya ditutup di `dispose`; `shell_channel.dart` antarmuka tipis di atas `SSHSession`; `key_codes.dart` `applyModifiers`; `quick_key_bar.dart` Esc, Tab, Ctrl, Alt, Fn (F1-F12), ^C, ^D, panah, Home, End, PgUp, PgDn, simbol, tidak mengambil fokus; `terminal_screen.dart` header atau mode ringkas di bawah 480 dp, `MediaQuery.removePadding`, konfirmasi sebelum memutus; `terminal_palette.dart`). `ConnectScreen` menampilkan `TerminalScreen` untuk `ConnectDone`. Shell dibuka setelah layout pertama supaya PTY berukuran layar sebenarnya. Tanpa A7 (animasi keyboard), A8 (seleksi), A9.
- Keputusan baru (perlu masuk artifact desain): magenta dan sian ANSI tidak ada di `tokens.json`, nilainya dipilih di `terminal_palette.dart`; tombol kembali dan tombol kembali sistem meminta konfirmasi bila shell masih hidup (shell di server ikut berakhir); Fn ditaruh setelah Alt supaya terjangkau tanpa menggeser baris.
- Tes: 21 tes sesi (urutan tombol, modifier, resize, UTF-8 terpotong, dispose) dan 15 tes layar (potret, landscape dengan dan tanpa keyboard, perubahan keyboard bertahap per 16 ms: `viewHeight` selalu sama dengan `floor(tinggi / lineHeight)`, tombol cepat, konfirmasi keluar); 254 tes seluruhnya. Di emulator terhadap OpenSSH 9.6: `stty size` dari server cocok dengan ukuran layar, `yes | head -n 200000` selesai dan UI tetap menjawab, `echo "é─😀"` utuh, keyboard tidak tertinggal terbuka setelah keluar dari terminal, warna ANSI tampil (tangkapan layar diperiksa).
- `integration_test/connect_flow_test.dart` memakai autentikasi perangkat yang selalu lolos (biometrik sungguhan di emulator ternyata tidak andal untuk tes otomatis; prompt sungguhan tetap diuji di `vault_test.dart`).
- **Belum teruji:** semuanya di HP fisik; `htop`, `vim`, `tmux`, `nano`; Ctrl dan tombol F di program nyata; responsivitas tombol saat keluaran deras; animasi keyboard (belum diukur, sekitar 30 fps di spike); tanpa seleksi dan salin, tanpa tempel; baris terminal memakai tinggi baris 1,5 dari token (bisa terasa lapang, belum ditimbang di HP).

### Langkah 8 (selesai di PC dan emulator, terhadap server SSH sungguhan)

- Kode: `ConnectScreen` memiliki `TerminalSession` dan sambungan aktif (bukan lagi `TerminalScreen`), sehingga riwayat layar bertahan selama sambung ulang walau layar host key atau "Rahasia hilang" tampil di tengahnya. Putus dideteksi dari `connection.closed` (alasan selain `userClosed`); saat aplikasi terlihat langsung disambung ulang lewat `ConnectFlow` yang sama (rahasia dibuka dari vault, host key diperiksa lagi; host key berubah tetap memblokir dan butuh keputusan). Saat di latar belakang tidak menyambung dan tidak memunculkan prompt biometrik; begitu kembali terlihat, `checkAlive` (batas 5 detik) memeriksa sambungan yang mungkin dimatikan Android, lalu menyambung ulang bila mati. `TerminalSession.restart` menutup shell lama, membersihkan mode terminal yang tertinggal (layar alternatif, kursor, tetikus, bracketed paste), menulis pemisah "— tersambung ulang —", dan membuka shell baru dengan ukuran layar. `TerminalScreen` menampilkan banner dengan kata (Koneksi terputus + "Sambung sekarang", Menyambung ulang…, Gagal menyambung ulang + alasan) dan status header (Terputus, Menyambung ulang…). `SshShellChannel.resize` menelan `SSHStateError` dari permintaan ubah ukuran yang tak sempat dibalas saat sambungan ditutup (ditemukan oleh uji emulator sebagai galat tak tertangani setelah tes selesai).
- Keputusan baru (perlu masuk artifact desain): sambung ulang otomatis satu kali saat putus (tanpa percobaan berulang); setelah gagal, menunggu tombol "Sambung sekarang". Sambung ulang membuka vault lagi sehingga prompt biometrik muncul lagi (aplikasi tidak menyimpan rahasia di memori antar sambungan).
- Tes: 8 tes sambung ulang di PC (putus lalu otomatis, gagal lalu manual, host key berubah saat sambung ulang, putus di latar belakang, soket mati diam-diam terdeteksi lewat `checkAlive`, menutup layar saat menyambung ulang, keluar) dan 3 tes `restart` pada sesi; 269 tes seluruhnya. Di emulator terhadap OpenSSH 9.6: `kill -9 $PPID` di shell memutus sambungan dari sisi server; aplikasi menyambung ulang sendiri, riwayat layar tetap, pemisah tampil, dan `echo` di shell baru berfungsi.
- **Belum teruji:** semuanya di HP fisik; Home 13 detik dan 5 menit; mematikan Wi-Fi; perpindahan Wi-Fi ke seluler; soket yang dimatikan Android sungguhan (di emulator hanya diputus dari server); sambung ulang saat biometrik dibatalkan di perangkat; tombol Sambung sekarang di perangkat. Sambung ulang otomatis hanya sekali: belum ada percobaan berulang dengan jeda.

### Uji di HP fisik (dilaporkan pengguna, 2026-10-16)

- Perangkat: Xiaomi 25053PC47G, Android 16 (API 36), arm64, build debug lewat `flutter run`.
- Berhasil: aplikasi terpasang dan berjalan; tambah host dan sambung ke server Ubuntu 14.04.6 (OpenSSH 6.6, **menutup pertanyaan tentang server lama**) dan Ubuntu 18.04; terminal tampil dengan keyboard terbuka dan tertutup, tombol cepat tampil; banner "Menyambung ulang" dengan riwayat layar tetap terlihat muncul pada pemakaian nyata. `htop` di Ubuntu 18.04 (24 inti, 46 kolom di potret) tampil benar: warna meter, baris terpilih, bilah F1 sampai F7; bilah fungsi terpotong di F8 ke kanan karena lebar layar, F10 lewat tombol Fn dicoba pengguna di `htop` dan berhasil (urutan tombol F sampai ke program nyata). Landscape tanpa keyboard dicoba pengguna dengan `htop`: mode ringkas (satu baris status, tombol kembali 32 dp, baris F1 sampai F12 36 dp), `htop` menggambar ulang selebar layar (bilah F1 sampai F10 penuh), tetapi hanya sekitar 12 baris muat sehingga daftar proses tidak terlihat; tinggi baris token `terminal` (1,5) ikut menentukan ini (catatan keputusan: turunkan ke sekitar 1,3 atau jadikan pengaturan?).
- Kejadian di jalan: sekali aplikasi hanya menampilkan layar hitam saat peluncuran pertama dari VSCode (bersama galat alat "log reader stopped unexpectedly"); tidak bisa direproduksi pada start dingin berikutnya (1,7 detik). Dugaan: `main()` menunggu `bootstrap()` sebelum menggambar apa pun. Belum ada perubahan; layar pemuatan awal bisa ditambahkan bila terulang.
- **Belum dikonfirmasi:** apakah sambung ulang yang terlihat di tangkapan layar berhasil dan apa pemicunya; biometrik sidik jari di HP (pola sudah berhasil); impor kunci lewat pemilih berkas (pengguna belum punya host berkunci untuk dicoba); `vim`, `tmux`, Ctrl dan F di program itu; Home 13 detik dan 5 menit; Wi-Fi ke seluler.

## 11a. Pengaturan (`settings.json`) dan menu setting

**Sudah ada (2026-10-16):** berkas `settings.json` di folder pribadi aplikasi (`getApplicationSupportDirectory`; di Android `/data/user/0/io.github.egateza.termul/files/settings.json`). Dibuat otomatis dengan nilai bawaan saat pertama kali aplikasi dijalankan; properti yang tidak dikenal diabaikan; nilai di luar batas dijepit; tipe yang salah membuat berkas disisihkan ke `settings.json.corrupt-<waktu>` lalu nilai bawaan dipakai (tanpa banner, pengaturan hilang tidak berbahaya). Berkas dibaca ulang **setiap sesi baru dibuka** (mengetuk host), jadi perubahan terpakai tanpa menutup aplikasi; sambung ulang di sesi yang sama tidak membacanya lagi. Kode: `lib/core/models/app_settings.dart`, `lib/core/storage/json/json_settings_repository.dart`, `appSettingsProvider`, `terminalStyleFor` di `terminal_palette.dart`.

```json
{
  "version": 1,
  "terminal": { "fontSize": 13.0, "lineHeight": 1.3 }
}
```

| Kunci | Bawaan | Batas | Arti |
|---|---|---|---|
| `terminal.fontSize` | 13.0 | 8 sampai 24 | ukuran huruf terminal (sp) |
| `terminal.lineHeight` | 1.3 | 1.0 sampai 2.0 | tinggi baris terminal (kelipatan ukuran huruf) |

Cara mengubah di HP selama pengembangan (hanya build debug): `adb shell run-as io.github.egateza.termul` lalu sunting `files/settings.json` (mis. `cat > files/settings.json`), kemudian keluar dari sesi dan ketuk host lagi. Di build rilis berkas ini tidak terjangkau tanpa menu setting, jadi menu itu perlu dibuat sebelum rilis.

**Bawaan tinggi baris 1,3, bukan 1,5 dari token `terminal`:** di HP fisik (Xiaomi 25053PC47G) 1,5 hanya memuat sekitar 12 baris di landscape sehingga daftar proses `htop` tidak terlihat. Keputusan baru, perlu masuk ke artifact desain (baris terminal lebih rapat daripada teks antarmuka).

**Menu setting (selesai di PC dan dicoba di HP fisik, 2026-10-16):**
- Kode: `lib/features/settings/settings_screen.dart` (layar), `lib/shared/widgets/termul_stepper.dart` (komponen `Stepper` baru, ikon `minus` baru), `JsonSettingsRepository.save` (tulis atomik), dan `appSettingsProvider` yang sekarang `NotifierProvider` (`update` menyimpan, `replace` hanya memakai nilai tanpa menyimpan). `ConnectScreen` memantau provider itu, jadi perubahan langsung mengubah huruf dan tinggi baris sesi terminal yang terbuka; ukuran PTY ikut berubah lewat debounce 150 ms yang sudah ada. Pembacaan ulang berkas tiap sesi baru dipertahankan (hasilnya dimasukkan lewat `replace`).
- Jalan masuk: ikon pengaturan di header layar Host, di samping tombol tambah. Keputusan sementara karena `NavBar` lima tab belum dibangun; saat `NavBar` ada, ikon ini pindah ke tab Pengaturan.
- Isi layar: pratinjau dua baris dengan gaya terminal sungguhan, `Stepper` ukuran font (8 sampai 24 px, langkah 1) dan tinggi baris (1,0 sampai 2,0, langkah 0,1), keterangan, tombol "Kembalikan bawaan" (nonaktif bila sudah bawaan). Bukan slider seperti usulan awal: `Stepper` mengikuti prototipe `Settings` yang sudah ada dan target sentuhnya 44 px. Tombol di batas rentang nonaktif. Perubahan tersimpan tiap ketukan; bila gagal menulis, banner "Pengaturan tidak tersimpan" tampil dan nilai tetap berlaku sampai aplikasi ditutup.
- Rentang ukuran font diperlebar dari prototipe (10 sampai 20) ke 8 sampai 24 sesuai batas di `AppSettings`, dan prototipe disesuaikan.
- Tes: 8 tes layar (`test/features/settings_screen_test.dart`: nilai bawaan, langkah font dan baris, tanpa sisa desimal, batas rentang, kembalikan bawaan, gagal simpan, target 44 px), 2 tes `save`, 1 tes perubahan langsung pada sesi terbuka (`reconnect_test.dart`); 294 tes seluruhnya lulus, `flutter analyze` bersih.
- **Di HP fisik (dilaporkan pengguna, 2026-10-16, build debug):** pengguna menyatakan menu setting "aman" setelah dicoba. Rincian yang diperiksa tidak dirinci pengguna (tampilan, ubah ukuran saat sesi hidup, simpan setelah tutup paksa).
- **Belum teruji / belum dikonfirmasi rinci:** `stty size` setelah mengubah ukuran saat sesi hidup, `htop` atau `vim` menggambar ulang setelah perubahan ukuran, dan penyimpanan `settings.json` di build rilis.
- **Sinkron dengan desain:** salinan lokal `docs/design/` sudah diperbarui (komponen `Stepper`, catatan implementasi di `README.md` dan `flutter.md`, prototipe `Settings.dc.html`), dan **sudah di-publish ke kedua artifact claude.ai** (design system v20, prototipe v33). Lihat `docs/design/SUMBER.md`, bagian "Perubahan lokal".

**Sisa daftar (belum dikerjakan):**
- Kandidat pengaturan lain dari pembahasan: tema terminal (gelap, kontras tinggi, terang; token `term-contrast-*` dan `term-light-*` sudah ada; prototipe `Settings` sudah memuat baris Tema), baris tombol cepat dua baris di layar luas, sambung ulang otomatis (nyala atau mati, jumlah percobaan dan jeda), konfirmasi sebelum memutus, foreground service (opt-in, `android.md`), pemeriksaan status host (online atau offline).
- Pengaturan lain ditambahkan ke berkas yang sama (`version` dinaikkan bila bentuknya berubah) dan ke layar yang sama.
- Dasar keputusan: tanpa cubit-untuk-zoom di terminal (keputusan pengguna: tersentuh tanpa sengaja akan mengganggu); pembanding JuiceSSH menampilkan banyak baris karena huruf kecil dan baris rapat, jadi rentang ukuran dibuat lebar.

## 11b. Foreground service "Pertahankan koneksi di latar belakang" (2026-10-16)

**Latar belakang (bukti dari HP pengguna):** setelah Home, sistem Android menghancurkan soket TCP aplikasi sekitar 6 detik kemudian (`InetDiagMessage: Destroyed live tcp sockets for uids={10493}`), padahal proses aplikasi tetap hidup. Aplikasi lalu menyambung ulang saat dibuka dan shell yang berjalan hilang. Ini bukan bug aplikasi dan bukan HyperOS mematikan proses; tmux di server tidak mencegah sambungan putus (hanya menjaga program di server). Hasil uji WSL dan emulator tidak bertentangan: keduanya tidak meniru pembekuan latar belakang.

- **Kode:** `android/.../KeepAliveService.kt` (service Kotlin, tipe `specialUse`) dan `MainActivity.kt` (MethodChannel, izin notifikasi, buka pengaturan aplikasi); `lib/core/platform/keepalive_platform.dart` (antarmuka, implementasi channel, `NoopKeepAlive` untuk tes); `lib/features/connect/keepalive_sync.dart` (daftar sesi aktif dan `keepAliveSyncProvider`); `ConnectScreen` mendaftarkan sesi selama tersambung dan mencabutnya saat putus; `ConnectionSettings.keepAlive` di `settings.json`; bagian Koneksi di layar Pengaturan; `lib/core/ssh/connection_log.dart` (log diagnosis build debug tanpa data sensitif).
- **Diverifikasi di dokumentasi resmi Android (2026-10-16):** tipe `specialUse` dan izin `FOREGROUND_SERVICE_SPECIAL_USE` (selain `FOREGROUND_SERVICE`), properti `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`, `startForeground(id, notification, type)`, Play Console meninjau penggunaan `specialUse` saat pengiriman. Tidak ada dependensi baru (Kotlin sendiri dan API framework).
- **Perilaku:** default mati; menyalakan meminta izin notifikasi (ditolak: saklar tetap mati dengan pesan); service hanya nyala selama ada sesi tersambung; notifikasi "N sesi tersambung" dengan aksi "Putuskan semua"; tidak ada janji "sesi tidak akan putus".
- **Tes:** 309 tes otomatis lulus (provider sinkronisasi 7, layar Pengaturan bagian Koneksi 5, siklus sesi dan "Putuskan semua" 3). Emulator Android 14 (AVD `termul_uji_bersih`): service jadi foreground bertipe `specialUse`, notifikasi dan aksi benar, aksi Putuskan semua menghentikan service tanpa galat. Dicek lewat `adb shell run-as ... am start-foreground-service --user 0`, bukan lewat UI.
- **Belum teruji (butuh HP):** efek sebenarnya di HyperOS (apakah baris `Destroyed live tcp sockets ... uids={10493}` masih muncul dengan saklar menyala), tes 5 dan 30 menit dengan layar mati di Wi-Fi tanpa kabel, baterai, notifikasi yang diblokir setelah service berjalan, aksi Putuskan semua dari notifikasi di perangkat nyata, alur izin notifikasi di HP (Android 16).
- **Keputusan pemilik (2026-10-16): auto-attach tmux per host tidak dibuat.** Di luar kebiasaan klien SSH pada umumnya; yang dipakai adalah foreground service. Pengguna tetap bisa menjalankan `tmux` sendiri di server.
- **Sinkron desain:** `docs/design/android.md` diperbarui (bagian Implementasi).

## 11c. Tempel di terminal (2026-10-16)

- **Kode:** `lib/features/terminal/paste_analysis.dart` (pemeriksaan teks tanpa UI), `TerminalSession.paste`, tombol Tempel di `QuickKeyBar` (setelah Fn; hanya saat sambungan hidup), `_paste` dan `_PasteDetails` di `terminal_screen.dart`, `showTermulSheet(cancelIsPrimary: ...)` untuk menjadikan pilihan aman tombol utama, string `paste*` dan `keyPaste*` di ARB. Membaca papan klip lewat `Clipboard.getData` (tanpa dependensi baru).
- **Aturan:** papan klip kosong: toast. Satu baris tanpa tanda bahaya: langsung ke prompt (toast "Ditempel · 1 baris · belum dijalankan"). Selain itu dialog dengan isi, kata "berisiko" pada baris yang cocok pola desain (`rm -rf`, `dd if=`, `mkfs`, `shutdown`, `reboot`, `chmod -R`, `chown -R`, `truncate`, `drop table/database`), dan akibatnya. Baris baru dikirim sebagai CR (seperti Enter). Bungkus tempel aman dipakai hanya bila server menyalakannya (xterm).
- **Dari temuan spike K11 (bash di bawah 5.1 tanpa bracketed paste menjalankan tiap baris begitu ditempel):** bila `terminal.bracketedPasteMode` mati dan teks berbaris-baris, dialog memberi peringatan "Server ini belum mendukung tempel aman…" sebagai ganti kalimat "belum dijalankan" milik prototipe, pilihan aman jadi tombol utama, dan toast tidak berjanji "belum dijalankan".
- **Tambahan di luar prototipe:** karakter kontrol (ESC, BEL, dan sejenisnya; bukan tab atau baris baru) dibuang dan dilaporkan (mencegah teks yang menyuntik urutan terminal, mis. penutup tempel aman); batas 100.000 karakter; dialog menampilkan paling banyak 50 baris.
- **Belum dibuat:** popover Tempel di kursor prompt (`TerminalPasteMenu`) dan snippet (`Snippets`); keduanya di luar irisan ini.
- **Tes:** 18 tes baru (`test/features/terminal/paste_test.dart`: analisis teks dan alur di layar terminal dengan papan klip palsu, termasuk bungkus tempel aman `\x1b[200~...\x1b[201~`); 327 tes seluruhnya lulus, `flutter analyze` bersih.
- **Belum teruji (butuh HP):** baca papan klip di Android 16 (izin dan toast sistem), tempel di `bash` 5.x (tempel aman) dan 4.4 (Ubuntu 18.04) dan 4.3 (14.04), di `vim` (mode insert dan normal) dan `tmux`, tempelan beberapa ratus baris, keyboard yang tetap terbuka setelah dialog tertutup, ukuran dialog di potret dan landscape ringkas.
- **Sinkron desain:** `README.md` salinan lokal diperbarui; prototipe tidak diubah (lihat `docs/design/SUMBER.md`).

## 11d. Seleksi dan salin teks (2026-10-16)

- **Kode:** `lib/features/terminal/selection_overlay.dart` (`SelectionHandles`: dua gagang yang bisa diseret, perhitungan dari lampiran A8 spike-temuan.md), `selection_bar.dart` (`SelectionBar`: jumlah karakter, Batal, Salin, Semua; menggantikan tombol cepat selama ada seleksi), `_copySelection` dan `_selectAll` di `terminal_screen.dart`, ikon `copy` dan `selectAll`, string `selection*` di ARB. Tekan lama memilih satu kata (bawaan xterm); gagang memperluas atau menyempitkan. Salin mengisi papan klip, menghapus seleksi, toast "Disalin · N karakter".
- **Warna seleksi sementara (perbaikan setelah dicoba di HP):** xterm 4.0.0 menggambar seleksi di atas teks, jadi `terminal-selection` yang pekat menutupi huruf. Dipakai biru lebih terang (`#3E7CA8`) dengan alpha 55% (`terminalSelectionOverlay` di `terminal_palette.dart`). Keputusan baru: perlu masuk ke desain (token `terminal-selection` dan `terminal-selection-ink` tidak berlaku untuk terminal sungguhan). Belum dicek ulang di HP.
- **Gagang dan kaca pembesar (perbaikan setelah dicoba di HP):** (1) gagang yang jatuh di bawah layar ikut terpotong; sekarang dijepit ke dalam area terminal. (2) Gagang di kolom pertama atau terakhir jatuh di zona gestur kembali Android; sekarang pusatnya minimal 36 dp dari tepi kiri dan kanan, dan seretan memakai selisih jari dari titik seleksi saat gagang diraih, jadi kolom pertama dan terakhir tetap terjangkau. (3) Kaca pembesar (`RawMagnifier`, perbesaran 1,6x) muncul di atas jari selama menyeret, di bawah gagang bila tidak muat di atas. Belum dicek ulang di HP; gulir otomatis ke tepi layar tetap belum ada.
- **Kaca pembesar di tepi (perbaikan kedua):** `RawMagnifier` hanya bisa mengambil isi yang ada di layar, jadi di tepi kiri, kanan, atas, dan bawah isinya bergeser dan salah. Wilayah yang diambil sekarang digeser ke dalam layar (seperti kaca pembesar Android), dan titik yang sebenarnya ditunjuk ditandai garis aksen di dalam lensa. Belum dicek ulang di HP.
- **Aturan desain (2026-10-16):** desain diikuti, tidak diubah agar cocok dengan kode. Gagang seleksi: awalnya `info` bertangkai seperti prototipe, lalu diganti atas pilihan pemilik menjadi tetesan air `accent` bertepi `ground` (bulatan 16 dp, ujung runcing ke teks, `_DropPainter`); prototipe tidak diubah, perbedaan dicatat di README design system. Belum bisa sesuai desain (dicatat di README design system, desain tidak diubah): warna seleksi (`terminal-selection` pekat menutupi huruf karena xterm 4.0.0 menggambar seleksi di atas teks; sementara `#3E7CA8` alpha 55%) dan petunjuk bilah "Ketuk kata lain untuk memperluas pilihan" (xterm menghapus seleksi saat diketuk; sementara "Seret gagang untuk mengubah pilihan"). **Ditutup (keputusan pemilik, 2026-10-16): warna sementara diterima, penggambar xterm tidak ditambal.** Catatan README design system tentang warna seleksi tetap sebagai penyimpangan yang diterima; sesuaikan kalimatnya ("diterima pemilik") saat artifact berikutnya dipublikasikan. Petunjuk bilah seleksi tetap berlaku seperti semula.
- **Seleksi berakhir saat mengetik (perbaikan setelah dicoba di HP):** sebelumnya seleksi tetap ada walau Enter ditekan atau perintah diketik. Sekarang setiap masukan ke server (papan ketik, tombol cepat, tempel; lewat `TerminalSession.onInput`) menghapus seleksi, seperti terminal pada umumnya. Jawaban otomatis terminal atas pertanyaan program (mis. atribut perangkat) juga lewat jalur itu dan bisa menghapus seleksi; jarang terjadi. Desain tidak menyebut perilaku ini, jadi tidak ada perubahan artifact.
- **Ujung gagang dinamis (permintaan pemilik):** badan gagang dijauhkan dari tepi kiri dan kanan (36 dp), tetapi ujung tetesan dan segitiga miring ke titik seleksi yang sebenarnya (gagang berputar utuh pada jarak ujung tetap supaya bentuknya tidak memanjang atau menggepeng; sudut paling miring 45 derajat; `_HandlePainter._tipFor`. Versi pertama memanjangkan ujung sampai ke titik seleksi dan hasilnya tidak proporsional saat miring); di baris paling bawah gagang dibalik (ujung ke sisi atas sel) alih-alih naik menutupi teks. Bulatan tidak punya ujung. Tes: arah miring di kolom pertama dan terakhir, tidak miring di tengah, balik hanya di baris paling bawah. Belum dicoba di HP.
- **Pilihan bentuk gagang (permintaan pemilik, tambahan di luar desain):** `SelectionHandleStyle` (`drop` bawaan, `triangle`, `dot`) di `TerminalSettings.handleStyle` (`settings.json`: `"handleStyle": "drop"`; nama asing kembali ke bawaan), `Segmented` di Pengaturan, bagian Terminal, dengan pratinjau bentuk (`SelectionHandleShape`), dan `TerminalScreen.handleStyle`. Segitiga = bulatan 14 dp dengan segitiga terpisah di atasnya, alas segitiga melengkung sepusat dengan bulatan. Tes: model (baca, tulis, nama asing, tipe salah) dan layar Pengaturan. Prototipe `Settings` dan README design system diperbarui. Belum dicoba di HP.
- **Semua:** memilih sampai baris terakhir yang berisi teks (baris kosong di bawahnya tidak ikut).
- **Landscape ringkas:** bilah satu baris tanpa petunjuk.
- **Belum dibuat (ada di prototipe `Terminal.dc.html`):** Cari, Kirim ke host lain, Simpan sebagai snippet, Bagikan, Salin sebagai satu baris, gulir otomatis saat gagang diseret ke tepi layar (juga belum di spike).
- **Tes:** 8 tes baru (`test/features/terminal/selection_test.dart`): bilah dan gagang muncul, Salin, Semua, Batal, seret kedua gagang, tekan lama, landscape. 335 tes seluruhnya lulus, `flutter analyze` bersih.
- **Sudah dicoba di HP (dilaporkan pemilik, 2026-10-16):** tekan lama dan seret gagang, gagang di tepi kiri dan kanan dan baris paling bawah, kaca pembesar (termasuk di tepi), bentuk gagang, ujung yang miring, dan seleksi berakhir saat mengetik atau menekan Enter, semuanya dinyatakan sesuai.
- **Belum teruji di HP:** tempel hasil salin di aplikasi lain, seleksi di `vim` dan `tmux` (mouse mode bisa mengambil alih sentuhan), seleksi lintas baris di scrollback yang panjang (gulir otomatis belum ada)
- **Sinkron desain:** bilah berbeda dari prototipe (tanpa Cari, Kirim, Snippet, Bagikan; ditambah gagang dari spike). Catatan sudah di-publish ke design system versi 23 (prototipe `Terminal` belum diubah).

## 11e. Sesi di latar belakang: "Tetap terhubung" dan Sesi aktif (2026-10-16)

- **Latar belakang:** sebelumnya keluar dari terminal selalu menutup sambungan, jadi tmux seolah satu-satunya cara menjaga sesi. Sekarang menekan kembali di terminal membuka sheet "Keluar dari terminal?" dengan Tetap terhubung di latar belakang (utama), Putuskan, dan Batal; ada catatan dan tombol "Buka Pengaturan" bila pengaturan foreground service mati (tanpa itu Android tetap bisa memutus soket; lihat 11b).
- **Arsitektur:** kepemilikan sambungan pindah dari `ConnectScreen` ke `SessionController` (`session_controller.dart`: alur sambung, sambungan, `TerminalSession`, pengawas putus, sambung ulang, pendaftaran ke daftar sesi aktif untuk notifikasi) yang dikelola `SessionManager` (`session_manager.dart`, provider `sessionManagerProvider`: daftar sesi yang dibiarkan hidup). Layar hanya menampilkan sesi; ditutup biasa = sesi dilepas (seperti sebelumnya), lewat "Tetap terhubung" = sesi tinggal di manajer.
- **Sesi aktif:** `lib/features/sessions/sessions_screen.dart`, dibuka dari ikon terminal bertanda jumlah di header daftar host (sementara `NavBar` belum ada; keputusan pemilik: lewat menu, bukan mengetuk host, karena bisa ada lebih dari satu sesi ke profil yang sama). Satu kartu per sesi (nama, nomor sesi bila lebih dari satu ke profil yang sama, `user@host:port`, jam mulai, status dengan kata), ketuk membuka lagi terminal yang sama dengan riwayat utuh, tombol Putuskan per sesi dan Putuskan semua (dengan konfirmasi). "Putuskan semua" di notifikasi foreground service juga menutup sesi di latar belakang.
- **Sesi putus di latar belakang:** tidak disambung ulang otomatis (alur sambung bisa memunculkan prompt biometrik saat pengguna sedang di layar lain); ditandai Terputus dan disambung ulang saat dibuka lagi.
- **Dua pelajaran saat membangun:** (1) perubahan state provider saat widget dibongkar ditolak Riverpod padahal nilainya sudah tersimpan, jadi pendengar tidak diberi tahu; diulang di microtask dengan salinan daftar. (2) Sambung ulang saat layar dibuka tidak boleh memberi tahu pendengar di tengah penyusunan widget; dijalankan setelah frame pertama.
- **Tes:** `test/features/sessions_test.dart` (10 tes: tiga pilihan dan catatan, catatan hilang bila pengaturan menyala, Tetap terhubung dan buka lagi dengan riwayat utuh tanpa sambungan baru, Putuskan menutup sesi, keadaan kosong, Putuskan dari daftar, dua sesi ke profil yang sama dengan sambungan dan riwayat sendiri, Putuskan semua, putus di latar belakang tanpa sambung ulang otomatis lalu sambung ulang saat dibuka, "Putuskan semua" notifikasi). 356 tes seluruhnya lulus, `flutter analyze` bersih.
- **Belum teruji (butuh HP):** sesi benar-benar bertahan di latar belakang (dengan dan tanpa foreground service menyala), beberapa sesi sekaligus, buka lagi setelah Android membekukan proses, notifikasi dengan banyak sesi, keyboard dan ukuran terminal saat sesi dibuka lagi.
- **Belum dibuat:** `NavBar` lima tab dengan tab Sesi, beberapa sesi dalam satu layar terminal (tab di prototipe `Terminal`).
- **Sinkron desain:** prototipe `Sessions` (12) dan `TerminalLeave` (2j) dan README design system diperbarui sebagai tambahan; ketidaksesuaian dengan `NavBar` dicatat di README.

### Hasil uji HP: foreground service dan sesi di latar belakang (2026-10-16)

Perangkat Xiaomi 25053PC47G, Android 16, build debug lewat `flutter run`, kabel USB terpasang, server OpenSSH di LAN. Sumber: `adb logcat`, `dumpsys`, `/proc/net/tcp` di HP, dan `who`/`ss` yang ditempel pengguna dari server. Sisi server hanya diketahui dari keluaran yang ditempel pengguna.

- **Foreground service menahan sambungan [T].** Sebelum saklar menyala, `Destroyed live tcp sockets for uids={10493}` muncul tiga kali (14:26, 14:42, 14:42). Setelah service menyala (14:43:14) tidak muncul lagi. Empat sesi di latar belakang 531 detik: `checkAlive` melaporkan hidup untuk keempatnya, empat soket `ESTABLISHED` ke port 22, shell di server utuh. Notifikasi dan service tipe `specialUse` benar (`dumpsys`).
- **Multi sesi ke profil yang sama [T]:** 4 sesi (jumlah di service 1 sampai 4, 4 shell di server) dan 2 sesi. Belum dikonfirmasi rinci: nomor sesi di kartu dan riwayat layar per sesi.
- **Putuskan semua [T]:** service mati, notifikasi hilang, soket ke port 22 nol, dan sesi hilang dari server sekitar 8 detik kemudian (diamati dua kali). Satu shell (pts/7) tetap tinggal di server setelah "Putuskan semua" pada 14:58:51, tidak lama setelah jaringan pulih dari mode pesawat; penyebab belum terbukti (dugaan: paket penutupan jatuh saat jaringan belum stabil). Uji terkendali dengan Wi-Fi stabil tidak mengulanginya.
- **Mode pesawat (dua kali) [T]:** putus terdeteksi sekitar 2 detik dengan alasan `error`, service mati saat tidak ada sesi tersambung, sesi pulih setelah jaringan kembali dan aplikasi terlihat. **Sambung ulang membuka shell baru, shell lama menjadi yatim di server** (5 yatim dari putaran pertama bertahan sampai `pkill`, 13 sampai 27 menit). Tidak bisa dicegah dari aplikasi; penangkalnya `ClientAliveInterval` di server.
- **Kunci layar [T, singkat]:** 86 detik di latar belakang, sambungan hidup. Uji terpanjang sekitar 9 menit.
- **Belum dikonfirmasi:** selama mode pesawat log memperlihatkan `inactive`/`resumed` bergantian tiap sekitar 2 detik, diduga prompt biometrik berulang tiap percobaan sambung ulang (belum dikonfirmasi pengguna). Sambung ulang tidak menunggu jaringan kembali.
- **Belum teruji:** layar mati 30 menit atau lebih; tanpa kabel (`adb tcpip`); pembanding saklar mati yang tercatat di log; efek penghemat baterai HyperOS; aksi "Putuskan semua" dari notifikasi; tempel (11c); `NavBar`.
- **Kandidat perbaikan:** sambung ulang menunggu jaringan kembali (tidak mencoba berulang saat mode pesawat), satu prompt biometrik untuk semua sesi yang perlu sambung ulang.

### Pengujian tertunda di HP (dicatat 2026-10-16, menunggu pengguna)

Build debug dengan fitur ini belum dipasang di HP Xiaomi 25053PC47G (HP sedang dicabut). Urutan uji saat HP tersedia:

1. Pasang build baru (`flutter run -d <HP>`) dan mulai rekam log: `adb logcat -c` lalu simpan `adb logcat -v time` ke berkas.
2. Pengaturan, Koneksi: nyalakan saklar, izinkan notifikasi. Periksa status "Diizinkan" dan tombol "Buka pengaturan".
3. Sambung ke host, tekan Home, tunggu 30 detik, 5 menit, lalu buka lagi. Catat apakah sesi (`echo $$`) sama.
4. Di log: apakah `Destroyed live tcp sockets for uids={<uid TermUL>}` masih muncul dengan saklar menyala, dan baris `[termul]` (alasan putus, lama di latar belakang).
5. Ketuk "Putuskan semua" di notifikasi saat aplikasi di latar belakang: sambungan tertutup, layar sesi tertutup, tidak menyambung ulang.
6. Bila sambungan tetap putus: atur penghemat baterai TermUL ke "Tanpa batasan" dan aktifkan Mulai otomatis (HyperOS), ulangi 3 dan 4.
7. Catat hasil di sini, dan di `docs/design/android.md` (bagian Implementasi, "Belum teruji").

Uji sesi di latar belakang (11e) di HP:

1. Nyalakan "Pertahankan koneksi di latar belakang", sambung ke host, tekan kembali, pilih "Tetap terhubung di latar belakang". Ikon sesi di header daftar host menunjukkan 1.
2. Tekan Home, tunggu 30 detik dan 5 menit, buka aplikasi lalu Sesi aktif: status Tersambung dan riwayat layar utuh; `echo $$` sama dengan sebelumnya.
3. Ulangi dengan pengaturan mati: catat apakah Android memutus sambungan (status Terputus) dan apakah dibuka lagi menyambung ulang.
4. Buka dua sesi ke profil yang sama (sesi 2 muncul), lanjutkan masing-masing, dan Putuskan satu lalu Putuskan semua.
5. "Putuskan semua" di notifikasi dengan sesi di latar belakang: semua sesi tertutup, daftar kosong.

Uji seleksi dan salin (11d) di HP, kunjungan yang sama:

1. Tekan lama sebuah kata: bilah "N karakter dipilih" muncul, dua gagang tampil di bawah awal dan akhir kata.
2. Seret kedua gagang, juga lintas baris dan ke scrollback; ketuk Salin, tempel di aplikasi lain, cocokkan isinya.
3. Ketuk Semua lalu Salin; Batal mengembalikan tombol cepat.
4. Ulangi dengan keyboard terbuka dan di `vim`/`tmux` (mouse mode); catat bila sentuhan diambil alih program.

Uji tempel (11c) di HP, bisa dilakukan pada kunjungan yang sama:

1. Salin satu baris dari aplikasi lain, buka terminal, ketuk Tempel: masuk ke prompt tanpa dijalankan; toast "Ditempel · 1 baris · belum dijalankan".
2. Salin tiga baris yang memuat `sudo rm -rf /tmp/uji/*`: dialog muncul, baris berisiko bertanda "berisiko", Batal jadi tombol utama; pilih Batal lalu coba lagi dengan Tempel.
3. Ulangi di server dengan bash 5.x (tempel aman nyala) dan bash 4.4 atau 4.3 (Ubuntu 18.04, 14.04): di yang lama harus muncul peringatan "belum mendukung tempel aman" dan baris langsung dijalankan setelah konfirmasi.
4. Tempel di `vim` (mode insert) dan di `tmux`; catat hasilnya.
5. Papan klip kosong: toast "Papan klip kosong". Tempelan besar (beberapa ratus baris): dialog tetap responsif.

Hasil: foreground service (11b) dan sesi di latar belakang (11e) sudah diuji di HP pada 2026-10-16 (lihat "Hasil uji HP" di atas), dengan batasan yang tertulis di sana. Tempel (11c) belum dicoba di HP. Seleksi (11d) sudah dicoba di HP dan sesuai (lihat catatannya).

## 11f. Sambung ulang yang menunggu jaringan, dan rahasia dipegang selama layar menyala (2026-10-16)

Menjawab temuan uji HP 1 (sambung ulang tidak menunggu jaringan, prompt biometrik berulang). **Selesai di PC (377 tes, build debug Android berhasil); belum diuji di HP.**

**Sambung ulang (`SessionController.reconnect()`):**
- Host diperiksa lewat probe TCP dulu (`core/ssh/reconnect_backoff.dart`, `hostProbeProvider`, tanpa dependensi baru). Belum terjangkau: ulangi dengan jeda 2, 5, 10, 30 detik (tetap di 30), tanpa prompt. "Sambung sekarang" menggantikan hitungan mundur.
- Hanya berjalan saat layar menampilkan sesi dan aplikasi terlihat; di latar belakang dijeda.
- UI: banner "Menunggu server terjangkau…" dengan hitungan mundur (ARB `reconnectWaitingTitle`, `reconnectWaitingBody`).

**Keputusan pemilik (2026-10-16): rahasia dipegang di memori selama pengguna masih memakai aplikasi.** Ini melonggarkan butir "pembacaan dijaga biometrik" di CLAUDE.md untuk sambung ulang; alasannya dari pemilik: layar terbuka berarti pengguna masih memakai aplikasi, layar terkunci berarti sudah tidak dipakai.
- Sambungan pertama: satu prompt biometrik, rahasia dipegang (`ConnectFlow.start(holdCredentials: true)`). Putus selagi layar tidak pernah mati: sambung ulang tanpa prompt.
- **Layar mati melepas rahasia**; sambung ulang berikutnya minta biometrik lagi (promptnya muncul saat aplikasi dibuka). Deteksi: `ScreenOffTracker.kt` (receiver `ACTION_SCREEN_OFF` di konteks aplikasi, penghitung di sisi Kotlin) lewat kanal `io.github.egateza.termul/screen` (`core/platform/screen_monitor.dart`). Penghitung dibandingkan sebelum tiap sambung ulang dan saat resume, jadi tetap benar walau Dart dibekukan saat layar mati dan peristiwa tidak sampai; peristiwa langsung hanya mempercepat pelepasan.
- Rahasia juga dilepas saat sesi ditutup atau "Putuskan semua", dan saat galat yang tidak sembuh dengan rahasia yang sama (login ditolak, kunci rusak, host key ditolak, rahasia dimasukkan ulang). String Dart tidak bisa ditimpa, jadi yang dilakukan hanya melepas rujukan.
- Risiko yang diterima: rahasia ada di memori proses selama sesi hidup dan layar menyala, termasuk sesi "Tetap terhubung" di latar belakang. Layar mati dianggap terkunci walau HP punya jeda kunci (lebih ketat).

**Prompt biometrik tidak berulang (temuan log HP 17:31, dikerjakan 2026-10-16):** mengetuk di luar prompt membatalkannya, aplikasi `resumed`, lalu sambung ulang otomatis memunculkan prompt lagi (lima kali dalam 10 detik). Perbaikan: (1) `AuthGate` (`core/vault/auth_gate.dart`, `authGateProvider`) memberi giliran satu prompt pada satu waktu antar sesi dan mengingat pembatalan selama 30 detik; (2) setelah prompt dibatalkan atau gagal, pemicu otomatis (putus, resume) tidak menyambung ulang; sesi menampilkan banner "Perlu verifikasi" (sidik jari, PIN, atau pola perangkat) dengan tombol "Tampilkan prompt" (`reconnect(manual: true)`); (3) sambungan pertama dan tombol selalu manual, jadi jeda 30 detik tidak menghalangi sesi baru. Belum diuji di HP.

**Hasil uji HP (2026-10-16, Xiaomi 25053PC47G, lewat adb dengan izin pemilik; prompt sidik jari disentuh pemilik) [T]:**
- Wi-Fi dimatikan saat layar menyala: putus terdeteksi sekitar 2 detik, banner menunggu dengan hitungan mundur, percobaan berulang tanpa prompt; Wi-Fi dinyalakan: tersambung lagi **tanpa prompt** (rahasia dipegang), shell baru, penanda "— tersambung ulang —".
- Layar dimatikan lalu putus lalu layar dinyalakan dan dibuka kuncinya: **satu prompt** setelah aplikasi terlihat, lalu tersambung.
- Prompt dibatalkan dengan tombol Back: aplikasi `resumed` dan **tidak ada prompt baru**; banner "Perlu verifikasi"; "Tampilkan prompt" memunculkan satu prompt dan tersambung.
- Gulir otomatis seleksi: gagang awal ditahan di tepi atas, isi bergeser dari baris 257 sampai 300 ke 10 sampai 54 dalam sekitar 2 detik, seleksi tumbuh ke 1060 karakter, berhenti saat dilepas. Kecepatan (900 px/detik) terasa cepat untuk scrollback pendek; perlu dinilai pemilik.
- Teks banner menunggu semula menyebut sidik jari akan diminta; salah untuk layar menyala, sudah diganti menjadi "Mencoba lagi dalam N detik."
- Server ditutup dari sisi server (`pkill` sshd di WSL, layar menyala): putus `serverClosed`, tersambung ulang sekitar 1 detik, **tanpa prompt**, penanda "— tersambung ulang —" [T]. Server uji: sshd di WSL (`tool/ssh_test_server/setup.sh`) dijangkau HP lewat `adb reverse tcp:2222 tcp:2222` karena server LAN pemilik tidak terjangkau saat itu.
- Belum diuji: dua sesi bersamaan (AuthGate), `SCREEN_OFF` saat proses dibekukan lama (layar mati puluhan menit) di HyperOS, mode pesawat sungguhan, pindah Wi-Fi ke seluler, `vim`/`tmux`. Catatan: dengan Wi-Fi mati, probe TCP ke host LAN sempat lolos (percobaan 2 tercatat "gagal jaringan", artinya probe berhasil lalu sambung gagal); penyebabnya belum diketahui, perilaku keseluruhan tetap benar.

Saklar "Sambung ulang otomatis" sudah dikerjakan di 11i. **Artifact desain sudah diperbarui** (prototipe 39, design system 33; `SUMBER.md`). CLAUDE.md (butir Rahasia) sudah menyebut keputusan rahasia dipegang selama layar menyala (2026-10-16); `docs/design/android.md` masih perlu, tetapi itu salinan artifact: ubah lewat alur publish (butir 9).

**Belum teruji di HP:** mode pesawat (tanpa prompt selama menunggu), sambung ulang tanpa prompt saat layar menyala, prompt muncul setelah layar mati lalu dibuka, pengiriman `SCREEN_OFF` di HyperOS saat proses dibekukan, pindah Wi-Fi ke seluler.

## 11g. Irisan B: layar pemuatan dan gulir otomatis seleksi (2026-10-16)

**Selesai di PC (377 tes); belum diuji di HP.**

- **Layar pemuatan** (`lib/boot_app.dart`, `main.dart`): `runApp(BootApp())` dipanggil segera; `bootstrap()` berjalan di belakangnya. Selama itu tampil latar `ground` dengan satu baris "Memuat…" (tanpa animasi, jadi tidak ada urusan reduce motion). Gagal membuka penyimpanan tetap menampilkan `BootErrorApp`. Menjawab catatan "layar hitam saat peluncuran pertama" (11, uji HP); penyebabnya tidak pernah terbukti, jadi ini perbaikan terhadap dugaan, bukan terhadap penyebab yang terkonfirmasi. **Tambahan di luar desain:** sudah masuk ke artifact (prototipe 14, README design system versi 33).
- **Gulir otomatis seleksi** (`selection_overlay.dart`): selama gagang diseret, jari dalam 56 dp dari tepi atas atau bawah area terminal menggulir isi (sampai 900 px/detik, makin dekat tepi makin cepat) dan seleksi dihitung ulang tiap frame; berhenti saat jari menjauh dari tepi atau dilepas. Tidak ada perubahan visual, jadi tidak menyentuh artifact desain. Kecepatan dan lebar zona perlu dirasakan di HP.
- Belum diuji di HP: kenyamanan kecepatan gulir, perilaku saat keyboard terbuka, dan di `vim`/`tmux` (layar alternatif tanpa scrollback: seharusnya tidak menggulir).

## 11h. `NavBar` lima tab (2026-10-16)

**Selesai di PC (377 tes) dan dicoba di HP lewat adb [T]:** bar tampil, berpindah tab, lencana "1" di tab Sesi setelah "Tetap terhubung".

- `TermulNavBar` (`shared/widgets/termul_nav_bar.dart`) mengikuti `components/NavBar` dan prototipe `Main` (tepi atas 1 px `line`, item minimal 56 dp, ikon 22, label `navLabel`, tab aktif `accent`, lencana jumlah). `MainShell` (`features/shell/main_shell.dart`) memegang lima tab: Host, Sesi, SFTP, Snippet, Pengaturan. Tab dibangun saat pertama dibuka lalu dipertahankan (pencarian dan gulir Host tidak hilang). Tombol kembali dari tab lain menuju Host dulu. Bar disembunyikan saat keyboard terbuka; layar terminal dan form dibuka di atas kerangka sehingga tanpa bar (sesuai desain).
- Ikon sesi dan pengaturan di header Host dihapus (pindah ke bar). `SessionsScreen` dan `SettingsScreen` punya `showBack` (false sebagai tab; Pengaturan dari terminal tetap dengan tombol kembali).
- **SFTP dan Snippet** belum punya fitur: tab-nya ada (sesuai desain) dan membuka layar sementara berbunyi "Belum tersedia" (`ComingSoonScreen`). Pilihan pemilik (2026-10-16).
- **Artifact desain sudah diperbarui (2026-10-16):** prototipe versi 39 (`1792156922-600e`) dan design system versi 33 (`1792156945-0858`); lihat `docs/design/SUMBER.md`. Berisi juga banner sambung ulang "menunggu" dan "Perlu verifikasi", layar sementara SFTP dan Snippet, dan layar "Memuat…" (11f dan 11g).
- Belum diuji di HP: perilaku tombol kembali sistem dari tab lain, bar saat keyboard terbuka (pencarian Host), landscape.

## 11i. Saklar "Sambung ulang otomatis" (2026-10-16)

**Selesai di PC (380 tes, `flutter analyze` bersih). Di HP: pemilik mencoba dan melaporkan saklar bekerja dengan baik (2026-10-16, rincian skenario tidak dicatat).**

- `ConnectionSettings.autoReconnect` (bawaan **nyala**, kunci `connection.autoReconnect` di `settings.json`; berkas lama tanpa kunci ini tetap termuat). Saklar di Pengaturan, bagian Koneksi, di atas "Pertahankan koneksi di latar belakang", teks mengikuti prototipe `Settings` ("Saat jaringan berpindah atau aplikasi kembali aktif"). Perbaikan sampingan: menyalakan "Pertahankan koneksi" tidak lagi menimpa `autoReconnect` (memakai `copyWith`).
- `SessionController` menerima `autoReconnect` (dibaca tiap dipakai, jadi perubahan langsung berlaku). Mati: pemicu otomatis (sambungan putus, aplikasi terlihat lagi, hitungan mundur) tidak menyambung; sesi tampil "Terputus" dengan tombol "Sambung sekarang", dan tombol itu tetap bekerja (`manual: true`). Dimatikan saat hitungan mundur berjalan: rangkaian berhenti pada ketukan timer berikutnya.
- **Desain:** saklar sudah ada di prototipe `Settings` (`recon`, bawaan nyala), jadi bukan tambahan dan artifact tidak diubah. Teks `README.md` (baris Pengaturan) belum menyebut saklar ini; perbarui saat artifact berikutnya dipublikasikan.
- Belum dirinci: skenario yang dicoba pemilik (mis. saklar mati lalu Wi-Fi diputus) dan tampilan baris baru di layar sempit.

## 11j. Popover Tempel dan saklar konfirmasi tempel satu baris (2026-10-16)

**Selesai di PC (397 tes, `flutter analyze` bersih). Dicoba di HP lewat adb (Xiaomi 25053PC47G, server uji WSL) [T], termasuk build akhir. Artifact sudah diperbarui: prototipe versi 40, design system versi 35.**

Usulan dan keputusan pemilik, bertahap: popover di kursor (prototipe `TerminalPasteMenu`) ternyata sulit dikenai jari, dan pemilik sudah memakai tombol Tempel di panel. Yang dipilih: tempel selalu divalidasi, dengan popover ringan untuk teks pendek dan dialog untuk sisanya.

| Isi papan klip | Saklar nyala (bawaan) | Saklar mati |
|---|---|---|
| Satu baris, tanpa baris baru, aman, sampai 40 karakter | **Popover** berisi teksnya | Langsung masuk prompt |
| Lebih dari 40 karakter | Dialog | Dialog |
| Baris baru, banyak baris, berisiko, atau karakter kontrol dibuang | Dialog | Dialog |
| Kosong, atau lebih dari 100.000 karakter | Toast | Toast |

- **Saklar** "Konfirmasi tempel satu baris" di Pengaturan, bagian Terminal (kunci `terminal.confirmSingleLinePaste`, bawaan nyala; berkas lama tanpa kunci ini tetap termuat). Mematikannya hanya memengaruhi satu baris pendek yang aman; teks panjang, banyak baris, atau berisiko selalu lewat dialog.
- **Ambang 40 karakter** (`PasteAnalysis.popoverMaxChars`) adalah nilai awal untuk dicoba pemilik di HP (80 dianggap terlalu panjang); mudah diubah.
- **Pemicu popover:** tombol Tempel di panel (popover di atas baris kursor, supaya baris prompt tetap terlihat) dan **tekan-tahan (450 ms) di area kosong** terminal (sisa baris di kanan teks, baris kosong, atau ruang di bawah prompt; popover di atas jari). Di atas teks, tekan lama tetap memilih kata (xterm). Hanya aktif saat sesi berjalan. **Tetap aktif di layar alternatif dan mouse mode (`tmux`, `vim`, `htop`)** karena yang dicari sel kosong (temuan pemilik di HP: sebelumnya mati di tmux, hanya tombol Tempel yang bekerja). Ketuk kursor sebagai pemicu **dibuang** (kursor satu sel, sekitar 8 x 17 dp, terlalu kecil untuk jari).
- **Popover** (`PastePopover`): teks yang akan ditempel (mono, paling 2 baris), "Masuk ke prompt, belum dijalankan", tombol Tempel (44 dp). Dipusatkan pada titik asal dan dibatasi 8 dp dari tepi (`_PopoverLayout`), di atas titik itu (di bawahnya bila tidak muat). Menutup: **ketukan di mana saja di luar popover** (terminal, bar atas, tombol cepat; dibaca lewat `Listener` pointer mentah di tingkat layar, `_onAnyPointerDown`; temuan pemilik: sebelumnya hanya Esc di panel yang menutup, regresi saat popover dipindah ke jalur tekan-tahan), mengetik, keluaran yang menggeser kursor, gulir, ukuran layar berubah. Tekan lama xterm yang sempat memilih sel kosong dibuang supaya bilah seleksi tidak menggantikan tombol cepat.
- **Temuan xterm 4.0.0:** `TerminalView.onTapUp` tidak pernah dipanggil (detektor gestur hanya meneruskan `onSingleTapUp`, yang tidak dipasang `TerminalView`). Tekan-tahan dibaca lewat `Listener` pointer mentah yang tidak ikut arena gestur, jadi ketuk, gulir, dan seleksi xterm tidak terganggu.
- **Hasil uji HP [T]:** tekan-tahan di area kosong dekat tepi kiri memunculkan popover berisi teks ("Fri", disalin lewat seleksi) di atas jari, dalam layar; Tempel di popover menempelkan dan toast "Ditempel · 1 baris · belum dijalankan" tampil; tombol Tempel di panel memunculkan popover yang sama; ketukan di tempat lain menutup; tekan lama di atas teks tetap memilih kata (bilah Salin/Semua). Versi pertama (popover rata kanan di kursor) menempel ke tepi kiri layar, dan zona ketuk kursor terlalu kecil; keduanya sudah diganti seperti di atas.
- **Desain:** popover dan saklar sudah di artifact (prototipe versi 40, README versi 34; lihat `docs/design/SUMBER.md`). Penyimpangan dari prototipe asli dicatat di README: popover dipusatkan pada titik asal (bukan rata kanan), dan pemicu tekan-tahan hanya ada di aplikasi.
- **Build akhir [T]:** tombol Tempel memunculkan popover tepat di atas baris prompt (baris prompt tetap terlihat); Tempel di popover memasukkan teks ke prompt tanpa menjalankannya (bash 5.1 menyorot teks hasil tempel aman).
- **Teruji di HP setelah temuan pemilik [T]:** di `tmux` dengan `mouse on`, tekan-tahan di area kosong memunculkan popover; ketukan di terminal atau di bar atas, di luar popover, menutupnya (ketukan di dalam popover tidak menutup).
- **Popover di landscape dengan keyboard (temuan pemilik, diperbaiki):** popover setinggi sekitar 100 dp menimpa bilah status sistem karena area yang tersisa hanya sekitar 130 dp dan tata letaknya tidak menghormati area aman. Perbaikan: (1) `_PopoverLayout` membatasi posisi di dalam area aman (`MediaQuery.padding`) dengan margin 8 dp dan menurunkan popover ke bawah jari bila di atasnya tidak muat; (2) di layar pendek (tinggi < 480 dp) `PastePopover` bersusunan mendatar (teks dan keterangan di kiri, tombol Tempel di kanan, sekitar 56 dp). Teruji di HP [T]: dari tombol Tempel popover tepat di atas baris prompt di bawah bilah status; dari tekan-tahan dekat atas area terminal ia turun ke bawah jari dan menutup sebagian panel tombol. Desain: contoh 2m di prototipe (versi 43) dan README versi 38.
- **Belum diuji di HP:** keyboard tertutup di landscape, tempel isi papan klip panjang (45 baris milik pemilik sengaja tidak ditempel saat uji), dan kenyamanan ambang 40 karakter.

## 11k. Tampilan landscape untuk layar utama (2026-10-16)

**Selesai di PC (408 tes, `flutter analyze` bersih). Dicoba di HP lewat adb (Xiaomi 25053PC47G, landscape 2772 x 1280 px) [T] untuk Host, Sesi, Pengaturan, dropdown, dan pencarian dengan keyboard. Artifact sudah diperbarui: prototipe versi 42 (contoh 1b), design system versi 37.**

Temuan pemilik: di landscape bar navigasi bawah dan header bertingkat (wordmark, judul, pencarian, filter) memakai hampir seluruh tinggi layar (sekitar 393 dp), sehingga daftar host nyaris tak terlihat. Prototipe hanya mendefinisikan landscape untuk terminal (2f, 2g), jadi ini **tambahan desain**. Pilihan pemilik: rel di sisi kiri, satu baris header, satu kolom; lalu dropdown untuk filter.

- **Rel navigasi** (`TermulNavRail` di `termul_nav_bar.dart`, dipakai `MainShell` saat `MediaQuery.orientation == landscape`): lima tab yang sama dengan bar bawah (lencana Sesi sama) dipusatkan secara vertikal dan horizontal, lebar 80 dp, tiap tab minimal 48 dp dengan jarak 4 dp, tepi kanan 1 px `line`, area aman kiri, atas, dan bawah dijaga sendiri; halaman di sebelahnya tidak menjaga lekukan kiri lagi. Perbaikan atas temuan pemilik ("kurang rapi"): isi tab semula bergeser ke kiri sesuai lebar labelnya karena `Pressable` tidak memaksa lebar penuh, dan rel menempel di atas. Rel **disembunyikan saat keyboard terbuka** (seperti bar bawah di potret). Bar bawah hanya di potret.
- **Host** (`host_list_screen.dart`): satu baris berisi judul "Host" (`h2`), kolom pencarian, **satu tombol dropdown filter** (`DropdownPill` di `termul_chip.dart`: label filter aktif dengan panah bawah, berbingkai `accent` bila bukan Semua; membuka `showTermulActions` "Filter host" dengan satu tombol per nilai `HostFilter`, jadi filter baru ikut otomatis dan tetap muat), dan tombol tambah. Wordmark "termul_" tidak ditampilkan di landscape; daftar satu kolom sampai tepi layar. Potret tetap memakai chip Semua dan Favorit.
- **Keyboard di landscape** (temuan pemilik: daftar host hilang saat mencari): akar masalahnya **dua `Scaffold` bertumpuk sama-sama mengurangi tinggi keyboard** (393 - 209 - 209 = area daftar 0 dp). Sumbernya `MediaQuery.removePadding(context: ...)` yang saya tambahkan di `MainShell` untuk landscape: konteksnya di atas `Scaffold`, jadi ia mengembalikan `viewInsets` yang sudah dibuang `Scaffold` luar. Perbaikan: `MainShell` memakai `resizeToAvoidBottomInset: false` (tiap halaman, yang berupa `Scaffold` sendiri, menyesuaikan satu kali), rel disembunyikan saat keyboard terbuka dengan `Expanded` berkunci supaya halaman dan fokus pencarian tidak dibangun ulang, dan selagi mengetik judul, dropdown, tombol tambah, dan judul grup disembunyikan (grup dipaksa terbuka) agar kolom pencarian dan satu-dua baris host tetap terlihat. Potret tidak terpengaruh (tes pelindung ditambahkan).
- **Sesi, Pengaturan, SFTP, Snippet:** judul `h2` dengan jarak atas lebih kecil di landscape. `showTermulActions` kini bisa digulir (sheet pendek di landscape).
- **Teruji di HP [T]:** rel rapi dan terpusat; daftar host menampilkan dua kartu penuh dan sebagian kartu ketiga (sebelumnya kurang dari satu kartu); dropdown "Semua" tampil; mengetuk pencarian memunculkan keyboard dengan kolom pencarian terfokus. Layar Sesi dan Pengaturan tidak terhalang header.
- **Desain:** prototipe 1b (`MainLandscape.dc.html`, 844 x 390), catatan di README design system ("Layar utama di landscape") dan README komponen `NavBar` (varian rel, hilang saat keyboard terbuka). Layar lain (form host, host key, dialog, Sesi dengan banyak kartu) belum dirancang khusus untuk landscape.
- **Perbaikan sampingan:** popover Tempel kini digambar di atas seluruh isi layar, bukan hanya area terminal (di landscape dengan keyboard terbuka area terminal hanya sekitar 65 dp, lebih rendah daripada popover sekitar 100 dp, sehingga terpotong). Tes `landscape ringkas` gagal sebelum perbaikan dan lulus sesudahnya.
- **Selesai dan teruji di HP setelah catatan ini ditulis:** popover Tempel di landscape dengan keyboard (lihat 11j, [T]).
- **Belum diuji di HP:** hasil pencarian dengan keyboard setelah judul grup disembunyikan (pencarian dengan keyboard sudah dicoba pemilik, tampilan daftar sesudahnya belum dicatat), dan form host di landscape.

## 11l. Banner status sambungan di landscape (2026-10-17)

**Selesai (411 tes lulus, `flutter analyze` bersih; uji HP [T]). Artifact sudah diperbarui 2026-10-17: prototipe versi 45 (contoh 2n), design system versi 40.**

Temuan pemilik (tangkapan layar HP): di landscape dengan keyboard terbuka, banner "Menunggu server terjangkau…" meluap ("BOTTOM OVERFLOWED BY 70 PIXELS"). Akar masalah: banner bertumpuk tiga tingkat (judul, teks, tombol, sekitar 126 dp) sedangkan tinggi yang tersisa di atas keyboard sekitar 157 dp dan harus memuat bar atas, terminal, dan tombol cepat. Putusnya sambungan di tangkapan itu wajar (mode pesawat menyala), yang salah hanya tampilannya.

- **`TermulBanner`** mendapat parameter `compact` dan `showBody`. `compact` (layar pendek): padding 10 dp dan tombol aksi di kanan teks, bukan di bawahnya. `showBody: false`: hanya judul dan tombol, padding vertikal 4 dp. `_linkBanner` di `terminal_screen.dart` memakai `compact` bila tinggi di luar keyboard < 480 dp, dan `showBody: false` saat landscape ringkas **dan** keyboard terbuka; jarak di bawah banner juga dipangkas (4 dp) pada keadaan itu.
- **Disengaja (dikonfirmasi pemilik 2026-10-17):** saat keyboard terbuka di landscape teks penjelasan disembunyikan, termasuk "Mencoba lagi dalam n detik". Banner penuh tampil lagi begitu keyboard ditutup. Catatan: "Menyambung ulang…" memang tidak punya hitungan mundur; hitungan hanya ada di keadaan "Menunggu server terjangkau…". Usulan yang belum dikerjakan: pindahkan hitungan ke judul ("Menunggu server terjangkau… 4 dtk") saat teks disembunyikan.
- **Tes:** `landscape dengan keyboard: banner putus tidak meluap...` di `terminal_screen_test.dart` (844 x 390, keyboard 209 dp, padding atas 24). Gagal sebelum perbaikan (meluap 82 px), lulus sesudahnya. **Tes lulus, tetapi di HP versi pertama perbaikan masih meluap 9,1 px** karena keyboard HP lebih tinggi daripada angka di tes; tes belum menangkap kasus itu.
- **Uji HP [T] (2026-10-17):** build pertama, landscape tanpa keyboard: banner mendatar rapi; dengan keyboard masih meluap 9,1 px (keyboard HP lebih tinggi daripada angka di tes). **Build kedua** (padding vertikal dan jarak bawah dipangkas): sesi "WSL Uji" diputus dari server dengan keyboard terbuka, banner tampil satu baris (ikon, "Menunggu server terjangkau…", tombol "Sambung sekarang"), tanpa garis overflow, dan baris prompt terminal tetap terlihat.
- **Label profil tertimpa isi terminal (temuan pemilik, diperbaiki):** dengan keyboard terbuka di landscape, nama profil di bar atas (mis. "Development SIT") bertabrakan dengan baris teratas terminal. Bukan soal tinggi bar (20 dp cukup): `TerminalView` menggambar barisnya melewati batas atas areanya saat area menyusut, sehingga baris teratas terlukis di atas label. Perbaikan: `ClipRect` di sekeliling `TerminalView` (`terminal_screen.dart`). Tes `gambar terminal dipotong...` gagal tanpa `ClipRect` dan lulus dengannya. Teruji di HP [T]: setelah `seq 1 120` dengan keyboard terbuka, label "WSL Uji" bersih dan baris teratas terpotong rapi di batas area.
- **Desain (sudah di artifact):** varian banner `compact` (susunan mendatar, tombol di kanan) dan `showBody: false` (hanya judul dan tombol saat keyboard terbuka) di README design system (catatan implementasi) dan README komponen `Banner`; prototipe `TerminalLandscape` mendapat prop `waiting` dan contoh baru 2n (`TerminalLandscapeWaiting`), diperiksa di Chrome (keyboard terbuka, tertutup, dan tampilan normal tidak berubah). Perbaikan `ClipRect` tidak mengubah desain; dicatat singkat di README.

## 11m. Form host di landscape dengan keyboard (2026-10-17)

**Selesai (411 tes; uji HP [T]). Artifact sudah diperbarui 2026-10-17: prototipe versi 45 (contoh 1c), design system versi 40.**

Temuan saat uji HP: di landscape dengan keyboard terbuka form "Host baru" kehilangan seluruh kolomnya (hanya judul dan tombol Simpan yang tersisa, meluap 14 px), karena judul dan bar Simpan besar di bawah (sekitar 90 dp) memakan hampir seluruh tinggi di atas keyboard. Perbaikan (`host_form_screen.dart`): di layar pendek (tinggi di luar keyboard < 480 dp, konstanta `TerminalScreen.compactBelowDp`) tombol Simpan pindah ke kanan baris judul (ukuran `sm`, 44 dp) dan bar bawah tidak dipakai; di potret tidak berubah. Tes `landscape dengan keyboard: kolom form tetap terlihat...` di `host_form_screen_test.dart` gagal tanpa perbaikan (Simpan 77 dp di bawah judul) dan lulus dengannya. Teruji di HP [T]: kolom Nama terlihat dengan teks yang diketik, Simpan di baris judul, keluar tanpa menyimpan (tidak ada host contoh tersimpan).

- **Desain (sudah di artifact):** form host di layar pendek adalah tambahan; catatan di README design system dan contoh 1c (`HostFormLandscape.dc.html`) di prototipe.
- **Teruji di HP juga [T]:** pencarian host dengan keyboard di landscape (kolom pencarian dan hasil terlihat penuh), sheet dropdown filter (terbuka, memilih Favorit menyaring daftar dengan bingkai aksen, Semua mengembalikan), dan sheet "Keluar dari terminal?" muat di landscape.
- **Uji HP [T] (2026-10-17), tiga uji terakhir:**
  - **Tempel papan klip panjang:** lulus. Papan klip pemilik ternyata kosong ("Papan klip kosong"), jadi isinya dibuat dari terminal (`seq 1 45`, Semua, Salin: 91 baris, 1838 karakter). Dialog "Tempel 91 baris?" muat di landscape, pratinjau bisa digulir, tombol Batal dan Tempel terlihat penuh. Setelah Tempel: toast "Ditempel · 91 baris · belum dijalankan", teks masuk ke prompt (bash menggambar ulang 91 baris) dan tidak dijalankan; `^C` membersihkannya.
  - **"Putuskan semua" dari notifikasi:** lulus. Notifikasi "1 sesi tersambung / WSL Uji" (kanal `sesi_aktif`, foreground service) punya aksi "Putuskan semua"; setelah diketuk, proses sshd `termul_t` di server turun dari 2 menjadi 0 dan notifikasi hilang. Shell yatim `pts/7` dari uji 2026-10-16 tidak muncul lagi (penyebabnya tetap tidak terbukti).
  - **Layar mati sekitar 25 menit** (07:41 sampai 08:06) dengan sesi "WSL Uji" terbuka: sesi tetap "Tersambung", tidak ada prompt biometrik, dan perintah `echo` setelahnya dijawab (sambungan benar-benar hidup; server masih memegang sesinya). **Batas hasil ini:** HP tercolok kabel USB (65% dan mengisi daya), jadi Android tidak masuk Doze dan soket TCP tidak dihancurkan; ini belum mewakili uji "layar mati 30 menit atau lebih" tanpa kabel. Uji tanpa kabel (adb nirkabel atau cukup memeriksa visual sesudahnya) tetap tercatat belum diuji.

## 11n. SFTP, langkah 1: lapisan data (2026-10-17)

**Selesai di PC (414 tes lulus, `flutter analyze` bersih); belum ada UI dan belum diuji di HP.** Tab SFTP masih layar sementara "Belum tersedia".

Keputusan pemilik (2026-10-17): SFTP bisa lewat **sesi SSH yang sedang terbuka** atau **koneksi sendiri** (seperti TermUL desktop); unduhan masuk ke **Unduhan/TermUL**; dependensi baru diserahkan ke saya dengan syarat lisensi bebas (MIT, BSD, Apache). Rencana irisan: (1) lapisan data [selesai], (2) layar jelajah folder, (3) unduh dan unggah dengan progres dan batal (unduhan ke Unduhan/TermUL lewat MediaStore, dicoba dulu dengan method channel Kotlin sendiri agar tanpa paket baru; bila perlu paket, lisensinya dicek dan dicatat di `docs/licenses.md`), lalu irisan berikutnya: buat folder, ganti nama, hapus, edit berkas jarak jauh.

- **`lib/core/sftp/sftp_service.dart`:** `SftpService` membungkus satu `SftpClient` (tidak menyambung sendiri dan tidak memegang kredensial): `home`, `list` (folder dulu, tautan simbolik ke folder dihitung folder), `mkdir`, `rename`, `deleteFile`, `deleteTree`, `download`, `upload` dengan `onProgress` dan `SftpCancelToken`. Galat dipetakan ke `SftpFailure` (`notFound`, `permissionDenied`, `connectionLost`, `cancelled`, `other`).
- **Temuan:** `SftpFileWriter.abort()` menyelesaikan `done` **secara normal**, jadi pembatalan unggah harus dideteksi sendiri; berkas parsial di server dihapus saat batal atau gagal (spike K14 hanya mencatat masalahnya).
- **Tes:** `test/core/sftp/sftp_service_test.dart`. Helper jalur jalan tanpa jaringan; delapan tes lainnya memakai server SSH sungguhan lewat `--dart-define=SSH_TEST_CONFIG=<config.json>` (dilewati tanpa itu) dan lulus terhadap WSL Ubuntu 22.04 (unggah, daftar, unduh, ganti nama, hapus, batal unggah dan unduh, galat dipetakan, hapus rekursif).
- **Belum teruji:** kecepatan SFTP di HP (angka 4 detik per 100 MB hanya dari PC), pembatalan saat sambungan putus di tengah transfer, folder besar, nama berkas non-UTF-8.
- **Desain:** belum ada perubahan (layar 4 dan komponen Progress dan Toast sudah ada di artifact). Artifact baru perlu diperbarui hanya untuk tambahan di langkah 2 dan 3 (mis. pilihan koneksi, tempat simpan unduhan).

## 11o. SFTP, langkah 2: layar jelajah folder (2026-10-17)

**Selesai (431 tes, `flutter analyze` bersih); teruji di HP lewat adb (sebagian). Artifact sudah diperbarui 2026-10-17: prototipe versi 46 (contoh 4b sampai 4e), design system versi 41.**

- **Tab SFTP** (`lib/features/sftp/sftp_screen.dart`) menggantikan layar "Belum tersedia": pilihan sumber, yaitu **Sesi terbuka** (sesi "Tetap terhubung" dipinjam, tanpa login lagi; hanya muncul bila ada) dan **Koneksi sendiri** (semua host, lewat `ConnectFlow`: vault, biometrik, verifikasi host key). `SftpLink` (`sftp_link.dart`) membungkus kedua cara; menutup layar menutup koneksi sendiri, sesi yang dipinjam tetap hidup. `SessionController.connection` ditambahkan untuk meminjam.
- **Penjelajah:** `SftpBrowserController` (jalur, isi, pilihan, galat; hasil muatan lama dibuang bila sudah pindah folder), breadcrumb yang bisa diketuk, baris `..`, tarik untuk memuat ulang, bar "dipilih" dengan **Salin path**. Banner bila sambungan putus (koneksi sendiri: tombol Sambung ulang) dan bila subsistem SFTP tidak tersedia. `connectFailureText` dijadikan fungsi publik agar kegagalan sambung memakai teks yang sama dengan terminal. Ikon `file` ditambahkan.
- **Teruji di HP [T] (2026-10-17, lewat adb; biometrik disentuh pemilik):** daftar host di tab SFTP; sambung ke "WSL Uji" dengan koneksi sendiri (sampai daftar folder tampil sekitar 12 detik, termasuk menunggu prompt); daftar folder rumah (folder dulu, ukuran, "27 menit lalu", "6 Jan 2022"); buka folder; memilih berkas (bingkai aksen, bar "dipilih"); Salin path (toast "Path disalin"); breadcrumb ke `/home`; Naik ke `/`; Muat ulang.
- **Keluar dari SFTP tidak meminta konfirmasi dan sesi di server tertutup [T]:** server WSL (`ps` dan `ss` di Ubuntu-22.04) memperlihatkan `sshd: termul_t [priv]`, `sshd: termul_t@notty`, dan `sftp-server` selama layar SFTP terbuka. Setelah tombol kembali di header **dan** setelah tombol kembali sistem, ketiganya hilang dan koneksi TCP ke port 2222 turun ke 0. Itu **sebelum** konfirmasi keluar ditambahkan (lihat di bawah).
- **Konfirmasi keluar (keputusan pemilik 2026-10-17: selalu konfirmasi, dan lebih lengkap bila ada transfer):** header kembali dan tombol kembali sistem membuka sheet "Keluar dari SFTP?" (Batal tetap di layar, Keluar menutup). Bila ada transfer berjalan, sheet berjudul "Transfer masih berjalan": jumlah dan daftar transfer dengan persen (ikut berjalan), catatan bahwa berkas unggahan yang belum lengkap dihapus dari server dan berkas unduhan dari perangkat, Batal jadi tombol utama, dan "Batalkan transfer dan keluar" membatalkan semuanya. Dibangun: `SftpTransferTracker` (`sftp_transfers.dart`, `SftpLink.transfers`; menutup layar atau sambung ulang membatalkan semua transfer). Tanpa transfer sheet ini sudah teruji di HP [T] (sheet tampil, Batal tetap di daftar, Keluar menutup dan server 0 sesi); **varian dengan transfer baru teruji otomatis** (3 tes widget) karena belum ada unduh atau unggah, jadi belum pernah tampil di HP. Saat langkah 3 dibuat, setiap transfer wajib didaftarkan ke `link.transfers`.
- **Edit berkas jarak jauh:** belum ada (desain layar 4 memuat Edit, Unduh, Salin path; sekarang baru Salin path). Dijadwalkan setelah unduh dan unggah.
- **Belum teruji di HP:** pinjam sesi, sambungan putus di latar belakang (Home lalu kembali), keluar lewat Home atau aplikasi dimatikan (apakah server menutup sesi yatim), host key baru lewat SFTP, folder besar. **Catatan:** pada percobaan pertama prompt biometrik habis tanpa disentuh dan layar kembali ke daftar host, bukan ke layar "Autentikasi dibatalkan"; belum dipastikan penyebabnya dan belum diulang dengan sengaja membatalkan prompt.
- **Belum dikerjakan:** meminjam sesi yang sedang tampil di layar terminal (tombol SFTP di terminal, seperti desain layar 4), serta tombol Unggah dan Unduh/Edit (langkah 3 dan berikutnya).
- **Desain (sudah di artifact):** layar pilih sumber SFTP, sheet konfirmasi keluar (biasa dan dengan transfer), banner sambungan putus, subjudul "terputus" berwarna `bad`, dan ikon `file`; catatan di README design system (butir SFTP) dan README `Icon`. Yang belum bisa sesuai layar 4 (Unggah, Unduh, Edit, buka dari terminal) dicatat di README.

## 11p. SFTP: sambung ulang otomatis (2026-10-17)

**Selesai (437 tes, `flutter analyze` bersih); teruji di HP lewat adb. Artifact diperbarui 2026-10-17: prototipe versi 47 (contoh 4f dan 4g), design system versi 42.**

Permintaan pemilik: sambung ulang SFTP memakai mekanisme yang sama dengan terminal. Rahasia dipegang di memori selama layar SFTP terbuka dan layar menyala (kelanjutan keputusan 2026-10-16 untuk sesi terminal; pemilik menyetujui).

- **`SftpLink` (`lib/features/sftp/sftp_link.dart`)** untuk koneksi sendiri kini menjalankan rangkaian yang sama dengan `SessionController`: sambungan putus ditandai (`closed`), probe TCP (`HostProbe`), jeda bertingkat `ReconnectBackoff` (2, 5, 10, 30 detik), `ConnectFlow.start(holdCredentials: true)`, rahasia dilepas bila layar pernah mati (`ScreenMonitor`), saklar "Sambung ulang otomatis" dihormati, tidak menyambung selagi di latar belakang (dilanjutkan saat aplikasi terlihat lagi), `checkAlive` saat kembali ke depan, dan prompt yang dibatalkan memunculkan "Perlu verifikasi" dengan tombol "Tampilkan prompt". Logikanya ditulis ulang di `SftpLink`, bukan dipakai bersama dengan `SessionController`; bila keduanya perlu diubah bersamaan, pertimbangkan mengekstraknya.
- **Sesi yang dipinjam** (`SftpLink.borrowed(session:)`) mengikuti sesi terminalnya: sesi putus menandai SFTP putus, dan saat sesi itu tersambung ulang kanal SFTP dibuka lagi di sambungan barunya. `SftpOpener` ditambahkan sebagai titik suntik tes.
- **Layar:** daftar lama tetap terlihat selagi putus; banner "Menunggu server terjangkau…" (hitungan mundur dan "Sambung sekarang"), "Menyambung ulang…", "Perlu verifikasi", atau putus biasa; subjudul "terputus" berwarna `bad`. Setelah tersambung, folder yang sama dibuka lagi (`SftpBrowserController.start(restore:)`, jatuh ke folder rumah bila gagal). Host key yang perlu diputuskan saat sambung ulang tampil di atas layar. Transfer yang berjalan dibatalkan saat putus.
- **Tes:** `test/features/sftp/sftp_link_test.dart` (6 tes): putus lalu sambung ulang tanpa prompt kedua dan layanan diganti, saklar mati, layar mati melepas rahasia, menutup layar menutup koneksi dan membatalkan transfer, sesi dipinjam mengikuti sesinya, dan layar (banner hitungan mundur, folder dipulihkan).
- **Teruji di HP [T]:** sambungan diputus dari server (`pkill` pada sesi sshd): tersambung lagi dalam sekitar 1 detik, tanpa prompt biometrik, folder `.ssh` tetap terbuka. Server tidak terjangkau (`adb reverse` dilepas lalu sesi diputus): subjudul "terputus" merah dan banner "Menunggu server terjangkau…" dengan "Mencoba lagi dalam 3 detik" dan tombol "Sambung sekarang"; setelah jalur dipulihkan tersambung sendiri dalam sekitar 6 detik dan kembali ke folder yang sama.
- **Belum teruji di HP:** putus karena Android memutus soket di latar belakang (Home lalu kembali), layar mati lalu prompt biometrik pada sambung ulang, "Perlu verifikasi" setelah prompt dibatalkan, sesi yang dipinjam, dan sambung ulang dengan host key yang berubah.

## 11q. SFTP, langkah 3: unduh dan unggah (2026-10-17)

**Selesai (448 tes, `flutter analyze` bersih); teruji di HP lewat adb (build profile) kecuali yang tertulis belum. Artifact diperbarui 2026-10-17: prototipe versi 48 (contoh 4h dan 4i), design system versi 43.**

Keputusan pemilik: unduhan masuk ke folder Unduhan dengan subfolder TermUL; dependensi baru diserahkan ke saya (tidak ada paket baru: pemilih berkas memakai `file_selector` yang sudah ada, penyimpanan ke Unduhan lewat kode Kotlin sendiri).

- **Unduhan:** berkas diunduh ke berkas sementara di cache aplikasi, lalu disalin ke Unduhan/TermUL lewat `DownloadsSaver.kt` (MediaStore, `RELATIVE_PATH = Download/TermUL`, `IS_PENDING` selama disalin, entri dihapus bila gagal; nama kembar diberi " (1)" oleh MediaStore dan nama akhirnya ditampilkan di toast). Salinan berjalan di thread latar belakang. Berkas sementara selalu dihapus; batal atau gagal tidak meninggalkan apa pun di Unduhan. Android di bawah 10 (minSdk 24): folder Unduhan khusus aplikasi, **belum diuji**. Method channel `io.github.egateza.termul/downloads` (`lib/core/platform/downloads_saver.dart`).
- **Unggahan:** pemilih berkas sistem (`file_selector`, `openFiles`), isi dibaca bertahap (`XFile.openRead`), nama yang sudah ada di folder itu ditanyakan ("nama sudah ada", Batal tombol utama). **Perbaikan rancangan yang ditemukan saat uji:** menulis langsung ke nama tujuan memotong berkas lama lebih dulu sehingga membatalkan unggahan yang menimpa menghilangkan berkas asli; kini ditulis ke `nama.termul-part` lalu diganti namanya setelah selesai (SFTP v3/OpenSSH menolak mengganti nama ke berkas yang sudah ada, jadi berkas lama dihapus tepat sebelum penggantian nama). Berkas sementara dihapus bila gagal; bila penggantian nama gagal berkas sementara dibiarkan supaya hasil unggahan tidak hilang. Tes dengan sshd sungguhan: timpa lalu batal menyisakan berkas lama utuh tanpa berkas sementara.
- **Orkestrasi** (`sftp_transfer_actions.dart`): mendaftarkan transfer ke `link.transfers` (konfirmasi keluar dan pembatalan saat putus mengenalinya), pembatas laju progres 120 ms (yang pertama dan nilai akhir selalu lewat), hasil `TransferDone`, `TransferCancelled`, `TransferFailed` untuk toast. **Panel transfer** di layar: nama, persen, bilah, tombol batal per transfer. Header mendapat tombol Unggah; bar pilihan Unduh dan Salin path. Ikon `upload` dan `download` ditambahkan. Waktu ubah berkas yang sedikit di masa depan (jam server maju) ditampilkan "baru saja".
- **Tes:** `sftp_transfer_actions_test.dart` (7 tes: unduh utuh dan bersih, batal, gagal dipetakan, simpan gagal, unggah, batal dan gagal unggah, pembatas laju), tes layar (unduh, panel dan batal, unggah dengan konfirmasi menimpa, unggah nama baru), dan satu tes server baru. Catatan tes widget: I/O berkas sungguhan tidak selesai di dalam `testWidgets`; tes layar memakai `createTempSync` dan `runAsync`.
- **Teruji di HP [T]:** unduh berkas kecil dan 40 MB (hash cocok; folder TermUL terlihat di aplikasi File; nama kembar " (1)"); panel dengan persen; **batal di tengah unduhan** (toast "Dibatalkan", tidak ada berkas baru di Unduhan, cache bersih); unggah lewat pemilih berkas sistem dengan konfirmasi menimpa (Batal dan Timpa); unggah 40 MB (selesai sekitar 3 detik; selama berjalan server menyimpan berkas asli utuh dan hanya `.termul-part` yang tumbuh).
- **Kecepatan:** build profile, 40 MB lewat `adb reverse` ke server WSL: unduh 4,1 detik (sekitar 10 MB/s), salin ke Unduhan 0,16 detik; unggah serupa. Build **debug** sekitar 1,6 MB/s (25 detik) karena JIT; cipher ChaCha20-Poly1305 dalam Dart murni yang membatasi, bukan jaringan (spike: 11,9 MB/s di HP).
- **Temuan: ANR di build debug.** Selama unduhan 40 MB di build debug, Android melaporkan "Input dispatching timed out" (tap batal menunggu 5 detik lalu dibuang, dialog "TermUL tidak menanggapi"). Di build profile tidak terjadi (0 ANR, batal langsung bekerja). Dugaan: Dart berjalan di thread yang sama dengan UI dan pekerjaan dekripsi besar menghambat input; di debug jauh lebih berat. **Risiko di HP yang lebih lambat belum diukur;** bila ANR muncul di build rilis, pindahkan pekerjaan SFTP ke isolate terpisah.
- **Belum teruji di HP:** batal di tengah unggahan (unggahan 40 MB selesai lebih cepat dari ketukan; tercakup tes server), Android di bawah 10, folder besar atau berkas ratusan MB, penyimpanan penuh, unggah banyak berkas sekaligus, nama berkas dengan karakter khusus, unduhan saat layar mati atau aplikasi di latar belakang (transfer tidak dilindungi foreground service).
- **Belum dibuat:** Edit berkas jarak jauh, buka SFTP dari layar terminal, buat folder, ganti nama, hapus, melanjutkan transfer yang putus.

## 11r. SFTP: nama berkas sudah ada, nama lain atau timpa (2026-10-17)

**Selesai (455 tes, `flutter analyze` bersih); teruji di HP (build profile). Artifact diperbarui: prototipe versi 49 (contoh 4i dan 4j), design system versi 44.**

Permintaan pemilik: unduh dan unggah punya pilihan timpa atau simpan dengan nama lain bernomor "(1)", "(2)", dan seterusnya.

- **Sheet konflik** (`showTermulActions`, satu untuk unggah dan unduh): "nama sudah ada", tombol utama **Simpan sebagai nama (n).ext** (nama sebenarnya tertulis di tombol, aman), **Timpa berkas lama** (`danger`; catatan bahwa menimpa tidak bisa dibatalkan), **Batal**. Muncul sebelum transfer dimulai. Menggantikan sheet "nama sudah ada" dari 11q.
- **Penomoran** (`unique_name.dart`): nomor pertama yang bebas (celah diisi dulu); ekstensi di titik terakhir, `.tar.gz`/`.tar.bz2`/`.tar.xz`/`.tar.zst` utuh, tanpa ekstensi dan berkas tersembunyi (`.bashrc (1)`) ditangani.
- **Unggah:** konflik dideteksi dari isi folder yang sedang dibuka; nama bernomor dipilih terhadap nama di folder itu. **Unduh:** `DownloadsSaver.exists` (Kotlin: MediaStore menurut nama dan `Download/TermUL/`), nama bernomor dipilih terhadap yang terlihat; `save(overwrite: true)` mengganti isi berkas lama (`openOutputStream(uri, "wt")`) dan toast "Ditimpa di Unduhan/TermUL · nama".
- **Batas Android:** di Unduhan hanya berkas milik aplikasi ini yang terlihat dan bisa ditimpa. Berkas bernama sama milik aplikasi lain (atau dari instalasi dengan pemilik berbeda) tidak terlihat, jadi tidak ada dialog dan MediaStore menomorinya sendiri; bila menimpa ditolak (`SecurityException`) hasilnya disimpan sebagai berkas bernomor dan toast tidak mengatakan "Ditimpa". Android di bawah 10: folder khusus aplikasi, **belum diuji**.
- **Tes:** `unique_name_test.dart` (3), tes aksi (nama lain dan timpa diteruskan), dan tes layar (unggah: Batal, nama lain, timpa, nomor berikutnya bila (1) ada; unduh: nama lain melewati yang ada, timpa, batal).
- **Teruji di HP [T]:** unduh `uji_kecil.txt` yang sudah ada: dialog tampil dengan "Simpan sebagai uji_kecil (1).txt"; berikutnya menyarankan (2) dan berkas bernomor terbentuk di Unduhan/TermUL; **Timpa** mengganti isi `uji_kecil.txt` di HP dengan isi baru dari server (15 B menjadi 30 B) tanpa membuat berkas baru, nomor (1) dan (2) tetap berisi versi lama; unggah `uji_kecil.txt` dari pemilih berkas ke server yang sudah punya nama itu: dialog "Di /home/termul_t di server", memilih nama lain membuat `uji_kecil (1).txt` di server dan berkas asli tidak berubah.
- **Belum teruji di HP:** Timpa untuk unggahan (tercakup tes layar dan tes server 11q), konflik dengan berkas milik aplikasi lain di Unduhan, Android di bawah 10, beberapa berkas sekaligus dari pemilih (konfliknya ditanyakan satu per satu).

## 11s. SFTP: pilihan berkas dilepas setelah aksi (2026-10-17)

**Selesai (457 tes; teruji di HP). Design system versi 45 (catatan di README); prototipe tidak berubah.**

Permintaan pemilik: setelah Unduh atau Salin path ditekan, seleksi pada berkas dihilangkan, karena sebelumnya Unduh bisa ditekan berulang. `SftpBrowserController.clearSelection()`; bar pilihan memanggilnya begitu salah satu tombol ditekan (sebelum aksi berjalan, jadi tidak ada celah untuk ketukan kedua). Konsekuensi: bila pengguna membatalkan sheet "nama sudah ada", pilihan tetap sudah lepas dan berkas dipilih ulang. Tes: unduh melepas pilihan dan hanya satu unduhan berjalan, Salin path melepas pilihan, `clearSelection`. **Teruji di HP [T]:** Salin path (toast, bar hilang) dan tiga ketukan cepat pada Unduh menghasilkan satu berkas saja di Unduhan/TermUL.

## 11t. SFTP: tombol kembali ke folder sebelumnya (2026-10-17)

**Selesai (463 tes; teruji di HP). Design system versi 46 (catatan di README); prototipe tidak berubah.**

Temuan pemilik: di dalam sebuah folder, tombol kembali malah membuka konfirmasi keluar dari SFTP. Kini `SftpBrowserController` menyimpan riwayat folder (`back()`, `canGoBack`): tombol kembali di header dan tombol kembali sistem kembali ke folder yang dikunjungi sebelumnya (satu tingkat per ketukan); konfirmasi keluar baru muncul di folder awal. Riwayat, bukan folder induk: setelah melompat lewat breadcrumb, kembali ke asal lompatan. Muat ulang tidak menambah riwayat; folder yang gagal dibuka tidak mengubahnya; riwayat dibawa ke penjelajah baru setelah sambung ulang. Tes: controller (3), layar (3: sistem dan header di dalam folder, folder awal, beberapa tingkat). **Teruji di HP [T]:** dari `.ssh`, tombol kembali sistem kembali ke folder rumah tanpa konfirmasi; di folder rumah muncul "Keluar dari SFTP?". Baris `..` tetap naik ke folder induk dan ikut masuk riwayat.

## 11u. SFTP: seleksi ganda dan unduh folder (2026-10-17)

**Selesai (479 tes lulus, 2 dilewati; `flutter analyze` bersih; jalur utama teruji di HP, lihat di bawah).** Design system versi 47 (`1792235257-3479`) dan prototipe versi 50 (`1792235241-ca17`).

Permintaan pemilik: multi seleksi di SFTP lewat tekan lama (berkas maupun folder), dengan jumlah pilihan dan total ukuran berkas (folder dihitung di jumlah, tidak di ukuran), dan unduh folder; symlink diikuti ke sumbernya.

- **Seleksi ganda:** `SftpBrowserController` menyimpan himpunan jalur terpilih (`toggle`, `selectAll`, `clearSelection`, `selection` urut seperti daftar, `selectionCount`, `selectionBytes` tanpa folder). Ada pilihan berarti mode seleksi: ketukan menambah atau mencabut pilihan dan folder tidak dibuka; tekan lama memulai (`Pressable.onLongPress` baru, juga ke semantik). Bar pilihan: tutup ("Batal pilih"), "N dipilih" (satu entri: "nama dipilih"), total ukuran, "Pilih semua" (hilang bila semua terpilih), Unduh, Salin path (banyak path satu per baris). Tombol kembali lebih dulu melepas pilihan. Perilaku lama (ketuk berkas memilih satu, ketuk folder membuka) tetap berlaku selama belum ada pilihan.
- **Unduh folder:** `SftpFileOps.walk` (`SftpService.walk`) menelusuri rekursif dan mengembalikan `SftpTree` (berkas, ukuran, jumlah dilewati). Symlink ke berkas atau folder diikuti ke sumbernya (`stat`); dilewati dan dihitung: symlink rusak, putaran (folder yang sedang ditelusuri **atau folder yang memuat folder awal**, mis. tautan ke `..`; celah ini ditemukan saat uji dan ditutup), soket dan sejenisnya, dan subfolder yang tidak terbaca. Folder kosong tidak dibuat (MediaStore tidak bisa membuat folder tanpa berkas). `SftpTransferActions.downloadFolder` mengunduh berurutan sebagai **satu transfer** (total dari penelusuran, satu bilah, satu tombol batal); berkas yang gagal (izin, hilang) dilewati dan dihitung, sambungan putus dan pembatalan menghentikan sisanya; berkas yang sudah tersimpan **tidak dihapus**. `DownloadsSaver.save/exists` mendapat parameter `folder` (subfolder relatif, `Download/TermUL/<folder>/...`), ditambah `folderExists`; sisi Android di `DownloadsSaver.kt` dan `MainActivity.kt` (segmen `..` ditolak; di bawah API 29 memakai folder Unduhan khusus aplikasi).
- **Bentrok nama:** satu pertanyaan untuk seluruh kelompok ("N item sudah ada": nama bernomor, timpa semuanya, batal); satu entri memakai sheet lama. Folder bernomor `nama (1)` tanpa memecah ekstensi (`uniqueFolderName`). Menimpa folder mengganti berkas bernama sama dan menambah yang baru. Beberapa entri diunduh berurutan dengan satu toast ringkasan ("N berkas diunduh ke ...", "... · M dilewati", "N berkas diunduh, M gagal"), pembatalan menghentikan sisa kelompok.
- **Tes:** controller (seleksi ganda, pilih semua), layar (tekan lama folder, jumlah dan ukuran, Salin path banyak, kembali, Unduh banyak, bentrok banyak, folder bersubfolder, folder bernomor, folder dan berkas sekaligus), aksi (`downloadFolder`: struktur, saveAs dan timpa, berkas gagal, semua gagal, putus di tengah, batal di tengah, folder kosong, penelusuran gagal), dan **server SSH sungguhan di WSL** (`walk` dengan symlink berkas, folder, putaran, tautan ke `..`, tautan rusak, root berupa symlink, batal). Jalur MediaStore tidak bisa dites di PC.
- **Teruji di HP [T] (2026-10-17, lewat adb; biometrik disentuh pemilik; server WSL `~/uji_unduh`):** tekan lama folder memilihnya tanpa membuka (bingkai, centang, bar "uji_unduh dipilih"); menambah `.bashrc` menjadi "2 dipilih · 3,7 KB" (folder tidak dihitung); Unduh menyimpan `Download/TermUL/uji_unduh/{a.txt, sub/b.txt, sub/dalam/c.txt, tautan_sub/..., tautan_a.txt}` dengan isi benar (symlink diikuti ke sumbernya; `putaran` dan `rusak` tidak ikut, folder `kosong` tidak dibuat) dan `.bashrc`; mengulang unduhan memunculkan sheet "2 item sudah ada" (`folderExists` bekerja) dan "Simpan dengan nama bernomor" menghasilkan `uji_unduh (1)` dan `.bashrc (1)`; toast "7 berkas diunduh ke Unduhan/TermUL · 2 dilewati" (terpotong "dile..." karena toast satu baris; belum diperbaiki).
- **Belum teruji di HP:** Timpa semuanya pada folder, unduh folder besar dan lama, pembatalan di tengah folder, sambungan putus di tengah folder, Android di bawah 10.
- **Desain (sudah di artifact):** contoh baru 4k (seleksi ganda) dan 4l (unduh folder berjalan) di prototipe dan canvas; catatan di README design system (butir SFTP). Sheet "N item sudah ada" belum punya contoh sendiri (bentuknya sama dengan 4i dan 4j).

## 11v. SFTP: toast saat daftar dimuat ulang (2026-10-17)

**Selesai (480 tes). Belum diuji di HP. Design system versi 48 (`1792235871-a469`, catatan di README); prototipe tidak berubah (toast memakai komponen yang ada).**

Permintaan pemilik: toast saat muat ulang lewat tombol header maupun tarik ke bawah. `_refresh()` di layar SFTP memuat ulang lalu menampilkan "Daftar file diperbarui" **hanya bila berhasil**; bila gagal tidak ada toast karena galat sudah tampil di banner. Tombol Coba lagi di banner galat dan muat ulang otomatis setelah unggah tidak menampilkan toast. Tes: tombol, tarik ke bawah, dan kegagalan tanpa toast.

## 11w. SFTP: lencana tautan simbolik (2026-10-17)

**Selesai (481 tes). Prototipe versi 51 (`1792236450-1abf`, contoh baru 4m), design system versi 49 (`1792236452-92dc`, README dan `components/Icon/README.md`).**

Permintaan pemilik: tanda untuk membedakan symlink. `SftpEntry.isLink` (diisi `SftpService.list` dari jenis asli sebelum `stat`); baris berkas atau folder tautan mendapat lencana ikon `link` (ikon baru, 9 dp, di lingkaran 14 dp `surface` bertepi `line-strong`, pojok kanan bawah ikon) dan kata "Tautan" di akhir keterangan ("Folder · Tautan"), jadi status tidak hanya lewat ikon. Symlink ke folder tetap dibuka sebagai folder. Tes: layar (lencana dan kata), dan server SSH sungguhan (`isLink` untuk symlink berkas dan folder, bukan untuk yang biasa). **Teruji di HP [T] (2026-10-17):** di `~/uji_unduh` lencana dan "Folder · Tautan" tampil pada `putaran` dan `tautan_sub` (folder), serta "... · Tautan" pada `tautan_a.txt` dan `rusak` (tautan rusak tampil seperti berkas dengan ukuran panjang jalurnya, 9 B); `kosong`, `sub`, dan `a.txt` tanpa penanda. Lencana tidak terpotong dan tidak mengubah tinggi baris.

## 11x. Aplikasi dikunci ke potret (2026-10-17)

**Selesai (481 tes). Di HP terbukti lewat `dumpsys` bahwa aktivitas meminta `SCREEN_ORIENTATION_PORTRAIT`; putar fisik belum dicoba (pengaturan putar otomatis HP tidak diubah). Design system versi 50 (`1792237386-de11`, catatan di README); prototipe tidak berubah.**

Keputusan pemilik: satu orientasi saja supaya konsisten. `android:screenOrientation="portrait"` di manifest dan `SystemChrome.setPreferredOrientations([portraitUp])` di `main.dart` (`preferredOrientations`). Kode landscape (rel navigasi, terminal ringkas, banner satu baris, form host, 11k sampai 11m) dibiarkan dan tesnya tetap jalan (tes memakai ukuran layar langsung, bukan rotasi perangkat); tidak ada yang dihapus. Konsekuensi: terminal memuat sekitar 40 sampai 50 kolom. Prototipe landscape dibiarkan di kanvas sebagai rujukan tidak aktif.

## 11y. Ikon SFTP di terminal, sesi yang sama (2026-10-17)

**Selesai (485 tes), teruji di HP [T] 2026-10-17. Prototipe tidak berubah (tombol sudah ada di `Terminal.dc.html`); design system versi 51 (`1792237609-cc4b`, catatan README).**

Permintaan pemilik (mengacu TermUL desktop): SFTP memakai sesi terminal yang sama. Header terminal mendapat tombol folder (`onOpenSftp`, hanya saat sesi tersambung) yang memanggil `openSftpFromSession` (dipakai juga tab SFTP lama): `SftpLink.borrowed(session)` di atas sambungan sesi. `SftpBrowserScreen.confirmLeave` false: kembali ke terminal tanpa konfirmasi kecuali ada transfer berjalan. Mekanisme pinjam (kanal ditutup, sambungan sesi tidak; kanal dibuka lagi setelah sambung ulang) sudah ada dan dites dari 11p. Tes: tombol di header (ada dan tidak ada), keluar tanpa konfirmasi, keluar dengan transfer.

**Teruji di HP [T]:** dari terminal WSL Uji, ikon folder di header kanan membuka daftar folder rumah seketika, tanpa prompt sidik jari dan tanpa koneksi baru (server: tetap satu `sshd: termul_t@pts/6`, ditambah satu `sftp-server` selama SFTP terbuka); tombol kembali langsung ke terminal yang sama tanpa konfirmasi, `sftp-server` kanal itu hilang dan sesi tetap hidup. **Belum teruji di HP:** transfer berjalan lalu kembali (konfirmasi), terminal putus lalu tersambung ulang saat SFTP terbuka.

## 11z. SFTP tanpa tab: sesi mandiri, menu host, ikon sftp (2026-10-17)

**Selesai (490 tes), jalur utama teruji di HP [T]. Prototipe versi 52 (`1792238240-c187`; contoh baru 1d dan 4n; `Main`, `MainLandscape`, `Terminal`, `Sessions` diperbarui), design system versi 52 (`1792238242-ec7d`; README, `NavBar`, `Icon`).**

Keputusan pemilik: tab SFTP dihapus, semua sesi aktif di Sesi, SFTP dibuka dari menu tekan lama host atau dari terminal. Rencana disetujui pemilik dengan tiga irisan (potret 11x, SFTP dari terminal 11y, ini).
- **Ikon:** ikon `sftp` (folder berpanah naik-turun) menggantikan folder polos di header terminal dan di aksi menu host (pemilik tidak bisa membedakan folder SFTP dari folder di HP).
- **`SftpSessionManager`** (`sftp_session_manager.dart`): sesi SFTP mandiri (`SftpSession`: id, nomor urut, profil, `SftpLink`) yang dibiarkan hidup; `create`, `take`, `keep`, `release`, `disconnectAllKept`. Didaftarkan ke foreground service (id negatif, nama "profil · SFTP"), jadi "Pertahankan koneksi", notifikasi, dan "Putuskan semua" berlaku. `SftpLink.resumePath` menyimpan folder terakhir (praktis folder awal, karena sheet keluar hanya muncul di folder awal).
- **Sheet keluar sesi mandiri:** Tetap terhubung di latar belakang (utama), Putuskan, Batal; saat ada transfer: Tetap terhubung (transfer lanjut), Batalkan transfer dan keluar, Batal; banner `warn` bila "Pertahankan koneksi" mati. Transfer batch tidak berhenti saat layar ditutup (pemeriksaan `mounted` dihapus setelah transfer mulai). Sambungan pinjaman (dari terminal) dan tes tetap memakai sheet lama.
- **Menu host:** "Sambung SFTP" (profil agen yang belum lengkap diarahkan ke dialog yang sama dengan terminal). **Sesi:** baris sesi SFTP dengan chip "SFTP", status berkata sama, tombol putuskan, "Putuskan semua" dan lencana tab menghitung keduanya. **Tab SFTP dan `SftpScreen` dihapus**; `NavBar` empat tab.
- **Tes:** menu host, tidak ada tab SFTP, sheet keluar (Tetap terhubung, Putuskan, transfer), sesi di tab Sesi dan dibuka lagi, putuskan dari Sesi (foreground service ikut), tab-tab diperbarui.
- **Teruji di HP [T]:** tekan lama WSL Uji menampilkan "Sambung SFTP" dengan ikon baru; Sambung SFTP tersambung dan membuka daftar folder; sheet keluar tampil; Tetap terhubung memunculkan baris "WSL Uji [SFTP] Tersambung" di Sesi dengan lencana tab 1, dan di server `sshd: termul_t@notty` dan `sftp-server` tetap hidup; Home 45 detik lalu buka lagi: koneksi masih hidup (`KeepAliveService` berjalan) dan baris sesi membuka penjelajah lagi tanpa login; Putuskan menutup koneksi di server dan mengosongkan Sesi.
- **Putuskan merah (permintaan pemilik):** tombol Putuskan di sheet keluar SFTP mandiri kini `danger` (merah) seperti di terminal, juga tanpa transfer berjalan; contoh 4n dan README diperbarui (prototipe versi 53, design system versi 53).
- **Belum teruji di HP:** transfer yang berjalan saat sesi di latar belakang, layar mati lama, sambung ulang otomatis sesi SFTP kept setelah soket diputus Android, banyak sesi SFTP ke host yang sama. Teks Sesi kosong sudah diperbarui menyebut terminal dan SFTP ("Tekan kembali di terminal atau SFTP ...").

## 11aa. Vault terbuka: chip di daftar host dan saklar "Jangan kunci vault" (2026-10-17)

**Selesai di PC (510 tes, `flutter analyze` bersih); jalur utama teruji di HP [T] (lihat hasil uji di bawah). Versi artifact terkini: prototipe versi 55 (`1792241978-2960`; awalnya versi 54 `1792240210-8f47`: `Main` dengan prop `vault`, `Settings` dengan saklar, contoh baru 1e `MainVaultOpen`; versi 55: saklar menjadi zona bahaya merah) dan design system versi 55 (`1792241980-78c8`; awalnya versi 54 `1792240223-1474`: README "Vault terbuka" dan ikon `lock-open`; versi 55: README zona bahaya).**

Permintaan pemilik: chip "Vault terkunci" di prototipe bisa dibuka supaya terminal tersambung tanpa biometrik atau PIN, dan opsinya ada di Pengaturan. Rencana disetujui pemilik, cakupan "Keduanya" (buka sementara lewat chip, dan permanen lewat Pengaturan).

**Keputusan pemilik (2026-10-17) yang melonggarkan butir "Rahasia" di CLAUDE.md:** (1) buka sementara: satu kali autentikasi, lalu sambung tanpa prompt sampai layar mati atau aplikasi ditutup; (2) permanen: saklar "Jangan kunci vault" membuat rahasia dibaca tanpa autentikasi apa pun. Risiko yang diterima pemilik: HP yang hilang atau dipegang orang lain saat terbuka bisa menyambung ke semua server. Penyimpanan tidak berubah (Keystore, terenkripsi): gerbang biometrik ada di aplikasi (`_gate` di `KeystoreCredentialVault`), kunci Keystore tidak terikat autentikasi, jadi tidak ada rahasia yang ditulis ulang.

- **`VaultLock`** (`core/vault/vault_lock.dart`, `ChangeNotifier`): `unlock` (satu `DeviceAuth.authenticate`, lalu mencatat penghitung layar mati), `lock`, `isOpen` (selalu terbuka, atau terbuka sementara dan penghitung layar mati belum berubah; penghitung tidak terbaca berarti terkunci), `alwaysOpen`, `refresh` (dipanggil saat aplikasi `resumed`). Layar mati mengunci lewat peristiwa langsung dan perbandingan penghitung `ScreenMonitor` yang sama dengan 11f, jadi tetap benar walau Dart dibekukan. Dibuat di `bootstrap()` dan disuntikkan lewat `vaultLockProvider`; bawaan di tes memakai autentikasi yang selalu ditolak (tetap terkunci).
- **`KeystoreCredentialVault._gate`:** setelah pemeriksaan `AuthLevel.none`, `if (await _lock?.isOpen() ?? false) return;`. Hanya pembacaan untuk sambung yang dilonggarkan (satu-satunya pembacaan rahasia di aplikasi saat ini).
- **Pengaturan:** bagian baru `security` di `settings.json` (`vaultAlwaysOpen`, bawaan mati; `SecuritySettings`). Saklar di Pengaturan > Keamanan: menyalakan menampilkan sheet peringatan (Batal tombol utama, "Jangan kunci" `danger`), lalu satu autentikasi lewat `AuthGate`; dibatalkan berarti tetap mati dan tidak tersimpan. Mematikan langsung berlaku. `VaultLock.alwaysOpen` diisi dari `settings.json` saat mulai dan diubah bersama saklar.
- **Chip** (`features/hosts/vault_chip.dart`, di header Host potret): "Vault terkunci" (gembok, `ink-muted`) atau "Vault terbuka" (gembok terbuka, `accent`). Ketuk saat terkunci: prompt satu kali (lewat `AuthGate`, jadi tidak bertabrakan dengan sesi), toast "Vault terbuka sampai layar mati" atau "Vault tetap terkunci". Ketuk saat terbuka sementara: mengunci lagi. Mode permanen: ketuk hanya memberi toast keterangan. Ikon baru `lockOpen`.
- **Tidak dikerjakan:** chip di layout landscape (landscape tidak aktif, 11x). Streak chip di header Host juga belum ada di aplikasi (di prototipe sudah). Pada HP tanpa penguncian layar (`AuthLevel.none`) gerbang memang sudah tanpa prompt, chip tetap bisa diketuk.
- **Tes baru:** `vault_lock_test.dart` (gerbang terkunci, buka sementara satu prompt, batal atau galat, layar mati lewat peristiwa dan lewat penghitung, penghitung gagal, `lock`, selalu terbuka, `SecuritySettings`), `vault_chip_test.dart` (chip membuka dan mengunci, batal, mode permanen, saklar: peringatan lalu prompt lalu tersimpan, batal di prompt, batal di peringatan, mematikan).
- **Hasil uji HP (2026-10-17, Xiaomi 25053PC47G, lewat adb dengan izin pemilik; prompt disentuh pemilik) [T]:** chip "Vault terkunci" tampil di header; ketuk memunculkan satu prompt sistem, lalu chip menjadi "Vault terbuka" (ikon terbuka, aksen); sambung ke WSL Uji **tanpa prompt** (fokus tetap di aplikasi); layar dimatikan lalu dinyalakan (jeda 4 detik): chip kembali "Vault terkunci"; saklar Pengaturan > Keamanan tampil, ketuk memunculkan sheet "Jangan kunci vault?" (Batal utama), "Jangan kunci" memunculkan satu prompt, lalu `settings.json` berisi `security.vaultAlwaysOpen: true`; chip menjadi "Vault terbuka" (permanen), layar mati-nyala tidak mengunci, sambung tanpa prompt; saklar dimatikan tanpa prompt dan `settings.json` kembali `false` (HP dikembalikan ke keadaan semula, sesi diputus).
- **Zona bahaya merah (permintaan pemilik, 2026-10-17):** baris saklar "Jangan kunci vault" memakai varian `SwitchRow(dangerTag: ...)`: latar `bad-bg`, tepi `bad-line`, tag kata "Berisiko" di samping label, keterangan `bad-ink`, sakelar menyala `bad`. Prototipe `Settings` versi 55 (`1792241978-2960`; saklar dipindah ke blok merah di bawah kartu Keamanan) dan design system versi 55 (`1792241980-78c8`; README). Dirender di Chrome dan dilihat di HP [T] (tampilan saja; fungsi saklar sudah teruji di atas). Satu tes Pengaturan disesuaikan (menggulir ke saklar karena daftar lebih panjang).
- **Belum teruji di HP:** layar mati lama saat proses dibekukan di HyperOS (hanya jeda 4 detik yang dicoba), ketuk chip untuk mengunci kembali, prompt dibatalkan, tampilan chip di lebar sempit, dan tanpa penguncian layar. Tugas CLAUDE.md butir "Rahasia" sudah diberi catatan keputusan ini.

## 11ab. Impor profil dari `profiles.json` desktop (2026-10-17)

**Selesai di PC (538 tes, `flutter analyze` bersih); jalur utama teruji di HP [T] (hasil uji di bawah). Versi artifact: prototipe versi 56 (`1792242991-46d1`: `Main` dengan tombol impor, contoh baru 1f `HostImport`) dan design system versi 56 (`1792243006-2190`: README).**

Permintaan pemilik: fitur impor profil di TermUL Mobile. Sampel berkas dari desktop (23 profil, hampir semuanya `AGENT`, satu jump host, `groups`, `favorites`, `recent`) diberikan pemilik; rencana disetujui dengan syarat **impor tidak boleh menghilangkan profil yang sudah ada di HP**.

- **Format:** `profiles.json` desktop apa adanya (objek dengan `version`, `groups`, `profiles`, `favorites`, `recent`) atau daftar profil polos. Berkas ekspor lain (mis. `~/.ssh/config`) tidak didukung.
- **`ProfileImportSource.parse`** (`core/import/profile_import.dart`): membaca per entri, jadi satu profil rusak (port di luar rentang, host kosong, id ganda, bukan objek) dilaporkan di `rejections` dan sisanya tetap diimpor. Bukan JSON atau bentuk salah melempar `ImportFormatException`. Id favorit/recent yang bukan UUID dibuang diam-diam.
- **`plan(existing, policy)`** murni (tidak menulis): menggabungkan ke snapshot yang ada tanpa pernah membuang apa pun darinya. Profil baru ditambahkan; id sama ditangani lewat `ImportConflictPolicy`: `skip` (bawaan, profil di HP tidak disentuh), `update` (isi diganti; rahasia di vault tetap karena terkait id), `copy` (id baru, nama "(salinan)"). Grup, favorit, dan recent digabung (yang lama tetap, batas `recent` lima). Favorit profil yang dilewati tidak mengubah favorit di HP. Jump host mengikuti pemetaan id (salinan menunjuk salinan); yang tidak ada di berkas maupun HP dikosongkan dengan peringatan. `KEY` dengan path perangkat asal: path dibuang dengan peringatan (kunci diimpor lagi di HP; menutup catatan 3.2). Profil `AGENT` tetap tersimpan dan, saat diketuk, memunculkan panel "Perlu dilengkapi" yang sudah ada; pratinjau menyebut jumlahnya.
- **`HostRepository.update`** (baru): menghitung dari keadaan terkini di dalam kunci tulis dan menulis sekali secara atomik, jadi penggabungan tidak memakai salinan usang. `HostService.importProfiles` memakainya; vault tidak disentuh (profil impor tidak membawa rahasia).
- **UI:** tombol ikon `download` ("Impor profil", varian plain) di sebelah tombol tambah di header Host (hanya potret). Alur di `features/hosts/profile_import_flow.dart`: pemilih berkas (`ProfileFilePicker`, `file_selector`, tanpa filter jenis berkas karena `.json` kadang dilaporkan `octet-stream`; batas 2 MB), panel pratinjau dengan `Segmented` Lewati/Perbarui/Salinan yang menghitung ulang ringkasan, peringatan, dan maksimal 5 entri ditolak; Batal atau Impor; toast "Diimpor · N profil". Galat (bukan JSON, tanpa profil valid, berkas terlalu besar) tampil di banner daftar host dan tidak mengubah apa pun.
- **Tes baru:** `test/core/import/profile_import_test.dart` (20: parsing, entri rusak, setiap kebijakan tidak mengurangi profil lama, grup, favorit, recent, jump host, path kunci, agen, penulisan ke disk dan muat ulang) dan `test/features/profile_import_screen_test.dart` (8: alur lengkap, pilihan id sama, Batal, pemilih dibatalkan, galat, agen). Tes memakai data buatan (IP dokumentasi), bukan berkas desktop pemilik.
- **Desain:** tambahan, bukan penyimpangan. README (bagian "Catatan dari implementasi Flutter") memuat bulir "Impor profil"; prototipe `Main` mendapat tombol, contoh 1f menampilkan panel pratinjau.
- **Belum dikerjakan:** (ekspor sudah dikerjakan di 11ad); tombol impor di layout landscape (landscape tidak aktif, 11x); tombol impor di keadaan daftar kosong; mengganti nama grup yang bentrok. Sidik jari host key lama untuk profil yang `update`-nya mengubah host:port tidak dibersihkan (host baru memakai sidik jari baru; sisa lama tidak berbahaya).
- **Hasil uji HP (2026-10-17, Xiaomi 25053PC47G, lewat adb dengan izin pemilik) [T]:** dengan berkas sampel pemilik (23 profil, direkonstruksi dari kiriman pemilik, ditaruh di Unduhan lalu dihapus lagi) dan 3 profil yang sudah ada di HP: pemilih berkas Android terbuka dan menemukan `.json` lewat pencarian; berkas 42 MB (`uji_besar.bin`) yang terpilih tanpa sengaja memunculkan banner "Berkas terlalu besar untuk daftar profil." dan daftar tidak berubah; pratinjau "23 profil baru ditambahkan" dan "22 profil memakai agen SSH"; Impor menghasilkan toast "Diimpor · 23 profil", `profiles.json` di HP berisi 26 profil (3 lama utuh), jump host `gapura08 jumphost` tetap menunjuk `rekon public`, favorit lama di depan lalu favorit impor, recent lama di depan dan dibatasi lima, tanpa path kunci; impor ulang berkas yang sama: "23 profil dilewati karena sudah ada" (Lewati), "23 profil disimpan sebagai salinan" (Salinan, dibatalkan), "23 profil diperbarui" (Perbarui, ditulis: tetap 26 profil, id unik semua); mengetuk profil agen hasil impor membuka panel "Perlu dilengkapi". Profil hasil impor tetap ada di HP uji.
- **Belum teruji di HP [?]:** tampilan panel di lebar sempit, berkas JSON rusak atau bukan JSON di HP (diuji di PC), dan profil `KEY` dengan path perangkat asal (sampel tidak memuatnya; diuji di PC).

## 11ac. Penanda favorit di baris host (2026-10-17)

**Selesai di PC (540 tes, `flutter analyze` bersih); tampil di HP [T]. Versi artifact: prototipe versi 57 (`1792243645-bba9`: `Main` dengan bintang di host favorit) dan design system versi 57 (`1792243651-17e1`: README dan `HostRow/README.md`).**

Permintaan pemilik: host favorit diberi ikon favorit. Sebelumnya favorit hanya terlihat lewat filter "Favorit" dan menu tekan lama. Ini tambahan, bukan penyimpangan: desain belum punya penanda di baris.

- **`HostRow`** (`shared/widgets/host_row.dart`): prop baru `favorite` (bawaan salah). Bintang terisi `accent` 14 dp (ikon `star`, `filled`) di kanan nama; nama dipotong dengan elipsis sedangkan bintang tetap terlihat. Nama semantik baris memuat kata "Favorit" setelah nama (status tidak hanya lewat bentuk atau warna). String baru `hostFavoriteLabel`.
- **Daftar host** meneruskan `favorites` dari snapshot ke `HostRow`, jadi bintang ikut berubah saat aksi "Jadikan favorit" atau "Hapus dari favorit".
- **Tes baru (2):** bintang hanya di host favorit dan hilang atau muncul saat favorit diubah lewat menu; nama sangat panjang tidak meluap.
- **Hasil uji HP (2026-10-17, lewat adb) [T]:** filter Favorit menampilkan "Development Gapura08" dan "gapura08" masing-masing dengan bintang beraksen di kanan nama.
- **Belum teruji di HP [?]:** tampilan bintang di semua baris (yang bukan favorit tidak berbintang) pada daftar penuh, dan pembaca layar membaca kata "Favorit".

## 11ad. Ekspor profil lewat menu bagikan Android (2026-10-17)

**Selesai di PC (549 tes, `flutter analyze` bersih); menu bagikan dan isi berkas teruji di HP [T] (hasil di bawah). Versi artifact: prototipe versi 58 (`1792244310-e3de`: `Main` dengan tombol ekspor, contoh baru 1g `HostExport`) dan design system versi 58 (`1792244312-8344`: README).**

Permintaan pemilik: fitur ekspor profil; lalu "langsung saja buat opsi bagikan ketika di export, dan gunakan opsi bagikan dari Android itu sendiri". Keputusan pemilik: profil `KEY` ditulis sebagai `AGENT` di berkas ekspor (opsi A), semua profil diekspor.

- **`ProfileExporter`** (`core/import/profile_export.dart`): `ProfileSnapshot` menjadi teks `profiles.json` skema desktop (`version`, `groups`, `profiles`, `favorites`, `recent`). Tidak ada rahasia (model profil tidak membawanya). Profil `KEY` (kunci di vault HP, tanpa path) ditulis sebagai `AGENT` tanpa `privateKeyPath`, karena desktop menolak seluruh berkas bila ada `KEY` tanpa path (menutup risiko di 3.2); dihitung di `keyConverted` dan disebut di panel. Metode di HP tidak berubah. Ekspor lalu impor ke HP kosong menghasilkan profil, grup, favorit, dan recent yang sama.
- **Menu bagikan, tanpa dependensi baru:** `FileSharer.kt` (`Intent.ACTION_SEND` lewat `Intent.createChooser`, content URI dari `androidx.core.content.FileProvider`, izin baca sementara, `clipData`), channel `io.github.egateza.termul/share` di `MainActivity`, `FileProvider` di manifest (`${applicationId}.fileprovider`, tidak diekspor) dengan `res/xml/share_paths.xml` yang hanya membuka `cache/share/`. Sisi Dart: `core/platform/file_sharer.dart` (`FileSharer`, `MethodChannelFileSharer`, `ShareException`) dan `fileSharerProvider`. Tanpa paket baru (FileProvider bagian dari AndroidX yang sudah dipakai Flutter), jadi tidak ada lisensi baru untuk dicek.
- **Alur** (`features/hosts/profile_export_flow.dart`): tombol ikon `upload` "Ekspor profil" di kiri tombol impor; `BottomSheet` konfirmasi (jumlah profil, catatan tanpa rahasia, catatan profil `KEY` yang diubah); Batal atau Bagikan. Bagikan menulis `cache/share/termul-profiles.json` (sisa ekspor sebelumnya dibuang lebih dulu) lalu membuka menu bagikan. Tanpa toast sesudahnya: aplikasi tidak tahu tujuan yang dipilih. Daftar kosong atau menu bagikan gagal dibuka menampilkan banner di daftar host. Penyimpanan ke Unduhan/TermUL tidak dipakai untuk ekspor (menu bagikan Android sudah menawarkan simpan ke penyimpanan).
- **Tes baru (11):** `profile_export_test.dart` (5: skema, tanpa rahasia, `KEY` menjadi `AGENT`, kosong, bolak-balik dengan impor) dan `profile_export_screen_test.dart` (4: panel dan berkas yang dibagikan, Batal, daftar kosong, menu bagikan gagal).
- **Hasil uji HP (2026-10-17, Xiaomi 25053PC47G, lewat adb dengan izin pemilik) [T]:** panel "26 profil akan diekspor"; Bagikan membuka menu bagikan Android dengan berkas `termul-profiles.json` (tanpa mengirim ke tujuan mana pun); isi `cache/share/termul-profiles.json` di HP valid: 26 profil (21 `AGENT`, 5 `PASSWORD`), 2 grup, 2 favorit, 5 recent, hanya kunci profil yang dikenal desktop.
- **Belum teruji di HP [?]:** menyimpan atau mengirim berkas lewat tujuan sungguhan lalu membukanya di aplikasi tujuan (Drive, WhatsApp, "Simpan ke berkas") dan mengimpornya kembali di HP lain; memuatnya di TermUL desktop; profil `KEY` sungguhan di HP (hanya diuji di PC); tampilan panel di lebar sempit.
- **Catatan:** `cache/share/` berisi nama host dan username (bukan rahasia) sampai ekspor berikutnya atau sampai Android membersihkan cache; bila ini dianggap sensitif, berkas bisa dihapus setelah `onResume` berikutnya (belum dikerjakan).

## 11ae. Snippet: daftar, detail, editor, kategori, urutan, dan penanda berbahaya (2026-10-17, irisan 1 dan perluasannya)

Tab Snippet tidak lagi layar sementara "Belum tersedia" (`ComingSoonScreen` dan teks `comingSoon*` dihapus). Rancangan dasar mengikuti prototipe 7 (`Snippets.dc.html`, `SnippetNew.dc.html`); perluasan di bawah datang dari permintaan pemilik selama pengerjaan.

**Keputusan pemilik (2026-10-17):** cakupan snippet "Semua host atau satu host"; mulai kosong tanpa snippet contoh; kategori awalnya Sistem, Nginx, Docker, Database tetapi **kategori buatan pengguna** (tambah, ubah nama, hapus, urutkan) menggantikan keputusan awal "kategori tetap"; penanda perintah berbahaya dengan peringatan sebelum dipakai; urutan kategori dan urutan snippet bisa diatur dengan menggeser; kata "berbahaya" dipakai (bukan "berisiko") di tag dan peringatan snippet.

### Yang sudah dibangun

- **Data (`core/`):** `Snippet` (`models/snippet.dart`: judul, perintah beberapa baris, `categoryId` nullable, `hostId` nullable = semua host, favorit, `dangerous`, nilai bawaan variabel; variabel `${nama}` huruf kecil dan garis bawah) dan `SnippetCategory` (id stabil dan nama, maksimal 24 karakter, unik tanpa membedakan huruf). `SnippetLibrary` (`models/snippet_library.dart`) memegang kategori dan snippet serta menjaga aturannya (id unik, snippet yang menunjuk kategori hilang dilepas, pindah dan hapus). `SnippetRepository` (`storage/`) dengan `JsonSnippetRepository` (`snippets.json` di folder pribadi aplikasi, ditulis atomik, berkas rusak disisihkan seperti `profiles.json`) dan `MemorySnippetRepository` (nilai bawaan provider dan tes). Bukan rahasia, jadi tidak lewat Keystore.
- **Format `snippets.json` versi 2:** `{"version": 2, "categories": [...], "snippets": [...]}`; berkas versi 1 (tanpa `categories`, `category` berisi `sistem`/`nginx`/`docker`/`database`) terbaca tanpa migrasi karena kategori awal memakai id lama. `categories` kosong tetap kosong setelah dimuat ulang. Menghapus host memanggil `clearHost` (snippet-nya jatuh ke "semua host"; bila gagal, daftar tetap menampilkannya sebagai "Semua host").
- **Daftar (`features/snippets/snippets_screen.dart`):** kolom cari, chip Semua, Favorit, dan kategori pengguna (baris bisa digulir), kartu (judul, bintang, baris pertama, tag kategori, cakupan, jumlah variabel, tag "berbahaya"), keadaan kosong, banner "Daftar snippet rusak". Header: urutkan, kelola kategori, snippet baru.
- **Detail (`snippet_detail_sheet.dart`):** isian variabel, pratinjau perintah, banner bila berbahaya, **Salin** ke papan klip, Edit, dan Hapus (ikon tempat sampah).
- **Editor (`snippet_editor_sheet.dart`):** judul, perintah beberapa baris, kategori (chip "Tanpa kategori" dan kategori pengguna, dengan ikon pensil kelola kategori di baris labelnya), cakupan (chip "Semua host" dan pil "Satu host" yang membuka daftar host), favorit, saklar berbahaya, dan Hapus. Editor membaca kategori dari `snippetLibraryProvider`: perubahan lewat pengelola (dibuka di atas editor tanpa menutupnya) langsung tampil, kategori baru langsung terpilih, kategori terpilih yang dihapus menjadi "Tanpa kategori".
- **Pengelola kategori (`snippet_category_sheet.dart`):** sheet berisi daftar kategori dengan jumlah snippet, pegangan geser untuk urutan, ikon ubah nama dan hapus, tombol Kategori baru; sheet nama (galat "sudah dipakai" dan "terlalu panjang"). Hapus kategori memindahkan snippet-nya ke "Tanpa kategori" (tidak ikut terhapus; konfirmasi menyebut jumlahnya; satu penulisan berkas); filter yang menunjuk kategori terhapus kembali ke Semua. Urutan kategori dipakai chip filter, chip editor, dan kategori awal snippet baru.
- **Mode mengurutkan snippet:** tombol ikon dua panah di header (hanya bila snippet dua atau lebih) menampilkan semua snippet sebagai baris ringkas dengan pegangan geser (pencarian dan filter disembunyikan lalu kembali seperti semula); tombol berubah menjadi centang "Selesai mengurutkan". Tiap baris punya ikon hapus. Mode berakhir sendiri bila snippet tinggal satu. Snippet baru tetap muncul di paling atas.
- **Hapus snippet:** tiga jalur (form edit, ikon di detail, ikon di baris mode urut), semuanya lewat konfirmasi "Hapus {judul}?".
- **Perintah berbahaya (`snippet_danger.dart`):** berbahaya = ditandai pemilik (`Snippet.dangerous`, saklar merah "Tandai sebagai perintah berbahaya" di editor) **atau** terdeteksi otomatis (`PasteAnalysis.isRisky`: rm -rf, dd, mkfs, dan sejenisnya, dicek pada perintah dengan variabel yang sudah diisi). Akibatnya: tag "berbahaya" di kartu, banner di detail, dan **Salin meminta konfirmasi dulu**: sheet "Perintah berbahaya" dengan peringatan dan isi perintah, Batal sebagai tombol utama dan "Tetap salin" varian bahaya; tanpa konfirmasi tidak ada yang masuk papan klip.
- **Perilaku penting:** (1) geseran memakai urutan sementara (`_pendingOrder`) yang langsung ditampilkan saat dilepas lalu disimpan; tanpa itu baris sempat kembali ke posisi lama menunggu penulisan berkas lalu melompat (glitch temuan pemilik, dibuktikan dengan tes berpenulisan lambat); bila penyimpanan gagal, tampilan kembali ke urutan tersimpan dengan pesan galat. (2) Cincin fokus isian (4 px di luar tepinya) tidak terpotong tepi area gulir: area gulir sheet diberi ruang `snippetRingGutter`. (3) `ReorderableListView` bawaan Flutter dipakai tanpa dependensi baru; bayangan seret dimatikan (tepi 1 px saja).
- **Perubahan bersama:** `TermulTextField` mendapat `minLines` dan `maxLines`; `FilterChipButton` selebar isinya (tidak membentang di `Wrap`); ikon `grip` dan `sort`; `PasteAnalysis.isRisky` dibuka; `snippetRepositoryProvider` (bawaan di memori) dan `snippetLibraryProvider`; `bootstrap` memuat `snippets.json` dan `BootReport.snippets`; l10n: `comingSoon*` dan `snippetCat*` dihapus, string snippet dan kategori ditambah.

### Berbeda dari prototipe dan tanpa padanan di desain

Keputusan pemilik (2026-10-17): semuanya masuk ke artifact (prototipe dan README); ringkasan perbedaan terhadap prototipe 7 yang semula:

- **Berbeda:** (1) detail dari tab memakai **Salin** ke papan klip, bukan "Kirim ke", "Tempel ke <host>", dan "Tempel & jalankan" (keputusan pemilik 2026-10-17: dihapus; menempel hanya lewat panel di terminal); (2) "Berlaku untuk" memakai pil "Satu host" yang membuka daftar host, karena prototipe hanya punya dua host contoh; (3) kategori bisa diubah pengguna, prototipe memakai empat kategori tetap; (4) tag memakai kata "berbahaya", prototipe "berisiko"; (5) nilai bawaan variabel dibaca dari berkas tetapi belum bisa diisi di editor (prototipe juga tidak menyediakannya).
- **Tanpa padanan:** keadaan kosong (judul, ajakan, tombol), tombol Hapus (editor, detail, mode urut) beserta konfirmasi, banner "Daftar snippet rusak", pengelola kategori (tambah, ubah nama, hapus, urutan) dan ikon kelola di editor, chip "Tanpa kategori", mode mengurutkan snippet, saklar berbahaya, dan sheet peringatan sebelum Salin.

### Tes

`flutter analyze` bersih, **672 tes lulus (2 dilewati)** setelah irisan 2 dan penghapusan "Kirim ke" (659 sebelum irisan 2), naik dari 549 sebelum fitur ini. Berkas baru: `snippet_test.dart`, `snippet_library_test.dart`, `snippet_library_order_test.dart`, `snippet_order_test.dart`, `json_snippet_repository_test.dart`, `snippet_list_model_test.dart`, `snippets_screen_test.dart`, `snippet_category_order_test.dart`, `snippet_sort_test.dart`; `main_shell_test.dart` disesuaikan. Hal yang sengaja dibuktikan: tes cincin fokus gagal bila ruang `snippetRingGutter` dihapus (16 px lawan 20 px); tes glitch memakai repository berpenulisan lambat (`SlowRepo`) dan gagal sebelum perbaikan; migrasi berkas versi 1; penulisan gagal tidak mengubah keadaan. Catatan teknis tes geser: `ReorderableListView` perlu frame bertahap (`pumpFor`), `pumpAndSettle` tidak menunggu timer, dan `enterText` perlu `pump` sebelum mengetuk tombol yang bergantung padanya.

### Hasil uji HP (2026-10-17, Xiaomi 25053PC47G, build profile, lewat adb dengan izin pemilik) [T]

Keadaan kosong; editor dengan keyboard terbuka (Batal/Simpan tetap terlihat, cincin fokus utuh); simpan, kartu, dan toast; detail (Salin nonaktif selagi variabel kosong, pratinjau mengikuti isian, toast "Disalin · 22 karakter"); persistensi setelah aplikasi ditutup paksa; migrasi berkas versi 1 yang berisi snippet buatan pemilik; pengelola kategori (tambah "Jaringan", tampil di editor, hapus dengan konfirmasi); geser kategori dengan swipe nyata (chip filter ikut berubah); ikon kelola di editor; saklar berbahaya, tag, banner, dan sheet peringatan dengan Batal sebagai tombol utama; mode urut snippet (swipe nyata, urutan bertahan setelah tutup paksa); ikon hapus di detail dan baris mode urut, penghapusan snippet uji "Restart nginx" dengan toast; logcat tanpa galat. Temuan yang sudah diperbaiki: chip membentang selebar layar, cincin fokus terpotong, dan glitch saat mengubah urutan kategori.

### Belum teruji di HP [?]

Tombol "Tetap salin" dan isi papan klip sesudah Salin (tempel lewat `KEYCODE_PASTE` tidak memunculkan teks di kolom Flutter, jadi tidak terbukti lewat adb); ubah nama kategori dan hapus kategori berisi snippet; edit snippet; cakupan satu host; filter dan cari dengan banyak snippet; banner berkas rusak. **Rasa mulus geseran** (kategori dan snippet) hanya dinilai dari tangkapan layar dan tes, bukan rekaman (tidak ada ffmpeg di mesin ini); perlu dicoba langsung oleh pemilik. Layar hanya potret.

### Irisan 2: menempel snippet ke terminal (2026-10-17)

Pemilik memilih kedua jalur. Terminal mengikuti prototipe 2 (tombol Snippet di bilah dan panel), sehingga jalur yang saya buat lebih dulu (tombol di baris tombol dan pemilih lembar) diganti.

- **Tujuan tempel (`features/snippets/snippet_target.dart`):** `SnippetTarget` (id, label, `send`). `sessionTarget` membersihkan teks seperti tempel dari papan klip (`PasteAnalysis`: karakter kontrol berbahaya dibuang, baris baru menjadi Enter, dibungkus tempel aman hanya bila server menyalakannya); "jalankan" menambah satu Enter (baris baru di ujung perintah tidak menggandakannya). ~~`keptSessionTargets` memilih sesi di latar belakang~~ (dihapus bersama "Kirim ke"); `sessionLabel` memberi nama seperti di tab Sesi (nomor sesi bila ada beberapa sesi ke host yang sama).
- **Dari tab Snippet:** ~~tempel ke sesi di latar belakang~~ **dihapus atas permintaan pemilik (2026-10-17)**: "Kirim ke", Tempel ke {sesi}, dan Tempel & jalankan tidak ada lagi di detail dari tab (terasa aneh); `keptSessionTargets` dan string `snippetTargetLabel`/`snippetNoTargets` dibuang. Detail dari tab: Edit, Salin (tombol utama), Hapus. Sheet detail yang sama dari terminal tetap punya Tempel ke sesi ini dan Tempel & jalankan, kini tanpa baris chip "Kirim ke".
- **Dari terminal:** ikon Snippet tetap di kiri bilah tombol cepat (menyala bila panel terbuka); `SnippetPanel` (240 dp di bawah bilah, menyembunyikan keyboard sistem selama terbuka) menampilkan snippet untuk semua host atau host ini: judul, baris pertama, dan "berbahaya". **Ketuk** menempel lewat alur tempel terminal (`_pasteText`, refaktor dari `_paste`): satu baris aman langsung masuk ke prompt, banyak baris atau berisiko ditampilkan dulu; snippet **berisi variabel** membuka detail untuk diisi; snippet **ditandai berbahaya** meminta peringatan dulu; **tekan lama** membuka detail (Tempel & jalankan, Salin); **Kelola semua** membuka tab Snippet. `showSnippetDangerSheet` dipakai bersama detail dan terminal.
- **Perilaku perintah berbahaya:** "Tempel & jalankan" nonaktif untuk perintah berbahaya (ditandai atau terdeteksi), dan Tempel serta Salin meminta peringatan dulu dengan Batal sebagai tombol utama.
- **Tes:** `snippet_paste_test.dart` (semula 17, kini 13 sesudah grup "dari tab" disusutkan menjadi satu tes tanpa "Kirim ke": panel dan ikon, snippet untuk host ini saja, keadaan kosong, tempel cepat, banyak baris, risiko otomatis, tanda berbahaya, variabel, tekan lama, Tempel & jalankan dengan Enter tunggal, karakter kontrol dibuang, Kelola semua; dari tab: hanya Salin dan Edit walau ada sesi di latar belakang) memakai jaringan dan shell palsu dari `reconnect_test.dart` dan memeriksa byte yang terkirim. Hasil: `flutter analyze` bersih, 672 tes lulus (2 dilewati).
- **Teruji di HP [T]:** panel di terminal, ketuk snippet berisi variabel, isi variabel, dan Tempel ke sesi (profil "WSL Uji"); rincian di "Perubahan setelah Irisan 2". **Belum teruji di HP [?]:** Tempel & jalankan di sesi nyata, ketuk snippet satu baris yang aman (tempel cepat), tekan lama, keyboard sistem tersembunyi dan muncul lagi saat panel ditutup, dan peringatan snippet berbahaya di terminal.

### Belum dikerjakan

- **Irisan 3:** "Simpan sebagai snippet" di bilah seleksi terminal (prototipe 7b; `showSnippetEditor` sudah menerima `initialCommand`).
- Mengisi nilai bawaan variabel di editor (sekarang hanya bisa dibaca dari berkas).

### Sinkron desain

**Sudah (2026-10-17):** prototipe versi 59 (`1792250992-35d1`) dan design system versi 59 (`1792251008-13ee`), lalu versi 60 untuk keduanya (lihat "Perubahan setelah Irisan 2"); rincian di `docs/design/SUMBER.md` ("Snippet dibangun"). Semua tambahan di atas masuk ke prototipe (`Snippets`, `Terminal`, contoh 7c sampai 7i dan 2o) dan README (butir Snippet, ikon `grip` dan `sort`); yang belum bisa sesuai desain dicatat di README: "Simpan sebagai snippet" (7b), nilai bawaan variabel, dan tempel ke sesi yang sedang tampil hanya lewat panel terminal. Kata "berbahaya" menggantikan "berisiko" di tag dan peringatan snippet atas keputusan pemilik. Papan 13 (`ComingSoon`) di prototipe sudah tidak dipakai aplikasi tetapi dibiarkan di kanvas.

### Perubahan setelah Irisan 2 (2026-10-17)

- **Kirim ke dihapus dari tab Snippet** (lihat di atas). Tempel ke sesi hanya lewat panel snippet di terminal.
- **Tombol Snippet di bilah tombol cepat:** tetap paling kiri dan ikon saja, kini ikonnya **kuning** (nada baru `IconButtonTone.accentIcon`: ikon aksen di atas permukaan terangkat dengan tepi 1 px; menyala penuh saat panel terbuka), sesuai permintaan pemilik.
- Tes: `snippet_paste_test.dart` diganti (grup tab menjadi satu tes: tanpa "Kirim ke" dan tanpa tombol Tempel walau ada sesi di latar belakang); 672 tes lulus (2 dilewati); `flutter analyze` bersih.
- **Teruji di HP [T] (build profile, profil "WSL Uji" lewat `adb reverse`, 2026-10-17):** detail dari tab tanpa "Kirim ke" (hanya Edit dan Salin); di terminal ikon Snippet kuning paling kiri, panel terbuka dan menyala penuh, ketuk snippet berisi variabel membuka detail tanpa chip "Kirim ke", mengisi variabel lalu Tempel ke WSL Uji memasukkan `cp /etc/hostname /tmp/h.txt` ke prompt tanpa Enter dengan toast "Ditempel ke WSL Uji · belum dijalankan". **Belum teruji [?]:** Tempel & jalankan di sesi nyata, isi papan klip sesudah Salin.
- **Desain:** prototipe `Snippets` (detail hanya Edit dan Salin; peringatan contoh 7h memakai "Tetap salin") dan `Terminal` (ikon Snippet kuning) serta README diperbarui; prototipe 60 (`1792251862-a9a1`) dan design system 60 (`1792251864-76ae`), hash terverifikasi; rincian di `docs/design/SUMBER.md`.

## 12. Status terkini dan cara melanjutkan

Terakhir diperbarui: 2026-10-17. **Snippet irisan 1 beserta perluasannya (kategori buatan pengguna, urutan kategori dan snippet, penanda berbahaya, hapus, dan irisan 2 tempel ke terminal; 11ae; sebagian besar teruji di HP kecuali yang memerlukan sesi SSH); 672 tes; prototipe 60, design system 60.** **Ekspor profil lewat menu bagikan Android, profil `KEY` menjadi `AGENT` di berkas (11ad; menu bagikan teruji di HP); 549 tes; prototipe 58, design system 58.** **Penanda favorit (bintang) di baris host (11ac; teruji di HP); 540 tes; prototipe 57, design system 57.** **Impor profil dari `profiles.json` desktop, menggabungkan tanpa menghapus profil yang ada (11ab; jalur utama teruji di HP); 538 tes; prototipe 56, design system 56.** **Vault terbuka (chip, buka sampai layar mati, dan saklar "Jangan kunci vault" berupa zona bahaya merah, 11aa; jalur utama teruji di HP, sisa yang belum teruji tercatat di 11aa); 510 tes; prototipe 55, design system 55.** **SFTP selesai untuk menjelajah, sambung ulang otomatis, unduh, unggah, seleksi ganda, unduh folder, SFTP dari terminal, dan sesi SFTP mandiri tanpa tab (11n sampai 11z; jalur utama teruji di HP); edit berkas, buat folder, ganti nama, dan hapus belum.** Langkah 0 sampai 8 selesai, ditambah `settings.json` dan menu setting (11a), foreground service (11b), tempel (11c), seleksi dan salin teks (11d), sesi di latar belakang (11e), sambung ulang menunggu jaringan (11f), layar pemuatan dan gulir seleksi (11g), `NavBar` lima tab (11h), saklar sambung ulang otomatis (11i), popover Tempel dan saklarnya (11j), dan landscape layar utama (11k). 510 tes lulus (2 dilewati), `flutter analyze` bersih. **Dua perbaikan landscape (banner status sambungan dan label profil, 11l; form host dengan keyboard, 11m) teruji di HP dan artifact desainnya sudah diperbarui.** Irisan pertama (daftar host, sambung dengan verifikasi host key, terminal, sambung ulang) berjalan di emulator terhadap server SSH sungguhan dan di HP fisik. Menu setting dan seleksi sudah dicoba di HP dan sesuai.

**Sudah diuji di HP (2026-10-16):** foreground service (`Destroyed live tcp sockets` tidak muncul lagi dengan saklar menyala, sambungan bertahan sekitar 9 menit), sesi di latar belakang, multi sesi, Putuskan semua, dan putus serta pulih saat mode pesawat; rincian dan batasnya di "Hasil uji HP" (11e). **Tempel (11c, 11j) dan landscape (11k) sudah dicoba di HP lewat adb (2026-10-16).** **Landscape: banner, label profil, form host, pencarian, dan dropdown teruji di HP (2026-10-17).** **Teruji di HP 2026-10-17:** tempel isi papan klip panjang (91 baris), "Putuskan semua" dari notifikasi, dan layar mati sekitar 25 menit (sesi tetap hidup; HP masih tercolok kabel). **Belum diuji di HP:** layar mati 30 menit atau lebih tanpa kabel, efek HyperOS. Sisa uji HP lama: Home 13 detik dan 5 menit, Wi-Fi mati dan Wi-Fi ke seluler, impor kunci lewat pemilih berkas, sidik jari, PIN dan sandi, `vim` dan `tmux`, hasil sambung ulang di HP, HP tanpa kunci layar (`none`), `keyboard-interactive`, animasi keyboard (belum diukur).

**Keputusan yang berlaku:** sesi persisten `tmux` otomatis tidak dibuat (di luar kebiasaan klien SSH; penangkalnya foreground service dan sekarang "Tetap terhubung"). Warna seleksi terminal: warna sementara diterima pemilik (11d). Desain sistem dan prototipe diikuti, tidak diubah agar cocok dengan kode: tambahan masuk ke artifact, yang belum bisa diterapkan hanya diberi catatan di README (`CLAUDE.md` butir 8). Belum bisa sesuai desain, dicatat di README: petunjuk bilah seleksi (xterm 4.0.0 menghapus seleksi saat diketuk), serta tab Sesi di prototipe `Terminal` (beberapa sesi dalam satu layar terminal). `NavBar` lima tab sudah dibangun (11h); catatan README tentang `NavBar` belum dibangun sudah usang sampai artifact diperbarui.

**Temuan uji HP 2026-10-16 yang belum dikerjakan (menunggu persetujuan rencana):** (1) [sudah dikerjakan di 11f, belum diuji di HP] sambung ulang tidak menunggu jaringan kembali: saat mode pesawat sesi terus mencoba menyambung, dan diduga memunculkan prompt biometrik berulang (belum dikonfirmasi pengguna); usulan: tunda sambung ulang sampai ada jaringan, dan satu prompt untuk semua sesi yang perlu sambung ulang. (2) Setiap sambung ulang membuka shell baru dan meninggalkan shell lama yatim di server (terlihat di `who`; bertahan sampai dibersihkan `pkill`); tidak bisa dicegah dari aplikasi, penangkalnya `ClientAliveInterval` di `sshd_config` (keputusan pemilik server); pertimbangkan catatan di layar atau dokumentasi pengguna. (3) Satu shell (pts/7) tetap tinggal setelah "Putuskan semua" pada 14:58:51, penyebab belum terbukti.

**Kandidat irisan berikutnya (menunggu persetujuan):** sambung ulang berulang dengan jeda dan saklarnya (sudah dikerjakan di 11f dan 11i; saklar sudah dicoba pemilik di HP), [gulir otomatis seleksi dan layar pemuatan: sudah dikerjakan di 11g, belum diuji di HP] [popover Tempel dan saklar konfirmasi tempel: sudah dikerjakan di 11j, teruji di HP] [landscape layar utama: sudah dikerjakan di 11k, teruji di HP; banner sambungan, label profil, dan form host landscape: 11l dan 11m, teruji di HP, desain sudah sinkron] snippet (irisan 1 dan 2 sudah dikerjakan di 11ae; sisa: irisan 3 simpan sebagai snippet dari terminal), sisa pengaturan (tema terminal dan lainnya). **Di luar irisan pertama (belum dibuat):** status host online/offline. **Sudah ada setelah daftar ini ditulis:** impor profil (11ab), penanda favorit (11ac), ekspor profil lewat menu bagikan (11ad; `KEY` menjadi `AGENT` di berkas, kunci tidak ikut), dan profil agen (diarahkan ke form untuk dilengkapi). **Kandidat berikutnya terkait profil:** tombol impor dan ekspor di keadaan daftar kosong dan di landscape, hapus berkas `cache/share/` setelah dibagikan, impor dari `~/.ssh/config`.

**Tindakan:** pembersihan sumber daya sementara (daftar di bawah, butuh persetujuan pengguna). Sinkron desain: salinan lokal `docs/design/` sama dengan kedua artifact (design system versi 60, prototipe versi 60; lihat `docs/design/SUMBER.md`). `PRIVATE_KEY_PEM` kode 5 hanya dicatat di dokumen ini, belum di desain.

Cara menjalankan tes:

```
flutter analyze
flutter test                                   # 672 tes otomatis (2 dilewati), tanpa jaringan
flutter test integration_test/storage_test.dart -d <perangkat>
flutter test integration_test/host_flow_test.dart -d <perangkat>
flutter test integration_test/vault_test.dart -d <perangkat> [--dart-define=PROMPT=true]
flutter test integration_test/connect_flow_test.dart -d <perangkat> --dart-define=E2E_HOST=10.0.2.2 --dart-define=E2E_PORT=2222 --dart-define=E2E_USER=... --dart-define=E2E_PASSWORD=...
flutter test test/core/ssh/ssh_connector_test.dart --dart-define=SSH_TEST_CONFIG=<config.json>
```

Skrip bantu ada di `tool/` (pembuat token dari `tokens.json`, pembuat `docs/licenses.md`, pemasang dan pembongkar server uji SSH di WSL). Jalankan `tool/ssh_test_server/setup.sh` di dalam WSL sebagai root untuk membuat server uji (kredensial acak, ditulis ke folder yang Anda tunjuk, bukan ke repo) dan `teardown.sh` untuk menghapus semuanya.

**Sumber daya sementara yang masih ada dan harus dibersihkan saat selesai:**

- WSL Ubuntu-22.04 dan Ubuntu-18.04: user `termul_t`, berkas `/etc/ssh/termul_test_*.conf`, `/etc/ssh/termul_alt/`, dan proses `sshd` uji di port 2222, 2224 (22.04) serta 2223, 2225 (18.04). Dua proses `wsl ... sleep infinity` di Windows menjaga distro tetap hidup. Bersihkan dengan `teardown.sh` di kedua distro, lalu hentikan proses `sleep infinity`.
- Berkas kredensial uji (`config.json`, kunci privat uji) ada di folder scratchpad sesi, di luar repo. Hapus setelah selesai.
- AVD sementara `termul_uji_bersih` (buat dengan `avdmanager`): hapus dengan `avdmanager delete avd -n termul_uji_bersih`.
- Emulator `hp_besar_pin_121212_` Anda masih memuat aplikasi spike lama `com.example.termul_spike` dengan kredensial uji terenkripsi di Keystore-nya; uninstall bila sudah tidak dipakai.
- Server Ubuntu 24.04 dari spike: user `spike` di sana masih belum dibersihkan (tidak ada akses dari sesi ini).

## Tab Streak (layar "segera hadir")

Permintaan pemilik (2026-10-17): tab baru **Streak** di kiri Pengaturan, isinya pemberitahuan fitur yang akan datang. Urutan tab: Host, Sesi, Snippet, Streak, Pengaturan (`NavBar` dan `NavRail` landscape otomatis lima tab).

- **Kode:** `lib/features/streak/streak_screen.dart` (judul "Streak" dan banner info "Segera hadir"; tanpa logika, penyimpanan, atau api berwarna tier), ikon `TermulIconName.flame` (garis, bukan komponen `Flame` desain), l10n `navStreak`, `streakTitle`, `streakSoonTitle`, `streakSoonBody`.
- **Warna sorot (permintaan pemilik, 2026-10-17):** ikon tab Streak selalu merah api (`level3`, `#FF4D2E`) dan labelnya merah saat aktif, supaya mencolok dibanding tab lain; `NavItem.highlight` baru. **Penyimpangan dari desain:** desain hanya mengenal satu aksen untuk tab aktif; ini perlu masuk ke artifact (README: `NavItem.highlight`, prototipe tab Streak merah) sebelum commit.
- **Tes:** `main_shell_test.dart` dan `main_shell_landscape_test.dart` diperbarui ke lima tab; tab Streak membuka `StreakScreen`.
- **Belum teruji di HP:** tampilan lima tab di layar sempit (label "Pengaturan" paling panjang) dan di rel landscape.
- **Artifact (sudah, 2026-10-17):** prototipe versi 61 (`1792253150-1905`) dan design system versi 61 (`1792253153-ee3d`); rincian di `docs/design/SUMBER.md`. Tab Streak masuk ke `Main`, `MainLandscape`, `Settings`, `Snippets`, contoh baru 15 (`StreakSoon`), README (butir `NavBar`), `NavBar/README.md` (`highlight`), dan `Icon/README.md` (`flame`). `Settings` sekaligus kehilangan tab SFTP lamanya (sisa keputusan 2026-10-17). Prototipe lain yang memuat bar navigasi (`ComingSoon`, `Sftp`, `SftpSources`) sudah tidak dipakai aplikasi dan tidak diubah.
- **Uji HP (2026-10-17, dd3bf2af, build debug):** lima tab muat satu baris, perpindahan Host, Pengaturan, Streak berfungsi, ikon merah api dan label merah saat aktif; layar Streak sejajar dengan judul tab lain. Belum diuji: layar lebih sempit dan rel landscape.
- **Lanjutan:** streak sungguhan dibangun di bagian "Streak api" di bawah; layar "Segera hadir" sudah diganti.

## Tombol x hapus pencarian

Permintaan pemilik (2026-10-18): semua kolom pencarian mendapat tombol x di pojok kanan untuk mengosongkan kata kunci.

- **Kode:** `TermulTextField.clearLabel` (bila diisi dan ada `controller`): tombol `TermulIconButton` 44 dp muncul selama kolom berisi teks (kunci `field-clear`), mengosongkan kolom, memanggil `onChanged('')`, dan menjaga fokus supaya keyboard tetap terbuka. Dipakai di tiga kolom: Host potret, Host landscape, dan Snippet. Teks: `actionClearSearch` ("Hapus pencarian"). Kolom isian lain (form host, editor snippet) tidak memakainya.
- **Tes:** `widgets_test.dart` (muncul hanya saat ada teks, 44 px, mengosongkan, memberi tahu, fokus bertahan; tanpa `clearLabel` tidak ada tombol), `main_shell_test.dart` (Host), `snippets_screen_test.dart` (Snippet); total 677 tes.
- **Uji HP (2026-10-18, dd3bf2af, build **profile**):** di tab Host, mengetik "gapura" memunculkan x di pojok kanan, mengetuknya mengosongkan kolom, daftar kembali penuh, keyboard tetap terbuka. Kolom Snippet dan Host landscape belum dicoba di HP (landscape tidak aktif; Snippet diuji otomatis saja).
- **Artifact:** prototipe versi 62 dan design system versi 62 (`SUMBER.md`); `MainLandscape` statis sehingga tidak memperlihatkan x.

## Lipatan grup host diingat permanen (2026-10-17)

Permintaan pemilik (2026-10-17): grup host yang diciutkan tetap terciut saat aplikasi dibuka lagi. Sebelumnya lipatan hanya di memori (bertahan saat pindah tab, hilang saat aplikasi ditutup atau dimatikan Android).

- **Kode:** `UiStateRepository` (`lib/core/storage/ui_state_repository.dart`, dengan `MemoryUiStateRepository` untuk tes dan bawaan provider) dan `JsonUiStateRepository` (`lib/core/storage/json/json_ui_state_repository.dart`) untuk berkas baru `ui_state.json`: `{"version": 1, "collapsedGroups": [...]}`, path terurut, `''` = "Tanpa grup". Berkas terpisah dari `settings.json` supaya penyimpanan dari layar Pengaturan tidak menimpa lipatan (dan sebaliknya). Berkas rusak disisihkan ke `.corrupt-<waktu>` dan semua grup terbuka tanpa banner; penulisan atomik dan diantrekan (`AsyncLock`). `HostListNotifier` memuat lipatan saat dibangun, menyimpan tiap `toggleGroup`, dan membuang path grup yang sudah tidak ada (dihapus atau diganti nama) supaya grup baru bernama sama tidak langsung terciut. Gagal menulis tidak diberitahukan; lipatan tetap berlaku sampai aplikasi ditutup. Provider `uiStateRepositoryProvider`; `bootstrap()` memuat `ui_state.json` dan menyuntikkannya lewat `AppDependencies.uiState`.
- **Tes:** `json_ui_state_repository_test.dart` (berkas belum ada, simpan dan muat ulang, urutan simpan beruntun, berkas rusak dan tipe salah disisihkan, gagal menulis), `host_list_screen_test.dart` (ketukan judul grup tersimpan termasuk "Tanpa grup"; dibuka dengan grup tersimpan terciut dan path usang dibuang); total 684 tes.
- **Belum teruji di HP [?]:** lipatan bertahan setelah aplikasi ditutup paksa atau dimatikan Android; berkas `ui_state.json` benar-benar tertulis di folder pribadi aplikasi.
- **Artifact:** design system versi 63 dan prototipe versi 63 (`docs/design/SUMBER.md`): butir README "Lipatan grup host diingat" dan `Main` mengingat lipatan lewat `localStorage`. Tanpa contoh baru di kanvas (tidak ada keadaan visual baru).

## Streak api (2026-10-18)

Permintaan pemilik: lengkapi fitur streak sesuai design system, irisan 1 sampai 3 sekaligus (inti dan layar, splash, pengingat). Keputusan pemilik: riwayat hari disimpan sebagai field tambahan di `streak.json`. Widget layar utama (prototipe 10) belum, irisan berikutnya.

### Irisan 1: inti, api, chip, layar Streak, saklar tampil

- **Aturan** (`lib/core/streak/streak.dart`): port `Streak`, `StreakStatus`, `StreakEvent`, dan `TapCounter` desktop (`b3d7854150`). Tanggal disimpan sebagai tengah malam UTC dari tanggal lokal supaya selisih hari tidak terganggu jam musim panas. Jam yang mundur dianggap hari yang sama.
- **Rekaman** (`streak_record.dart`): `StreakRecord` = streak + `days` (hari yang dihitung, paling banyak 400) + `longest`. Format berkas: `{"format": 1, "count", "lastDay", "days": [...], "longest"}`; berkas desktop (tanpa dua field tambahan) terbaca, `lastDay` selalu dicatat ke `days`.
- **Penyimpanan** (`JsonStreakRepository`, `streak.json`): tulis atomik; berkas rusak dikarantina dan `BootReport.streak` membuat layar Streak menampilkan banner "Data streak rusak". Gagal menyimpan hanya dicatat (`debugPrint`, tanpa isi), sama dengan desktop.
- **Penghitungan** (`StreakController`, `MainShell`): hari dihitung saat kerangka utama tampil, saat aplikasi kembali ke depan, dan tiap 1 menit selama terbuka. Ketukan: tiga ketukan cepat (jeda di bawah 500 ms) menyalakan api padam; beku butuh `clicksToThaw` ketukan; menyalakan menambah 1 dan mencatat hari ini.
- **Tampilan:** `Flame` (`lib/shared/widgets/flame.dart`, `CustomPainter` port `FlameArt`, goyangan motion.md, mati saat reduce motion atau tab tidak terlihat lewat `TickerMode`), `StreakChip` di header Host (membuka tab Streak lewat `mainTabProvider`), tab Streak (`streak_screen.dart`, `streak_cards.dart`, `streak_help_sheet.dart`), dan bagian Streak di Pengaturan (saklar "Tampilkan streak api"; `AppSettings.streak`). Ikon `help` baru.
- **Tes:** `test/core/streak/` (port tes desktop: aturan, `TapCounter`, tier; rekaman, JSON, repository) dan `test/features/streak/streak_screen_test.dart` (hari pertama, chip dan layar aktif, padam tiga ketukan cepat dan lambat, beku tujuh ketukan, hangus, pergantian tanggal saat kembali ke depan, saklar tampil, banner rusak, bantuan). Tes Pengaturan dan main shell disesuaikan (daftar lebih panjang; api bergoyang sehingga tidak menunggu diam).
- **Belum teruji di HP:** seluruh irisan. HP tidak terdeteksi adb saat build profile selesai (2026-10-18). Padam, beku, dan hangus di HP butuh tanggal sungguhan berganti (atau `streak.json` yang diatur lewat build debug); sejauh ini hanya teruji dengan jam palsu di tes.
- **Artifact:** prototipe versi 64 dan design system versi 64 (`docs/design/SUMBER.md`).

### Irisan 2: splash saat aplikasi dibuka

- **Kode:** `lib/features/streak/streak_splash.dart` (`showStreakSplash`, rute penuh layar dengan transisi pudar 200 ms). `MainShell` memutarnya untuk setiap peristiwa selain "hari yang sama", bila "Tampilkan streak api" menyala dan kerangka utama adalah rute teratas (terminal, form, dan sheet tidak disela). Ketukan di splash memakai `StreakController.tap` yang sama dengan tab Streak.
- **Ditemukan dan diperbaiki saat render:** `Pressable` nonaktif meredupkan isinya (40%), sehingga api yang tidak menunggu ketukan tampak redup di splash dan di hero tab Streak; kini hanya api yang menunggu ketukan yang dibungkus `Pressable`. Nilai "Level api" di statistik dibiarkan membungkus seperti prototipe (sebelumnya diperkecil).
- **Tes:** `streak_screen_test.dart` grup "splash saat aplikasi dibuka" (hari pertama bara, hari ke-3 "Streak menyala", naik level, bertambah tanpa lencana, padam diketuk di splash, beku dengan "Retak c/M" dan "Nanti saja", hangus, saklar tampil mati). Harness tes memakai streak yang sudah dihitung hari ini supaya splash tidak muncul di tes lain. Pratinjau render (font asli, golden sementara, tidak di-commit) dicocokkan dengan prototipe 8 dan 9.
- **Belum teruji di HP:** splash, gerak (goyangan, percikan, guncangan) dan kelancarannya di build profile, dan reduce motion sistem.
- **Artifact:** design system versi 65 (`docs/design/SUMBER.md`); prototipe tidak berubah.

