Sistem desain TermUL Mobile: klien SSH pribadi untuk ponsel (Android dan iOS), turunan TermUL desktop. Gelap, padat informasi, dan berhati-hati terhadap hal yang berisiko. Setiap nilai di bawah memakai nama token; jangan menulis heks, ukuran atau radius langsung.

## Fondasi konten

- Tulis dalam Bahasa Indonesia. Istilah teknis baku tetap berbahasa Inggris: host, terminal, sudo, SFTP, vault, scrollback, snippet.
- Gunakan huruf besar hanya di awal kalimat. Label tombol tanpa titik, tanpa tanda seru, tanpa emoji.
- Jelaskan akibat, bukan prosedur: "Teks masuk ke prompt tanpa menekan Enter, jadi belum dijalankan." Sebut angka dan nama nyata: "Tempel 3 baris?", "Sisa 2 ketukan lagi untuk menyalakan api."
- Setiap status memakai kata, bukan hanya warna: "online", "offline", "menyambung ulang", "berisiko", "Hari ini selesai". `ok` dan `bad` nyaris sama terang, jadi kata atau ikon yang membedakan keduanya.
- String teknis (host, user@ip, path, perintah, angka streak) selalu bergaya mono (`terminal`, `terminal-sm`, `key`, `count-*`). Judul dan penjelasan memakai `h1`, `h2`, `title`, `body`, `body-sm`, `caption`.
- Tindakan yang bisa merugikan (menempel banyak baris, perintah `rm -rf`, host key berubah) selalu menampilkan isi dan konsekuensinya sebelum tombol konfirmasi, dan pilihan aman menjadi tombol utama.

## Fondasi visual

- Hanya ada tema Gelap. Susun lapisan dari `ground` (halaman) ke `surface` (kartu, sheet, bar) ke `surface-raised` (kontrol di atas kartu). Terminal dan editor memakai `ground-deep`.
- `accent` adalah satu-satunya warna aksi: tombol utama, pilihan aktif, ikon aktif, cincin fokus. Teks di atas isian `accent` memakai `on-accent`, bukan putih. Jangan menambah warna aksi kedua.
- `ok`, `bad`, `ice` hanya untuk status dan selalu disertai kata atau ikon. `level-1` sampai `level-9` hanya untuk api streak; jangan dipakai sebagai warna dekorasi.
- Pisahkan permukaan dengan tepi 1px `line`, bukan bayangan; sistem ini tidak punya bayangan. `line` hanya 1,47:1 terhadap `ground`, jadi tepi kontrol yang membawa makna (input, sakelar mati, titik progres kosong) memakai `line-strong`.
- Fokus papan ketik: 2px solid `accent`, offset 2px, pada semua elemen interaktif.
- Setiap target sentuh minimal `tap-min` (44px). Tombol utama di dasar layar `button-lg`, baris pengaturan `row-min`, baris host `row-comfy`.
- Radius: kartu dan baris host `radius-xl`; input dan baris pengaturan `radius-lg`; tombol-khusus `radius-md`; sheet dan widget `radius-3xl`; chip dan tombol bulat panjang `radius-pill`; titik dan tombol api `radius-round`.
- Jarak: margin tepi layar `space-8`, gutter daftar `space-5`, padding kartu `space-6` sampai `space-7`, jarak antar elemen sebaris `space-3`, antar tombol-khusus `space-2`.
- Bingkai desain ponsel `screen-w` x `screen-h`. Layar utama: header, area gulir, lalu bar navigasi bawah lima tab (Host, Sesi, SFTP, Snippet, Pengaturan). Layar terminal tidak memakai bar navigasi agar ruang terminal maksimal. Panel dan dialog naik dari bawah sebagai `BottomSheet`.
- Keadaan: terpilih atau menekan = isian `accent` dengan teks `on-accent`; nonaktif = opasitas 0,4; meredup menunggu = `ink-faint`.
- Gerak hanya terjadi sebagai respons peristiwa dan mematuhi reduce motion. Lihat bagian Gerak.

## Ikonografi

- Ikon adalah SVG garis inline: viewBox 24, tebal garis 1,75, ujung dan sambungan bulat, warna `currentColor`. Pakai komponen `Icon` dan namanya; jangan menggambar ulang.
- Jangan memakai emoji. Glyph teks hanya untuk tombol-khusus di `KeyButton` (panah, backspace, enter).
- Ikon mandiri wajib punya label aksesibilitas; ikon yang menyertai teks disembunyikan dari pembaca layar.
- Api streak digambar oleh `Flame`, bukan ikon biasa, karena bentuknya berganti menurut state.

