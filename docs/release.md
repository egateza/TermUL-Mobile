# Rilis lewat GitHub Releases

TermUL Mobile tidak lewat Play Store. APK rilis diunggah ke GitHub Releases di `egateza/TermUL-Mobile`. Aplikasi memeriksa rilis terbaru setiap kali dibuka, dan pemeriksaan juga bisa dijalankan lewat tombol **Periksa** di bagian Pembaruan di Pengaturan. Bila ada versi baru, aplikasi mengunduhnya, mencocokkan SHA-256, lalu membuka penginstal Android. Rincian implementasinya ada di `docs/implementation-plan.md` (bagian "Pembaruan dari GitHub Releases").

## Kunci tanda tangan rilis

- Keystore: `D:\IdeaProjects\TermUL Mobile\keystore\termul-release.jks` (di luar repo). Format PKCS12, alias `termul`, RSA 4096, berlaku sampai 2054-03-05. Dibuat 2026-10-18.
- Password ada di `android/key.properties`, yang diabaikan git. Isinya `storePassword`, `keyPassword`, `keyAlias`, dan `storeFile`. Gradle (`android/app/build.gradle.kts`) membaca berkas ini untuk build rilis. Bila berkas itu tidak ada (mis. hasil clone), build rilis memakai kunci debug dan menulis peringatan, dan APK seperti itu **tidak boleh** diunggah.
- Sidik jari sertifikat (publik, boleh dibagikan): `SHA-256 6f:b4:55:12:fa:c9:36:8c:d5:c2:cc:50:34:4b:9b:79:b7:bb:89:d7:0d:12:66:87:ab:4a:f4:5c:b7:6b:8c:54`.
- **Cadangkan keystore dan `key.properties` bersama-sama di luar komputer ini** (mis. pengelola sandi atau penyimpanan terenkripsi). Android hanya menerima update yang ditandatangani kunci yang sama. Bila kunci hilang, pengguna harus uninstall dulu, dan uninstall menghapus host, kunci privat, dan password di vault.
- Jangan pernah memasukkan keystore, `key.properties`, atau passwordnya ke repo, issue, atau catatan rilis.

## Pindah dari build debug (sekali saja)

Aplikasi yang dipasang lewat `flutter run` atau build profile ditandatangani kunci debug. APK rilis tidak bisa menimpanya ("Aplikasi tidak terpasang", konflik paket). Langkahnya:

1. Ekspor profil host (tombol ekspor di daftar host). Kunci privat dan password tidak ikut ekspor, jadi siapkan juga salinannya.
2. Uninstall TermUL.
3. Pasang APK rilis, impor profil, lalu isi ulang rahasianya.

Setelah itu semua update berikutnya bisa langsung menimpa versi yang terpasang, dan datanya tetap ada.

## Langkah setiap rilis

1. Naikkan `version` di `pubspec.yaml`, mis. `0.2.0+2`. Bagian `+N` adalah `versionCode` dan **harus selalu naik**.
2. Pastikan `flutter analyze` bersih dan `flutter test` lulus, lalu commit.
3. Build dan beri nama:

   ```
   flutter build apk --release
   cp build/app/outputs/flutter-apk/app-release.apk termul-mobile-0.2.0.apk
   sha256sum termul-mobile-0.2.0.apk > termul-mobile-0.2.0.apk.sha256
   ```

4. Periksa tanda tangannya. Sidik jari harus sama dengan yang di atas:

   ```
   D:/Android/sdk/build-tools/36.0.0/apksigner.bat verify --print-certs termul-mobile-0.2.0.apk
   ```

5. Push commit, lalu buat rilis dengan tag `v` + nomor versi. Aplikasi membandingkan tag dengan versi terpasang; tag boleh berakhiran `+N` bila hanya `versionCode` yang naik.

   ```
   gh release create v0.2.0 termul-mobile-0.2.0.apk termul-mobile-0.2.0.apk.sha256 --title "TermUL Mobile 0.2.0" --notes "Ringkasan perubahan"
   ```

   Catatan rilis tampil di aplikasi (paling banyak 8 baris), jadi tulis kalimat pendek. Jangan menandai rilis sebagai *pre-release*, karena `releases/latest` melewatinya.

## Aturan yang diperiksa aplikasi

- Rilis harus berisi **tepat satu** berkas `.apk` dan berkas `<nama apk>.sha256` (keluaran `sha256sum`, atau hanya 64 digit hex). Tanpa salah satunya, aplikasi menampilkan "Rilis terbaru tidak berisi APK dan checksum yang dibutuhkan".
- Ukuran APK paling besar 300 MB.
- Unduhan yang tidak cocok dengan checksum dihapus dan tidak dipasang.
- Android sendiri menolak APK yang tanda tangannya berbeda dari aplikasi terpasang.
- GitHub membatasi 60 permintaan API per jam per alamat IP tanpa token. Bila batas itu tercapai, aplikasi menampilkan "GitHub menolak permintaan saat ini".

## Verifikasi developer Google

Sejak 30 September 2026, Indonesia termasuk negara pertama yang memberlakukan verifikasi developer Android. Sumber berita belum sepakat apakah APK dari luar toko ikut diblokir di HP bersertifikat Google, dan dokumentasi resmi Google belum dibaca. Coba pasang APK rilis pertama di HP dari browser atau dari aplikasi. Bila diblokir, pilihannya adalah mendaftar di Android Developer Console (ada jenis akun untuk penggunaan pribadi atau hobi), atau memasang lewat `adb install -r`.
