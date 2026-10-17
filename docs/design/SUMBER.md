# Sumber dokumentasi desain

Tanggal salin: 2026-10-15

**Versi terkini (2026-10-17):** design system versi 49 (`1792236452-92dc`; dari versi 48 `README.md`, `components/Icon/README.md` (ikon `link`), dan `design-system.json` berubah), prototipe versi 51 (`1792236450-1abf`; dari versi 50 `canvas.json` dan berkas baru `SftpLinks.dc.html` (contoh 4m)). Rincian sebelumnya: design system versi 48 (`1792235871-a469`; dari versi 47 hanya `README.md` (toast muat ulang SFTP) dan `design-system.json` yang berubah), prototipe versi 50. Rincian sebelumnya: design system versi 47 (`1792235257-3479`; dari versi 46 hanya `README.md` (seleksi ganda dan unduh folder) dan `design-system.json` (`lastChange`) yang berubah), prototipe versi 50 (`1792235241-ca17`; dari versi 49 berubah `canvas.json` dan dua berkas baru `SftpSelect.dc.html` (contoh 4k) dan `SftpTransferFolder.dc.html` (contoh 4l)). Sebelum publish, `README.md` dan `canvas.json` lokal dicek sama dengan artifact (sha256 `README.md` 83c3173e…, `canvas.json` 530ef771…); keduanya dirender di Chrome tanpa galat. Rincian sebelumnya: design system versi 46 (`1792233900-8950`; dari versi 45 hanya `README.md` (tombol kembali ke folder sebelumnya) dan `design-system.json` yang berubah), prototipe versi 49 (tidak berubah). Rincian sebelumnya: design system versi 45 (`1792233457-77e8`) dan 44 (`1792232765-ec9e`), prototipe versi 49 (`1792232756-4d1f`; dari versi 48 berubah `SftpOverwrite.dc.html` (tiga pilihan, prop `device`), `canvas.json`, dan berkas baru `SftpConflictDownload.dc.html`). Rincian versi sebelumnya: design system versi 43 (`1792231969-73d4`) dan prototipe versi 48 (`1792231961-c27d`); design system versi 42 (`1792203252-1828`) dan prototipe versi 47 (`1792203239-69e9`); design system versi 41 (`1792202208-a22d`) dan prototipe versi 46 (`1792202186-fc19`); design system versi 40 (`1792196865-8415`; dari versi 38 hanya `README.md` dan `components/Banner/README.md` yang berubah: banner dan form host di layar pendek), prototipe versi 45 (`1792196856-20b9`; dari versi 43 berubah `TerminalLandscape.dc.html` (prop `waiting`), `canvas.json`, dan dua berkas baru `TerminalLandscapeWaiting.dc.html` (contoh 2n) dan `HostFormLandscape.dc.html` (contoh 1c)). Salinan di `docs/design/` sama dengan kedua artifact untuk semua berkas yang diubah sejak salinan awal (dibandingkan dengan berkas yang dipublish); daftar "Versi artifact" di bawah adalah versi **salinan awal**, perubahannya tercatat di bagian "Perubahan lokal". Aturan: desain diikuti, tambahan masuk ke artifact, yang belum bisa diterapkan hanya diberi catatan (`CLAUDE.md` butir 8).

## Design system

- URL: https://claude.ai/artifact/HgnCv9wwMUjoKTbKWZCLC8
- Versi artifact: 1792066876-abe7
- Lokasi: `docs/design/`
- Berkas (dari `project/` di artifact):
  - README.md
  - tokens.json
  - flutter.md
  - motion.md
  - streak.md
  - android.md
  - spike.md
  - spike-temuan.md
- Dokumentasi komponen (dari `project/components/*/README.md` di artifact), versi artifact 1792066876-abe7 (sama dengan berkas di atas; dicek ulang 2026-10-15, belum berubah), disalin ke `docs/design/components/<Nama>/README.md` (19 berkas, 11.075 byte), tanggal salin 2026-10-15:
  Banner, BottomSheet, Button, Card, Chip, Flame, HostRow, Icon, IconButton, KeyButton, NavBar, Progress, Segmented, StatusDot, StreakChip, Switch, TerminalSurface, TextField, Toast.
  Berkas `preview.html`, `bundle.js`, `bundle.css`, dan `index.d.ts` komponen tidak disalin (kode web, bukan rujukan untuk Flutter).