## Komponen

- Aksi: `Button` untuk teks, `IconButton` untuk ikon saja. Satu `Button` varian `primary` per layar atau sheet; dalam dialog berisiko, tombol utama adalah pilihan aman.
- Input: `TextField` (pencarian dan form), `Switch` (baris pengaturan dengan deskripsi), `Segmented` (2-4 pilihan eksklusif), `Stepper` (satu angka dalam rentang kecil, dengan tombol kurangi dan tambah), `Chip` (filter, tag, level).
- Umpan balik: `Banner` (peringatan, risiko, es), `Toast` (konfirmasi sesaat, maksimal satu baris), `StatusDot` (titik dengan kata), `Progress` (bar atau titik ketukan).
- Permukaan: `Card`, `BottomSheet`, `HostRow`, `NavBar`.
- Terminal: `KeyButton` untuk baris tombol-khusus dan panel tombol, `TerminalSurface` untuk menampilkan baris terminal berwarna.
- Streak: `Flame` dan `StreakChip`. Aturan state ada di bagian Streak api.

## Spike teknis

Sebelum UI penuh dibangun, tumpukan Flutter (`dartssh2`, `xterm`) diuji ke server nyata. Daftar uji, kriteria lulus, hasil, dan keputusan desain ada di `spike.md`. Catatan teknis lengkap (masalah, penyebab, perbaikan, dan kode yang terbukti jalan) ada di `spike-temuan.md`. Hasil spike hanya mencakup Android; iOS belum diuji. Rancangan menjaga koneksi di latar belakang (foreground service, izin, dan pengaturannya) ada di `android.md`.

## Batasan yang berlaku

- Hanya tema Gelap dan orientasi potret yang didefinisikan.
- Sembilan tier api, ambang harinya dan palet warnanya mengambil nilai dari artifact desktop "Streak Api TermUL"; jika `StreakTier` di kode desktop berbeda, kode itulah yang benar.
- Tepi `line` pada input dan chip di prototipe tidak mencapai 3:1; sistem ini mencatatnya dan menyediakan `line-strong`.

## Catatan dari implementasi Flutter (diperbarui 2026-10-16)

Keputusan yang muncul saat aplikasi dibangun dan menyimpang atau menambah dari desain di atas. Rinciannya di `docs/implementation-plan.md` repo aplikasi.

