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
- Input: `TextField` (pencarian dan form), `Switch` (baris pengaturan dengan deskripsi), `Segmented` (2-4 pilihan eksklusif), `Chip` (filter, tag, level).
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
