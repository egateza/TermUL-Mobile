# Android: menjaga koneksi di latar belakang

Dokumen ini menjelaskan pengaturan "Pertahankan koneksi di latar belakang" (prototipe 6b), izin yang dibutuhkan, dan cara mengujinya. Status (2026-10-16): **sudah dibuat di aplikasi dan diuji di emulator Android 14; belum diuji di HP fisik (HyperOS)**. Lihat bagian "Implementasi" di bawah. Nama izin dan tipe service sudah dicek di dokumentasi resmi Android (bagian Deklarasi dan izin).

## Masalah

Saat aplikasi masuk latar belakang, Android bisa menutup soket TCP-nya dan sesi SSH putus, padahal sesi di server tetap hidup. Di spike (POCO 25053PC47G, Android 16) soket dimatikan sekitar 5 detik setelah aplikasi masuk latar belakang pada satu percobaan, dan sambungan putus setelah jeda 5 menit.

Penjelasan dari dokumentasi Android: sejak Android 14, proses aplikasi yang berstatus cached dibekukan 10 detik setelah masuk status itu, dan bila semua prosesnya beku, sistem menutup semua soket TCP aktif aplikasi tersebut. Ini cocok dengan log spike (`Destroyed live tcp sockets`). Kenapa jeda 13 sampai 73 detik masih selamat belum terjelaskan; dugaan, prosesnya belum berstatus cached.

## Rancangan

Pengaturan opt-in (**default mati**) di Pengaturan, bagian Koneksi. Bila menyala, aplikasi menjalankan **foreground service** selama ada sesi aktif, sehingga prosesnya tidak berstatus cached dan soketnya tidak ditutup oleh pembekuan.

- **Biaya:** baterai lebih banyak dan satu notifikasi permanen. Teks pengaturan harus menyebut keduanya.
- **Bukan jaminan:** perpindahan jaringan atau sinyal hilang tetap memutus sesi, dan HP tertentu (misalnya HyperOS) bisa menghentikan service. Sambung ulang otomatis tetap berjalan. Jangan menulis "sesi tidak akan putus" di antarmuka.

### Teks antarmuka

| Elemen | Teks |
|---|---|
| Label saklar | Pertahankan koneksi di latar belakang |
| Keterangan | Sesi tetap tersambung saat aplikasi ditutup ke latar belakang. Memakai baterai lebih banyak dan menampilkan notifikasi permanen. |
| Catatan saat menyala | Membantu sambungan bertahan, tetapi tidak menjaminnya: perpindahan jaringan atau sinyal hilang tetap memutus sesi, lalu sambung ulang otomatis berjalan. |
| Baris izin notifikasi | Izin notifikasi: Diizinkan, atau Belum diizinkan dengan tombol Izinkan (status dalam kata, bukan hanya warna) |
| Baris baterai HP | Pembatasan baterai HP. Beberapa HP (misalnya HyperOS) perlu diatur ke "Tanpa batasan" agar sesi tidak dihentikan. Membuka pengaturan Android. |

### Notifikasi

- Judul: `N sesi tersambung` (satu sesi: `1 sesi tersambung`). Isi: nama sesi dipisah koma (`app-01, db-01`).
- Aksi: **Putuskan semua** (menutup semua sesi dan menghentikan service). Mengetuk badan notifikasi membuka aplikasi.
- Saluran notifikasi terpisah bernama "Sesi aktif", prioritas rendah (tanpa bunyi). Pengingat streak memakai saluran lain.

### Perilaku

- Service mulai saat sesi pertama tersambung dan saklar menyala; berhenti saat sesi terakhir ditutup, saat "Putuskan semua", atau saat saklar dimatikan (sesi yang masih terbuka tetap berjalan, tetapi bisa putus di latar belakang).
- Menyalakan saklar di Android 13 ke atas meminta izin notifikasi. **Bila ditolak, saklar kembali mati** dan tampil pesan "Izin notifikasi diperlukan untuk menjaga koneksi". Aturan ini dipilih agar tidak bergantung pada perilaku service tanpa notifikasi, yang belum diuji.
- Saat service berjalan dan koneksi tetap putus, banner "Menyambung ulang" (layar 2d dan 2e) tetap dipakai.

## Deklarasi dan izin

| Kebutuhan | Keterangan | Status |
|---|---|---|
| `FOREGROUND_SERVICE` | Izin biasa, diberikan otomatis. Wajib sejak Android 9. | Dikonfirmasi di dokumentasi |
| Tipe service (`android:foregroundServiceType`) | Wajib sejak target API 34; tiap tipe punya izin sendiri (`FOREGROUND_SERVICE_<TIPE>`). | Dikonfirmasi di dokumentasi |
| Pilihan tipe: `specialUse` | Tipe baru di Android 14 untuk kasus yang tidak cocok dengan tipe lain. Kandidat paling masuk akal untuk SSH. Butuh izin `FOREGROUND_SERVICE_SPECIAL_USE` dan keterangan penggunaan di manifest; rilis di Play Store kemungkinan butuh deklarasi di Play Console. | Dikonfirmasi 2026-10-16 di dokumentasi resmi (service-types): tipe `specialUse`, izin `FOREGROUND_SERVICE_SPECIAL_USE`, properti `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`; penggunaan `specialUse` ditinjau di Play Console |
| Hindari `dataSync` | Android 15 membatasi lama jalannya untuk aplikasi yang menargetkan API 35 ke atas; tidak cocok untuk sesi panjang. | Dikonfirmasi ada batas; angka tidak dicatat di sini |
| `POST_NOTIFICATIONS` | Izin runtime di Android 13 ke atas agar notifikasi terlihat. Pengingat streak juga memakainya. | Dari pengetahuan umum |
| `WAKE_LOCK` dan Wi-Fi lock | Opsional, bila Wi-Fi tidur saat layar mati mengganggu. Menambah konsumsi baterai. | Belum diuji |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | **Tidak dipakai.** Bukan penyebab masalah ini dan dibatasi kebijakan Play Store. | Keputusan desain |