- Platform: Android saja; iOS belum diuji sama sekali (kalimat awal "Android dan iOS" tidak lagi berlaku).
- Pengaturan: layar Pengaturan sudah ada dengan bagian Terminal (pratinjau, `Stepper` ukuran font dan tinggi baris, tombol "Kembalikan bawaan") dan bagian Koneksi (saklar "Pertahankan koneksi di latar belakang", status izin notifikasi, tombol ke pengaturan baterai; lihat `android.md` dan prototipe `Settings` 6b). Karena `NavBar` lima tab belum dibangun, layar ini sementara dibuka dari ikon pengaturan di header layar Host, di samping tombol tambah host. Bagian lain di prototipe (Tema, Keamanan, Data, Streak, Widget) belum dibuat.
- Terminal: tinggi baris bawaan aplikasi 1,3, bukan 1,5 dari token `terminal` (di HP 1,5 hanya memuat sekitar 12 baris di landscape sehingga daftar proses `htop` tidak terlihat); token `terminal` tetap rujukan untuk teks terminal di luar pengaturan. Ukuran font 8 sampai 24 px (bawaan 13), tinggi baris 1,0 sampai 2,0. Tanpa cubit-untuk-zoom; ukuran hanya diubah lewat Pengaturan.
- Warna ANSI magenta dan sian tidak ada di `tokens.json`; aplikasi memakai `#D59BF6` dan `#7FD6E0` (versi cerah `#E6BDFB` dan `#A9E8EF`) supaya `htop`, `vim`, dan `ls --color` terbaca di `ground-deep`.
- Keluar dari terminal (tombol kembali di layar maupun sistem) meminta konfirmasi selama shell hidup, karena shell di server ikut berakhir.
- Sambung ulang: otomatis satu kali saat putus; bila gagal, menunggu tombol "Sambung sekarang". Setiap sambung ulang membuka vault lagi, jadi prompt penguncian muncul lagi.
- Penguncian rahasia tiga tingkat (mengubah K15 di `spike.md`): biometrik; PIN, pola, atau sandi perangkat bila HP tanpa biometrik; tanpa kunci layar boleh menyimpan tetapi dengan peringatan. Rahasia selalu terenkripsi di Keystore.
- Tombol cepat terminal: Fn (F1 sampai F12) ditaruh setelah Alt; mode ringkas landscape memakai tombol status 32 dp dan tombol cepat 36 dp.
- Tempel di terminal (diperbarui 2026-10-16): tombol **Tempel** ada di baris tombol cepat, setelah Fn (belum ada popover di kursor prompt seperti prototipe `TerminalPasteMenu`). Papan klip kosong: toast "Papan klip kosong". Satu baris tanpa tanda bahaya langsung masuk ke prompt. Selain itu dialog "Tempel N baris?" menampilkan isi (maksimal 50 baris, sisanya diringkas), baris berisiko diberi kata "berisiko", dan akibatnya. Pilihan aman (Batal) menjadi tombol utama bila ada baris berisiko atau server belum mendukung tempel aman; tempel banyak baris biasa dengan tempel aman aktif memakai Tempel sebagai tombol utama.
- Varian tanpa tempel aman (digambar di prototipe 2h): bila program di server tidak menyalakan tempel aman (bracketed paste; bash di bawah 5.1), banyak baris langsung dijalankan, jadi dialog memberi peringatan "Server ini belum mendukung tempel aman: setiap baris langsung dijalankan begitu ditempel." menggantikan kalimat "belum dijalankan", dan toast hanya "Ditempel · N baris". Karakter kontrol (mis. ESC) dibuang dari teks dan dilaporkan; teks lebih dari 100.000 karakter ditolak. Pola baris berisiko sama dengan prototipe.
- Seleksi dan salin teks (diperbarui 2026-10-16): mengikuti prototipe `Terminal` (bilah dengan jumlah karakter, Batal, Salin, Semua; toast "Disalin · N karakter"). Gagang berbeda atas pilihan pemilik: prototipe memakai bulatan `info` bertangkai, bentuk gagang bisa dipilih di Pengaturan, bagian Terminal, lewat `Segmented` "Bentuk gagang seleksi" (tambahan; digambar di prototipe `Settings`): **Tetesan** (bawaan; bulatan 16 dp dengan ujung runcing di atas yang sisinya sedikit melengkung, ujungnya menunjuk batas seleksi), **Segitiga** (bulatan dengan segitiga terpisah di atasnya, alas segitiga melengkung mengikuti bulatan), dan **Bulatan** (polos). Semuanya `accent` bertepi `ground` 3 dp, bukan bulatan `info` bertangkai seperti prototipe `Terminal` (prototipe itu tidak diubah). Ujung tetesan dan segitiga tidak statis: bila badan gagang dijauhkan dari tepi layar, ujungnya miring ke titik seleksi yang sebenarnya (sudut paling miring 60 derajat, panjang paling 1,5 kali jarak biasa); di baris paling bawah gagang dibalik, ujungnya menyentuh sisi atas sel dan badannya di atas. Bulatan tidak punya ujung sehingga tidak miring. Tambahan di luar prototipe: kaca pembesar di atas jari saat menyeret gagang (120 x 56 dp, perbesaran 1,6x, tepi `accent`; di tepi layar wilayah yang diambil digeser ke dalam dan garis `accent` menandai titik yang ditunjuk; contoh 2i), serta gagang yang dijepit di dalam layar dan minimal 36 dp dari tepi kiri dan kanan supaya tidak jatuh di zona gestur kembali Android.
- Seleksi: belum bisa diterapkan, desain tetap. (1) Petunjuk bilah di desain "Ketuk kata lain untuk memperluas pilihan" mengandaikan ketukan memperluas pilihan; xterm 4.0.0 menghapus seleksi saat terminal diketuk, jadi aplikasi sementara menulis "Seret gagang untuk mengubah pilihan". (2) Warna: desain memakai latar `terminal-selection` dengan teks `terminal-selection-ink`, tetapi xterm 4.0.0 menggambar seleksi di atas teks tanpa menggambar ulang teksnya, sehingga latar pekat menutupi huruf; aplikasi sementara memakai `#3E7CA8` dengan alpha 55%. Agar sesuai desain, seleksi harus digambar di bawah teks (perlu menambal atau mengganti penggambar xterm). (3) Belum dibuat: Cari, Kirim ke host lain, Simpan sebagai snippet, Bagikan, Salin sebagai satu baris, dan gulir otomatis saat gagang diseret ke tepi.