## Prototipe

- URL: https://claude.ai/artifact/NuqW6CFHpfe5TF3Xdv38HX
- Versi artifact: 1792066807-38e8
- Lokasi: `docs/design/prototype/`
- Hanya rujukan visual, bukan kode yang dipindahkan. Aplikasinya Flutter.
- Berkas `*.dc.html` memuat `./support.js`. Berkas itu tidak ada di daftar yang diminta pada salinan awal, jadi awalnya prototipe tidak bisa dibuka mandiri. **Ditambahkan 2026-10-15** (atas permintaan pemilik): `support.js` adalah salinan byte-demi-byte `artifact-type/dc-runtime.js` dari artifact yang sama (versi 1792066807-38e8, 187.897 byte, sha256 `3f160299989dc595cf434dac7b7f3e6fd20ed015a2d99e075c3eac09dffe0f10`; memuat React MIT dan runtime desain; kode pihak ketiga yang di-minify, hanya untuk rujukan visual). Ini satu-satunya berkas di `prototype/` yang namanya berbeda dari sumbernya.
- Cara melihat: buka `Main.dc.html` dan sejenisnya di Chrome (`file://`, lebar 390 px; `TerminalLandscape` 844x390), atau tangkap layar dengan `chrome --headless=new --window-size=390,844 --virtual-time-budget=8000 --screenshot=...`. Font diambil dari Google Fonts, jadi butuh internet.
- Diperiksa 2026-10-15: `Main`, `HostKey`, `Terminal`, `Settings`, dan `TerminalLandscape` tampil. Berkas pembungkus kecil (mis. `StreakBeku`, `TerminalReconnect`) bergantung pada `dc-import` bersarang dan hanya diperiksa sebagian; ikon api di chip streak tampil sebagai kotak penampung.

- Berkas (dari `project/` di artifact):
  - canvas.json
  - support.js (ditambahkan kemudian; lihat catatan di atas)
  - FlameArt, HostKey, Main, Settings, SettingsFg, Sftp, SnippetNew, Snippets (`.dc.html`)
  - Streak, StreakActive, StreakBara, StreakBeku, StreakHangus, StreakPadam (`.dc.html`)
  - StreakScreenBeku, StreakScreenPadam, StreakSplash, StreakTiers (`.dc.html`)
  - SudoSheet, Terminal, TerminalLandscape, TerminalLandscapeKb (`.dc.html`)
  - TerminalPaste, TerminalPasteMenu, TerminalReconnect, TerminalReconnectPlain (`.dc.html`)
  - WidgetFavorit, WidgetGallery, WidgetStreak, Widgets (`.dc.html`)

Salinan ini tidak diubah dari sumbernya kecuali yang tercatat di bagian "Perubahan lokal" di bawah. Bila artifact diperbarui, salin ulang dan perbarui tanggal serta versi di atas.

## Perubahan lokal (2026-10-16), sudah di-publish ke artifact

Dibuat bersama menu setting (lihat `docs/implementation-plan.md`, bagian 11a). **Sudah di-publish 2026-10-16** atas persetujuan pemilik: design system menjadi versi 20 (`1792121434-7216`), prototipe versi 33 (`1792121460-ecc0`). Sebelum itu dicek bahwa isi berkas sumber yang diubah sama dengan salinan lokal (sha256 sama), walau nomor versi artifact sudah naik dari salinan awal (`abe7` dan `38e8`). Salinan lokal dan artifact kini sama untuk berkas di bawah; selain itu salinan lain dari 2026-10-15 belum dibandingkan ulang dengan versi artifact terbaru. Di design system, `design-system.json` hanya berubah pada `lastChange`.

