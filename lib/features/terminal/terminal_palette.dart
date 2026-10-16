import 'package:flutter/painting.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/app_settings.dart';
import '../../core/theme/termul_theme.dart';

/// Warna seleksi di terminal. xterm 4.0.0 menggambar seleksi di atas teks, bukan di bawahnya, jadi warna latar
/// `terminal-selection` yang pekat (#2C4F6B) menutupi huruf. Dipakai biru yang lebih terang dengan alpha 55%
/// supaya teks di bawahnya tetap terbaca (keputusan baru, perlu masuk ke desain; `terminal-selection-ink` tidak
/// bisa dipakai karena teks tidak digambar ulang).
const terminalSelectionOverlay = Color(0x8C3E7CA8);

/// Warna terminal untuk `xterm`. Latar, teks, kursor, seleksi, hijau (prompt), biru (path), merah, kuning, dan
/// abu-abu berasal dari token `terminal-*`, `ok`, `info`, `bad`, `accent`. Magenta dan sian tidak ada di
/// `tokens.json`; nilainya dipilih di sini supaya `htop`, `vim`, dan `ls --color` terbaca di latar gelap
/// (keputusan baru, perlu dimasukkan ke desain).
const termulTerminalTheme = TerminalTheme(
  cursor: TermulPalette.terminalCursor,
  selection: terminalSelectionOverlay,
  foreground: TermulPalette.terminalInk,
  background: TermulPalette.groundDeep,
  black: Color(0xFF1B2328),
  red: TermulPalette.bad,
  green: TermulPalette.ok,
  yellow: TermulPalette.accent,
  blue: TermulPalette.info,
  magenta: Color(0xFFD59BF6),
  cyan: Color(0xFF7FD6E0),
  white: TermulPalette.terminalInk,
  brightBlack: TermulPalette.lineStrong,
  brightRed: TermulPalette.badInk,
  brightGreen: Color(0xFF8BE8C4),
  brightYellow: Color(0xFFF7CE85),
  brightBlue: Color(0xFF9CCBFF),
  brightMagenta: Color(0xFFE6BDFB),
  brightCyan: Color(0xFFA9E8EF),
  brightWhite: TermulPalette.terminalSelectionInk,
  searchHitBackground: TermulPalette.accentLine,
  searchHitBackgroundCurrent: TermulPalette.accent,
  searchHitForeground: TermulPalette.ink,
);

/// Gaya huruf terminal dari token `terminal` (JetBrains Mono), dengan ukuran huruf dan tinggi baris dari
/// pengaturan ([TerminalSettings]). Bawaan tinggi baris 1,3, bukan 1,5 dari token `terminal`: di HP fisik 1,5 hanya
/// memuat sekitar 12 baris di landscape sehingga `htop` tak menampilkan daftar proses (keputusan baru, perlu masuk
/// ke desain: baris terminal lebih rapat daripada teks antarmuka).
TerminalStyle terminalStyleFor(TerminalSettings settings) => TerminalStyle(
  fontSize: settings.fontSize,
  height: settings.lineHeight,
  fontFamily: TermulFonts.mono,
  fontFamilyFallback: const ['monospace'],
);

/// Gaya bawaan (pengaturan bawaan).
final termulTerminalStyle = terminalStyleFor(const TerminalSettings());
