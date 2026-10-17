# Rilis lewat GitHub Releases

TermUL Mobile tidak lewat Play Store. Rilis diterbitkan ke GitHub Releases di `egateza/TermUL-Mobile` dengan skrip `tool/release.ps1`. Aplikasi mengambil `manifest.json` dan `manifest.json.sig`, memverifikasi tanda tangan Ed25519, lalu mengunduh APK sesuai SHA-256 dan ukuran di manifest. Sebelum membuka penginstal Android, aplikasi juga memeriksa nama paket, `versionCode`, dan sertifikat APK.

## Kunci rilis

- Keystore Android: `%USERPROFILE%\.termul-release\termul-mobile-release.jks` (di luar repo), PKCS12, alias `termul`, RSA 4096. Jalur yang dipakai Gradle tercatat di `android/key.properties`, yang diabaikan git.
- Sidik jari sertifikat Android yang diperiksa skrip: `SHA-256 6f:b4:55:12:fa:c9:36:8c:d5:c2:cc:50:34:4b:9b:79:b7:bb:89:d7:0d:12:66:87:ab:4a:f4:5c:b7:6b:8c:54`.
- Kunci privat Ed25519 manifest berada di `%USERPROFILE%\.termul-release\mobile-update-signing.key` atau jalur `TERMUL_MOBILE_UPDATE_KEY`. Kunci publik yang dipakai aplikasi ada di `lib/core/update/update_keys.dart`.
- Cadangkan keystore Android beserta `key.properties`, dan kunci privat Ed25519, di penyimpanan terenkripsi di luar komputer ini. Jangan masukkan berkas atau password kunci ke repo, issue, atau catatan rilis. Android menolak pembaruan dengan sertifikat berbeda; aplikasi menolak manifest dengan tanda tangan berbeda.

## Persiapan sekali saja

Pastikan Flutter, Dart, Android SDK (termasuk build-tools), dan GitHub CLI (`gh`) tersedia. Jalankan `gh auth login` untuk akun yang berhak menerbitkan rilis. Pastikan kedua kunci lokal di atas ada. Skrip menolak build rilis tanpa `android/key.properties`.

Build debug dan profile yang dibuat pada checkout dengan `android/key.properties` memakai kunci rilis yang sama agar bisa saling menimpa. Instalasi lama yang dibuat sebelum perubahan ini mungkin masih memakai kunci debug. Instalasi tersebut tidak bisa diperbarui dengan sertifikat rilis: ekspor profil host, siapkan kembali rahasia secara terpisah, uninstall aplikasi lama, pasang APK rilis, lalu impor profil dan isi ulang rahasia. Penghapusan aplikasi menghapus data lokalnya.

## Langkah setiap rilis

1. Selesaikan perubahan, dokumentasi, dan pemeriksaan proyek. Buat commit pada `master`, lalu push commit. Skrip hanya berjalan dari working tree bersih dan commit yang sudah ada di remote.
2. Buat catatan singkat dalam berkas teks di luar repo. Catatan itu ikut ditampilkan aplikasi (maksimal delapan baris).
3. Jalankan dari root repo:

   ```powershell
   .\tool\release.ps1 -NotesFile C:\path\ke\release-notes.txt -Draft
   ```

   Versi dibentuk dari `major.minor` di `pubspec.yaml` ditambah jumlah commit, misalnya `0.1.234`; `versionCode` memakai jumlah commit. Karena itu commit rilis harus sudah di-push dan jumlah commit tidak boleh lebih rendah dari rilis sebelumnya. Tag `v<versi>` harus belum ada.

4. Skrip menjalankan `flutter build apk --release`, memastikan versi APK, memeriksa sidik jari sertifikat, menyalin APK serta membuat dan memverifikasi manifest bertanda tangan di `build/release`, lalu membuat GitHub Release draft dengan ketiga aset tersebut.
5. Tinjau draft dan aset di GitHub. Setelah siap, publikasikan draft secara manual. Jangan tandai sebagai *pre-release*, karena aplikasi mengunduh dari rilis `latest`.

Skrip mengharuskan catatan rilis, `gh`, keystore Android, serta kunci Ed25519 tersedia. Jangan jalankan skrip dengan `2>&1` di Windows PowerShell 5.1 karena stderr perintah native dapat dianggap galat. Opsi `-AllowDirty` hanya untuk uji lokal; jangan gunakan untuk rilis.

## Pemeriksaan pembaruan di aplikasi

- `manifest.json` memuat satu APK, versi, `versionCode`, catatan rilis, ukuran, SHA-256, dan commit. `manifest.json.sig` adalah tanda tangan Ed25519 atas byte manifest persis.
- APK dibatasi 300 MB. Unduhan yang ukuran atau SHA-256-nya tidak cocok dihapus. Sebelum instalasi, paket harus `io.github.egateza.termul`, `versionCode` harus sama dengan manifest, dan sertifikat harus sama dengan aplikasi.
- GitHub Release harus memiliki `manifest.json`, `manifest.json.sig`, dan APK yang namanya tercantum di manifest. Skrip menyiapkan dan memverifikasi ketiganya.

## Verifikasi developer Google

Pemasangan langsung APK rilis pertama di perangkat Indonesia belum diverifikasi. Uji alur pemasangan pada perangkat sebelum mengandalkannya; bila Google Play Protect atau kebijakan perangkat memblokir pemasangan, tinjau persyaratan Android Developer Console yang berlaku.
