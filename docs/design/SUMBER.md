# Sumber dokumentasi desain

Tanggal salin: 2026-10-15

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

