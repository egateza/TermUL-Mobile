import 'package:flutter/painting.dart';
import 'package:xterm/xterm.dart';

import '../../core/theme/termul_theme.dart';

/// Warna terminal untuk `xterm`. Latar, teks, kursor, seleksi, hijau (prompt), biru (path), merah, kuning, dan
/// abu-abu berasal dari token `terminal-*`, `ok`, `info`, `bad`, `accent`. Magenta dan sian tidak ada di
/// `tokens.json`; nilainya dipilih di sini supaya `htop`, `vim`, dan `ls --color` terbaca di latar gelap
/// (keputusan baru, perlu dimasukkan ke desain).
const termulTerminalTheme = TerminalTheme(
  cursor: TermulPalette.terminalCursor,
  selection: TermulPalette.terminalSelection,
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

/// Gaya huruf terminal dari token `terminal` (JetBrains Mono).
final termulTerminalStyle = TerminalStyle(
  fontSize: TermulText.terminal.fontSize!,
  height: TermulText.terminal.height!,
  fontFamily: TermulFonts.mono,
  fontFamilyFallback: const ['monospace'],
);