Design system:
- `components/Stepper/README.md`: **berkas baru** (komponen `Stepper`; di artifact path `project/components/Stepper/README.md`).
- `README.md`: `Stepper` ditambahkan ke daftar input; bagian baru "Catatan dari implementasi Flutter" (Android saja, Pengaturan dibuka dari ikon di header Host selagi `NavBar` belum ada, tinggi baris terminal bawaan 1,3, warna ANSI magenta dan sian, konfirmasi keluar, sambung ulang otomatis sekali, penguncian tiga tingkat, tombol Fn).
- `flutter.md`: dua butir di akhir (tema konstanta statis; pengaturan terminal lewat `Notifier`).
- Tidak diubah: `tokens.json`, `components/index.d.ts`, `bundle.js`, `preview.html`. `Stepper` belum ada di kode web komponen.

Prototipe:
- `prototype/Settings.dc.html`: rentang ukuran font 10-20 menjadi 8-24 px, baris baru "Tinggi baris" (1,0 sampai 2,0, langkah 0,1, bawaan 1,3), pratinjau memakai tinggi baris itu (sebelumnya tetap 1,5). Sudah dirender di Chrome tanpa galat.
- `prototype/Main.dc.html` **tidak diubah**: ikon pengaturan di header Host adalah jalan masuk sementara di Flutter, sedangkan prototipe tetap memakai `NavBar` lima tab.

## Perubahan lokal lanjutan (2026-10-16, foreground service)

- `android.md`: status diperbarui dan bagian baru "Implementasi" (bukti dari HP, perilaku, apa yang teruji dan belum). Isi rancangan di bagian lain tidak diubah. Sudah di-publish ke design system (versi 21, `1792125397-d101`) bersama pembaruan `design-system.json` (`lastChange`). Tabel "Deklarasi dan izin" diperbarui: tipe `specialUse` dan izinnya dikonfirmasi di dokumentasi resmi; nama service di contoh manifest menjadi `.KeepAliveService`.

## Perubahan lokal lanjutan (2026-10-16, tempel di terminal)

- **Sudah di-publish** (design system versi 22, `1792126727-a0ce`): `README.md`: dua butir baru di "Catatan dari implementasi Flutter" (letak tombol Tempel, aturan dialog, varian tanpa tempel aman, karakter kontrol, batas ukuran). Prototipe `Terminal.dc.html` **tidak diubah**: varian tanpa tempel aman dan tombol Tempel di baris tombol cepat belum tergambar di prototipe.
- Pada publish yang sama, butir Pengaturan di `README.md` diperbarui (bagian Koneksi sudah ada, bukan lagi "belum dibuat").

## Perubahan lokal lanjutan (2026-10-16, seleksi dan salin teks)

- **Sudah di-publish** (design system versi 23, `1792132127-c203`): `README.md` dua butir baru di "Catatan dari implementasi Flutter" (seleksi dan salin: gagang, kaca pembesar, bilah seleksi, yang belum dibuat; warna seleksi tembus pandang), `components/TerminalSurface/README.md` satu butir warna seleksi, `design-system.json` (`lastChange`). Sebelum itu dicek bahwa salinan lokal kedua berkas sama dengan isi artifact. Prototipe `Terminal.dc.html` **tidak diubah**: bilah seleksinya masih memuat Cari, Kirim, Snippet, Bagikan, dan belum menggambar gagang, kaca pembesar, tombol Tempel di baris tombol cepat, serta varian tanpa tempel aman. `tokens.json` tidak diubah (`terminal-selection` tetap nilai desain; aplikasi memakai warna tembus pandang yang dicatat di README).

## Perubahan lokal lanjutan (2026-10-16, prototipe Terminal disesuaikan)

