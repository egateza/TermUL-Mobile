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

Salinan ini tidak diubah dari sumbernya. Bila artifact diperbarui, salin ulang dan perbarui tanggal serta versi di atas.
