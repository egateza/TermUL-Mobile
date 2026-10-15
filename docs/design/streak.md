# Streak api

Aturan dan tampilan api mengikuti artifact desktop "Streak Api TermUL" dan TermUL desktop. Satu hari dihitung saat aplikasi dibuka; tanggal yang berganti selagi aplikasi terbuka dihitung seperti membuka lagi.

## Mode

| Mode | Syarat | Tampilan | Interaksi |
|---|---|---|---|
| bara | Hari 1-2 | Arang `coal` dengan api kecil Bara, angka `N/3`, belum dihitung sebagai streak | Tidak ada |
| aktif | Hari ke-3 ke atas | Api tiga lapis berwarna menurut tier | Tidak ada |
| padam | Absen 1-2 hari | Api abu-abu `flame-gray-*` dengan asap, angka redup | Ketuk 3 kali cepat (jeda antar ketukan kurang dari 0,5 detik); streak naik 1 |
| beku | Absen 3-10 hari | Api `flame-ice-*` di dalam balok es; retakan bertambah tiap ketukan | Ketukan = 5 + (hari absen - 3), minimal 5 dan maksimal 10; setelah es pecah streak naik 1 |
| hangus | Absen lebih dari 10 hari | Api mengecil lalu hilang, angka lama dicoret, lalu `1/3` | Tidak ada; hari ini menjadi hari ke-1 |

Contoh jumlah ketukan beku: absen 3 hari = 5, 5 hari = 7, 8 hari atau lebih = 10.

## Tier

| Tier | Nama | Hari | Token warna tengah | Tambahan |
|---|---|---|---|---|
| 1 | Bara | 1-2 | `level-1` | Arang, tanpa percikan |
| 2 | Api Jingga | 3-9 | `level-2` | 1 percikan |
| 3 | Api Merah | 10-29 | `level-3` | Lidah api kiri, 2 percikan |
| 4 | Api Magenta | 30-59 | `level-4` | Lidah api kiri, 2 percikan |
| 5 | Api Ungu | 60-99 | `level-5` | Lidah api kiri dan kanan, 3 percikan |
| 6 | Api Biru | 100-179 | `level-6` | Dua lidah api, 3 percikan |
| 7 | Api Zamrud | 180-364 | `level-7` | Dua lidah api, 4 percikan |
| 8 | Api Emas | 365-729 | `level-8` | Dua lidah api, 4 percikan, bintang |
| 9 | Api Pelangi | 730 ke atas | `level-9` | Dua lidah api, 5 percikan, bintang, warna berputar |

Tiap tier punya tiga lapis api (`tier-n-outer`, `level-n` untuk lapis tengah, `tier-n-core`) dan warna cahaya `tier-n-glow`.

## Aturan penggunaan

- Gambar api dengan `Flame` dan angka dengan `count-xl`, `count-lg` atau `count-md`; dua hari pertama menulis `N/3` dan seterusnya `Nx`.
- Sertakan nama tier atau state dalam kata di dekat api ("Lv 3 · Api Merah", "Api padam").
- `StreakChip` di header Daftar host mengikuti mode: warna tier untuk aktif, `chip-ember` untuk bara, `chip-gray` untuk padam dan hangus, `chip-ice` untuk beku.
- Widget layar utama menampilkan api statis; ketukan pada widget hanya membuka aplikasi (padam dan beku membuka splash yang bisa diketuk).
- Splash saat aplikasi dibuka menampilkan peristiwa hari itu (bertambah, naik level, bara, padam, beku, hangus). Padam dan beku punya tombol "Nanti saja".

## Teks pesan (dari desktop)

- Bara: "Buka TermUL lagi besok. Streak menyala di hari ke-3."
- Padam: "Kemarin kamu tidak membuka TermUL, jadi api padam. Ketuk api 3x cepat untuk menyalakannya lagi."
- Beku: "Kamu absen N hari, api membeku. Ketuk api M kali untuk memecahkan es." dengan keterangan "Retak c/M".
- Setelah dinyalakan: "Api menyala lagi. Streak lanjut, hari ini ikut dihitung."
- Hangus: "Kamu absen N hari. Streak X hari hangus." lalu "Mulai lagi hari ini. Buka TermUL 3 hari berturut-turut untuk menyalakan streak."