- **Sudah di-publish** (prototipe versi 34, `1792132712-5fa3`): `prototype/Terminal.dc.html` (hint bilah seleksi "Seret gagang untuk mengubah pilihan", warna seleksi `#3E7CA8` alpha 55% dengan teks tetap berwarna aslinya, gagang `accent` dengan tepi `ground`, tombol Tempel di baris tombol cepat, kaca pembesar lewat properti `lens`, varian tempel tanpa tempel aman lewat properti `bracketed="mati"` dengan pilihan aman jadi tombol utama), dua contoh layar baru `prototype/TerminalPasteUnsafe.dc.html` (2h) dan `prototype/TerminalSelectLens.dc.html` (2i), dan `prototype/canvas.json` (dua papan baru di x 2000 dan 2470, y 5732). Sebelum itu dicek bahwa `Terminal.dc.html` di artifact identik dengan salinan lokal sebelum diubah. Dirender di Chrome tanpa galat.
- `README.md` design system: kalimat "prototipe tidak diubah" diperbarui (design system dipublish ulang sebagai versi berikutnya).

## Perubahan lokal lanjutan (2026-10-16, desain tetap diikuti)

Aturan pemilik (dicatat di `CLAUDE.md` butir 8): desain sistem dan prototipe harus diikuti; tambahan dimasukkan ke artifact; yang tidak atau belum bisa diterapkan hanya diberi catatan, desainnya dipertahankan. Karena itu perubahan pada publish sebelumnya yang mengubah desain agar cocok dengan aplikasi dibatalkan:

- **Sudah di-publish:** prototipe versi 35 (`1792132943-afd3`): `Terminal.dc.html` dikembalikan untuk hint bilah ("Ketuk kata lain untuk memperluas pilihan"), warna seleksi (`#2C4F6B`, teks `#F4F8FA`), dan gagang (`#6CB4FF`). Tambahan tetap ada: kaca pembesar (properti `lens`, contoh 2i), varian tempel tanpa tempel aman (properti `bracketed`, contoh 2h), tombol Tempel di baris tombol cepat. Design system versi 25 (`1792132941-49dc`): `README.md` memisahkan tambahan (kaca pembesar, gagang dijepit di dalam layar) dari catatan "belum bisa diterapkan" (petunjuk bilah, warna seleksi, aksi yang belum dibuat); `TerminalSurface/README.md` memberi catatan bahwa warna seleksi aplikasi sementara.
- **Aplikasi mengikuti desain:** gagang seleksi memakai warna `info` dan bentuk prototipe (bulatan 14 dp dengan tangkai 2 x 4 dp), bukan `accent`.
- **Belum bisa mengikuti desain:** warna seleksi (xterm 4.0.0 menggambar seleksi di atas teks; aplikasi memakai `#3E7CA8` alpha 55%) dan petunjuk bilah (xterm menghapus seleksi saat diketuk).

## Perubahan lokal lanjutan (2026-10-16, gagang seleksi)

- Pemilik lebih memilih gagang seleksi berwarna `accent` bertepi `ground`. Aplikasi memakai itu; prototipe (gagang `info` bertangkai) **tidak diubah** dan perbedaannya dicatat di `README.md` design system (versi 26, `1792133660-c984`).
- Gagang kemudian dibentuk menjadi tetesan air (bulatan dengan ujung runcing ke teks) atas permintaan pemilik; README design system versi 27 (`1792133960-e2b6`) mencatatnya, prototipe tetap tidak diubah.

## Perubahan lokal lanjutan (2026-10-16, pilihan bentuk gagang seleksi)

- Tambahan atas permintaan pemilik: pengaturan "Bentuk gagang seleksi" (Tetesan, Segitiga, Bulatan) di Pengaturan, bagian Terminal. Di artifact: `prototype/Settings.dc.html` (baris baru dengan `Segmented` dan pratinjau bentuk, di antara "Tinggi baris" dan "Tema"; dirender di Chrome tanpa galat) dan `README.md` design system (butir seleksi). **Sudah di-publish:** prototipe versi 36 (`1792134367-fce0`) dan design system versi 28 (`1792134370-edd2`). Sebelum itu dicek bahwa `Settings.dc.html` di artifact identik dengan salinan lokal sebelum diubah.
- Segitiga pada pilihan bentuk gagang diperkecil atas permintaan pemilik (setengah sudut 28 derajat, jarak 3 dp, pusat bulatan 15 dp dari ujung); `prototype/Settings.dc.html` ikut disesuaikan dan dipublish sebagai prototipe versi 37 (`1792134537-aa46`).
- Ujung gagang dibuat dinamis atas permintaan pemilik (miring ke titik seleksi di tepi layar, dibalik di baris paling bawah); dicatat di `README.md` design system versi 29 (`1792134879-4374`). Prototipe tidak diubah (pratinjau `Settings` menggambar gagang tegak lurus).
- Ujung gagang yang miring diperbaiki supaya bentuknya tidak memanjang (berputar utuh, sudut paling 45 derajat); README design system versi 30 (`1792135132-6f35`) memperbarui catatannya.

