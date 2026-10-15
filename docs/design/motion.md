# Gerak

Api streak bergoyang terus selama layarnya terlihat (splash, layar Streak); itu ciri khas aplikasi. Selain itu, gerak hanya merespons peristiwa (streak bertambah, api dinyalakan, es dipecahkan, aplikasi dibuka). Saat pengguna mematikan animasi di sistem (reduce motion), semua gerakan dilewati dan layar langsung menampilkan keadaan akhir. Widget layar utama tidak beranimasi.

## Api (`Flame` dengan `animate`)

| Gerak | Durasi | Kurva |
|---|---|---|
| Lapisan luar bergoyang (miring dan memanjang) | 1,1s, berulang | ease-in-out |
| Lapisan tengah | 0,85s, berulang | ease-in-out |
| Inti | 0,65s, berulang | ease-in-out |
| Lidah api kiri dan kanan | 0,9s dan 0,75s, berulang | ease-in-out |
| Percikan naik dan memudar | 0,9-1,4s tiap percikan, berulang | ease-out |
| Bintang berkedip (Emas, Pelangi, kilau es) | 1,8-2,2s, berulang | ease-in-out |
| Asap api padam | 2s, berulang | ease-out |
| Warna pelangi berputar | 6s, berulang | linear |

## Splash saat aplikasi dibuka

| Peristiwa | Waktu (detik) | Gerak |
|---|---|---|
| Api masuk | 0 | Membesar dari nol dalam 0,7s, kurva cubic-bezier(0.3, 1.7, 0.5, 1) |
| Streak bertambah | 1,0 | Angka naik dari hari lama ke hari baru, cincin dan 18 percikan meledak, lencana muncul; bila tier berganti api lama memudar dan api baru muncul |
| Terbang ke chip | 3,0 (bara 2,8) | Api mengecil dan terbang ke chip dalam 0,7s dengan latar memudar (di desktop; belum dibuat di prototipe mobile) |
| Padam atau beku menunggu | selama menunggu | Tiap ketukan mengguncang api (0,3s); padam mengeluarkan asap, beku melepas serpihan es (4 per retakan) |
| Dinyalakan atau es pecah | saat ketukan terakhir | Guncangan, cincin dan percikan, serpihan (18 saat pecah); terbang ke chip 1,8s setelahnya |
| Hangus | 1,0 | Api memudar ke abu-abu dan mengecil selama 1,6s dengan asap; angka dicoret |
| Hangus: mulai lagi | 3,2 | Bara menyala dengan percikan, angka `1/3`; terbang ke chip pada 5,6s |

- Gunakan keyframe yang sama di Flutter dengan `AnimationController` atau Rive; kurva dan waktu di atas adalah acuan.
- Goyangan api berjalan hanya selama layar terlihat; hentikan saat aplikasi di latar belakang untuk menghemat baterai.
- Gerak tidak boleh menahan input: tombol Lanjut selalu bisa ditekan selama animasi berjalan.