Manifest yang dipakai aplikasi (nama service `.KeepAliveService`; bentuk selebihnya sama):

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<service android:name=".KeepAliveService"
         android:exported="false"
         android:foregroundServiceType="specialUse">
  <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
            android:value="menjaga sesi SSH interaktif tetap tersambung"/>
</service>
```

## Implementasi (2026-10-16)

Dibuat sesuai rancangan di atas. Yang perlu diketahui:

- **Bukti masalah di HP** (Xiaomi 25053PC47G, Android 16, build debug): log sistem `InetDiagMessage: Destroyed live tcp sockets for uids={10493}` muncul sekitar 6 detik setelah aplikasi ke latar belakang; proses aplikasi sendiri tetap hidup (PID sama). Aplikasi lalu menyambung ulang saat dibuka lagi (prompt sidik jari atau pola muncul).
- **Service**: `KeepAliveService` (Kotlin), tipe `specialUse`, `START_NOT_STICKY`. Tidak membuka soket; hanya menahan proses. Dijalankan dari Dart lewat `MethodChannel` `io.github.egateza.termul/keepalive`. Seluruh teks notifikasi dikirim dari Dart (ARB), bukan ditulis di Kotlin.
- **Notifikasi**: saluran "Sesi aktif" (prioritas rendah), judul "N sesi tersambung" (bentuk jamak lewat ARB), isi nama sesi dipisah koma, aksi **Putuskan semua**, mengetuk badan notifikasi membuka aplikasi.
- **Kapan menyala**: selama pengaturan menyala **dan** ada sesi yang tersambung. Sesi yang putus (menunggu sambung ulang) dicabut dari daftar; tersambung ulang mendaftarkannya lagi. Jadi notifikasi hanya menggambarkan sesi yang benar-benar tersambung, dan service padam bila tidak ada.
- **Putuskan semua** menutup sambungan langsung (tidak bergantung pada penggambaran layar, jadi jalan juga saat aplikasi di latar belakang), menutup layar sesi, dan tidak memicu sambung ulang.
- **Izin notifikasi**: menyalakan saklar meminta izin (Android 13 ke atas); bila ditolak, saklar tetap mati dan tampil "Izin notifikasi diperlukan untuk menjaga koneksi". Baris izin menampilkan "Diizinkan" atau "Belum diizinkan" (kata, bukan hanya warna) dengan tombol **Izinkan**. Status dibaca ulang saat aplikasi kembali terlihat.
- **Pembatasan baterai HP**: tombol "Buka pengaturan" membuka halaman info aplikasi Android (`ACTION_APPLICATION_DETAILS_SETTINGS`), tempat pengguna memilih "Tanpa batasan". Aplikasi tidak meminta pengecualian baterai sendiri (keputusan di atas tetap).
- **Log diagnosis** (hanya build debug, tanpa host, user, atau rahasia): baris berawalan `[termul]` di `adb logcat` memuat perubahan siklus hidup, alasan putus (`serverClosed`, `keepAliveTimeout`, `error`), lama di latar belakang, hasil pemeriksaan sambungan, dan nyala atau padamnya service.
- **Disimpan**: `settings.json` bagian `connection.keepAlive` (bawaan `false`).
- **Teruji**: emulator Android 14 (service menjadi foreground bertipe `specialUse`, notifikasi dan aksi benar, "Putuskan semua" menghentikan service tanpa galat) dan tes otomatis. **Belum teruji**: apakah service benar-benar mencegah `Destroyed live tcp sockets` di HyperOS; baterai; Wi-Fi tanpa kabel dengan layar mati; notifikasi yang diblokir pengguna setelah service berjalan.

## Cara menguji (K10, ulangan)

1. Aktifkan saklar, sambungkan satu sesi, tekan Home.
2. Lakukan di **Wi-Fi tanpa kabel**, HP di baterai, layar mati, untuk 5 dan 30 menit (spike lama memakai `adb reverse` lewat USB).
3. Periksa pembekuan dan penutupan soket:

```powershell
adb shell "dumpsys activity | grep -A 20 'Apps frozen:'"
adb logcat -d | Select-String "Destroyed live tcp"
```

4. Catat konsumsi baterai selama uji (dengan dan tanpa saklar) supaya teks "memakai baterai lebih banyak" punya angka.
5. Ulangi di HP lain bila ada; HyperOS dikenal agresif.

## Belum diverifikasi

- Foreground service menahan soket dalam praktik di HP (sudah dibuat dan jalan di emulator; belum dicoba di HyperOS).
- Syarat Play Store sebenarnya saat rilis (deklarasi di Play Console).
- Perilaku bila notifikasi diblokir pengguna setelah service berjalan.
- Angka baterai.
- iOS: tidak ada padanan; iOS tidak diuji (lihat `spike.md`).