## Perubahan lokal lanjutan (2026-10-16, sesi di latar belakang)

- Tambahan atas permintaan pemilik: pilihan "Tetap terhubung di latar belakang" saat keluar dari terminal dan layar Sesi aktif. Di artifact: `prototype/Sessions.dc.html` (12, baru), `prototype/TerminalLeave.dc.html` (2j, baru), `prototype/canvas.json` (dua papan baru: x 3290 y 964 dan x 2940 y 5732), dan `README.md` design system (dua butir: perilaku sesi di latar belakang dan catatan "belum bisa diterapkan" untuk `NavBar` dan tab sesi). Dirender di Chrome tanpa galat. **Sudah di-publish:** prototipe versi 38 (`1792136358-c0f1`) dan design system versi 31 (`1792136361-50f1`).

## Perubahan lokal lanjutan (2026-10-16, sambung ulang, NavBar lima tab, layar sementara)

Berkas artifact dibaca dulu lewat `read` dan hash-nya sama dengan salinan lokal sebelum diubah. Diedit di folder staging, dirender di Chrome (`ComingSoon`, `Boot`, dan `Terminal` dengan dua nilai `connection` baru tanpa galat), lalu dipublish.

- **Prototipe versi 39 (`1792156922-600e`):** `Terminal.dc.html` mendapat dua nilai `connection` baru, `menunggu` (banner `warn` dengan hitungan mundur dan tombol "Sambung sekarang") dan `verifikasi` (banner "Perlu verifikasi" dengan tombol "Tampilkan prompt"); berkas baru `TerminalWaiting` (2k), `TerminalNeedsAuth` (2l), `ComingSoon` (13, tab SFTP dan Snippet yang belum tersedia, dengan `NavBar` lima tab) dan `Boot` (14, layar "Memuat…"); `canvas.json` memuat empat papan baru (x 3410 y 5732, x 3880 y 5732, x 3760 y 964, x 4230 y 964). Papan lama tidak diubah.
- **Design system versi 33 (`1792156945-0858`):** `README.md` bagian "Catatan dari implementasi Flutter": catatan Pengaturan (kini tab di `NavBar`), butir sambung ulang diganti (jeda bertingkat, banner menunggu, rahasia dipegang selama layar menyala dan dilepas saat layar mati, banner "Perlu verifikasi", gerbang prompt), butir gulir otomatis seleksi dipindah dari "belum dibuat" menjadi tambahan, butir `NavBar` lima tab (menggantikan "belum bisa mengikuti desain"), butir layar sementara SFTP dan Snippet, dan butir layar pemuatan.
- Komponen `NavBar` (README komponen) tidak diubah: bar di aplikasi mengikuti spesifikasinya dan prototipe `Main`.

## Popover Tempel, saklar konfirmasi, warna seleksi (2026-10-16)

Berkas artifact dibaca dulu dan hash-nya sama dengan salinan lokal sebelum diubah (`README.md`, `Terminal`, `Settings`, `canvas.json`). Diedit di folder staging, `Terminal` dan `Settings` dirender di Chrome (popover terpotong di tepi kiri pada render pertama, lalu dipusatkan pada kursor), lalu dipublish.

