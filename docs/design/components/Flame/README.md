Api streak tiga lapis (luar, tengah, inti) yang bentuk dan warnanya berganti menurut hari streak dan state, digambar sebagai SVG dengan bentuk yang sama seperti di TermUL desktop.

**Anda menyediakan:** `count` (hari streak; menentukan tier), `state` (`aktif`, `bara`, `padam`, `beku`, `hangus`), `size` (bawaan 48; tinggi api, lebar kotak 1,3 kali), `animate` untuk menggoyang api, dan untuk `beku` `cracks` dan `need` (jumlah retakan dan ketukan yang dibutuhkan). `decorative` menyembunyikan api dari pembaca layar bila angkanya sudah dibaca di dekatnya.

- Sembilan tier mengikuti desktop: Bara (1-2 hari), Api Jingga (3-9), Api Merah (10-29), Api Magenta (30-59), Api Ungu (60-99), Api Biru (100-179), Api Zamrud (180-364), Api Emas (365-729), Api Pelangi (730 ke atas). Warna tiap lapis ada di token `tier-n-outer`, `level-n` dan `tier-n-core`.
- Tier tinggi menambah lidah api, percikan dan, untuk Emas dan Pelangi, bintang. Pelangi memutar warnanya saat `animate`.
- `padam` dan `hangus` abu-abu (`flame-gray-*`) dengan asap; `beku` menaruh api di dalam balok es dengan retakan yang bertambah menurut `cracks / need`.
- `animate` menggoyang tiga lapis api tanpa henti. Pakai hanya selama layar terlihat (splash, layar Streak) dan bukan di daftar atau widget; reduce motion mematikannya.
- Selalu sertakan kata atau angka (tier, "padam", "beku") di dekat api; bentuk dan warna tidak berdiri sendiri.