- **Prototipe versi 40 (`1792164108-c1dd`):** `Terminal.dc.html`: popover Tempel kini menampilkan teks yang akan ditempel (mono, satu baris, dipotong dengan elipsis), keterangan "Masuk ke prompt, belum dijalankan", dan tombol Tempel; dipusatkan pada kursor, bukan rata kanan. Alurnya: satu baris pendek (sampai 40 karakter) yang aman tampil di popover; lebih panjang dari 40 karakter, banyak baris, atau berisiko masuk dialog. `Settings.dc.html`: saklar baru "Konfirmasi tempel satu baris" (bawaan nyala) di bawah kartu Terminal. `TerminalPasteMenu.dc.html` memakai papan klip `aman` (contoh 2b); judul 2b di `canvas.json` menjadi "Contoh: popover Tempel (satu baris pendek)".
- **Design system versi 34 (`1792164121-e56d`):** `README.md`, "Catatan dari implementasi Flutter": butir Tempel ditulis ulang (popover, dua pemicu: tombol Tempel dan tekan-tahan di area kosong, ambang 40 karakter, saklar), butir Pengaturan menyebut saklar "Konfirmasi tempel satu baris" dan "Sambung ulang otomatis", dan warna seleksi dicatat sebagai diterima pemilik (xterm tidak ditambal).
- Pemicu tekan-tahan di area kosong hanya ada di aplikasi; prototipe memicunya lewat ketukan di kursor (tidak bisa meniru tekan-tahan di area kosong tanpa kursor). Dicatat di README.
- **Design system versi 35 (`1792164891-6272`):** `README.md`, butir Tempel: pemicu tekan-tahan juga aktif di layar alternatif dan mouse mode (`tmux`, `vim`, `htop`) selama yang ditekan sel kosong (sebelumnya dinyatakan tidak aktif); ketukan di mana saja di luar popover (terminal, bar atas, tombol cepat) menutupnya. Prototipe tidak diubah (tetap versi 40).

## Landscape layar utama (2026-10-16)

Berkas artifact dibaca dulu dan hash-nya sama dengan salinan lokal (`README.md` dan `components/NavBar/README.md`; `canvas.json` dari versi 40 yang baru dipublish). Contoh baru dirender di Chrome (844 x 390) sebelum dipublish.

- **Prototipe versi 41 (`1792166021-e467`):** berkas baru `MainLandscape.dc.html` (contoh 1b, 844 x 390): rel navigasi di kiri, header satu baris (judul Host, pencarian, chip Semua dan Favorit, tombol tambah), dan daftar host satu kolom. `canvas.json` mendapat papan baru di akhir `order`.
- **Design system versi 36 (`1792166030-cba5`):** `README.md` bagian Batasan (landscape kini juga untuk layar utama) dan butir baru "Layar utama di landscape" di catatan implementasi; `components/NavBar/README.md` mendapat varian rel.
- **Pembaruan atas temuan pemilik (prototipe versi 42, `1792166610-11cb`; design system versi 37, `1792166613-3902`):** `MainLandscape.dc.html`: dropdown filter "Semua" menggantikan chip Semua dan Favorit, rel 80 px dengan tab 48 px yang dipusatkan. `README.md`: butir landscape menyebut dropdown, rel 80 dp, dan perilaku saat keyboard terbuka (rel, judul, dropdown, tombol tambah, dan judul grup disembunyikan); `components/NavBar/README.md`: rel 80px, tab 48px, hilang saat keyboard terbuka.
- **Popover Tempel di landscape dengan keyboard (prototipe versi 43, `1792167502-ed31`; design system versi 38, `1792167505-69e0`):** `TerminalLandscape.dc.html` mendapat prop `paste` (popover mendatar di atas baris prompt), berkas baru `TerminalLandscapePaste.dc.html` (contoh 2m), dan `canvas.json` papan baru; `README.md` butir Tempel menyebut susunan mendatar di layar pendek dan batas area aman. Dirender di Chrome sebelum dipublish.

## SFTP: layar jelajah dan konfirmasi keluar (2026-10-17)

Berkas artifact dibaca dulu dan hash-nya sama dengan salinan lokal (`README.md`, `components/Icon/README.md`, `canvas.json`, `TerminalLeave.dc.html`). Contoh baru dirender di Chrome (390 x 844) sebelum dipublish; `Sftp.dc.html` (layar 4) tidak diubah.

- **Prototipe versi 46 (`1792202186-fc19`):** berkas baru `SftpSources.dc.html` (contoh 4b: pilih sumber, sesi terbuka dan koneksi sendiri; prop `withSessions`), `SftpLeave.dc.html` (4c: sheet "Keluar dari SFTP?"; prop `busy`), `SftpLeaveBusy.dc.html` (4d: varian dengan transfer berjalan, mengimpor `SftpLeave busy`), dan `SftpLost.dc.html` (4e: subjudul "terputus" dan banner Sambung ulang). `canvas.json` mendapat empat papan di baris y=6672.
- **Design system versi 41 (`1792202208-a22d`):** `README.md`: butir "SFTP dan Snippet" menjadi butir Snippet (SFTP sudah dibangun) dan butir baru "SFTP (tambahan, 2026-10-17)" di catatan implementasi (layar pilih sumber, jelajah, Salin path, sambungan putus, SFTP tidak tersedia, konfirmasi keluar selalu, varian dengan transfer, dan yang belum bisa sesuai desain layar 4: Unggah, Unduh, Edit, dan membuka dari terminal); `components/Icon/README.md`: catatan ikon `file`; `design-system.json`: `lastChange`.

## SFTP: sambung ulang otomatis (2026-10-17)

- **Prototipe versi 47 (`1792203239-69e9`):** `SftpLost.dc.html` mendapat prop `state` (`lost`, `waiting`, `auth`; teks banner mengikuti terminal), dua berkas baru `SftpWaiting.dc.html` (contoh 4f: "Menunggu server terjangkau…" dengan hitungan mundur) dan `SftpNeedsAuth.dc.html` (4g: "Perlu verifikasi"), dan `canvas.json` dua papan baru. Dirender di Chrome sebelum dipublish.
- **Design system versi 42 (`1792203252-1828`):** `README.md`, butir SFTP: sambung ulang otomatis dengan mekanisme terminal (probe, jeda bertingkat, rahasia dipegang selama layar menyala, saklar "Sambung ulang otomatis", folder dipulihkan, sesi dipinjam mengikuti sesinya, transfer dibatalkan saat putus); `design-system.json`: `lastChange`.

## SFTP: unduh dan unggah (2026-10-17)

- **Prototipe versi 48 (`1792231961-c27d`):** berkas baru `SftpTransfer.dc.html` (contoh 4h: panel transfer dengan persen dan tombol batal, bar pilihan Unduh dan Salin path, header dengan tombol Unggah) dan `SftpOverwrite.dc.html` (4i: sheet "Timpa nama?", Batal sebagai tombol utama); `canvas.json` dua papan baru. Dirender di Chrome sebelum dipublish.
- **Design system versi 43 (`1792231969-73d4`):** `README.md`, butir SFTP: unduh ke Unduhan/TermUL, panel transfer, batal, galat, konfirmasi menimpa, berkas sementara `.termul-part`, dan yang belum bisa sesuai desain (Edit, buka dari terminal); `components/Icon/README.md`: ikon `upload` dan `download`; `design-system.json`: `lastChange`.

## SFTP: nama berkas sudah ada (2026-10-17)

- **Prototipe versi 49 (`1792232756-4d1f`):** `SftpOverwrite.dc.html` (contoh 4i) kini sheet tiga pilihan "nama sudah ada" (Simpan sebagai nama (1).ext sebagai tombol utama, Timpa berkas lama `danger`, Batal; prop `device` untuk teks unduhan); berkas baru `SftpConflictDownload.dc.html` (contoh 4j, varian unduhan). Dirender di Chrome sebelum dipublish.
- **Design system versi 44 (`1792232765-ec9e`):** `README.md`, butir SFTP: paragraf "Timpa nama?" diganti penjelasan tiga pilihan untuk unggah dan unduh, batas Android (hanya berkas milik aplikasi yang dikenali dan ditimpa), dan toast "Ditimpa di ...".
