import 'dart:ui' show Color;

import '../theme/termul_theme.dart';

/// Level api menurut jumlah hari streak (desktop `StreakTier`; token `tier-n-*` dan `level-n`). Level atas
/// mendapat lidah api, percikan, dan bintang.
enum StreakTier {
  bara(1, TermulPalette.tier1Outer, TermulPalette.level1, TermulPalette.tier1Core, TermulPalette.tier1Glow, 0, 0),
  jingga(3, TermulPalette.tier2Outer, TermulPalette.level2, TermulPalette.tier2Core, TermulPalette.tier2Glow, 0, 1),
  merah(10, TermulPalette.tier3Outer, TermulPalette.level3, TermulPalette.tier3Core, TermulPalette.tier3Glow, 1, 2),
  magenta(30, TermulPalette.tier4Outer, TermulPalette.level4, TermulPalette.tier4Core, TermulPalette.tier4Glow, 1, 2),
  ungu(60, TermulPalette.tier5Outer, TermulPalette.level5, TermulPalette.tier5Core, TermulPalette.tier5Glow, 2, 3),
  biru(100, TermulPalette.tier6Outer, TermulPalette.level6, TermulPalette.tier6Core, TermulPalette.tier6Glow, 2, 3),
  zamrud(180, TermulPalette.tier7Outer, TermulPalette.level7, TermulPalette.tier7Core, TermulPalette.tier7Glow, 2, 4),
  emas(365, TermulPalette.tier8Outer, TermulPalette.level8, TermulPalette.tier8Core, TermulPalette.tier8Glow, 2, 4),
  pelangi(730, TermulPalette.tier9Outer, TermulPalette.level9, TermulPalette.tier9Core, TermulPalette.tier9Glow, 2, 5);

  const StreakTier(this.min, this.outer, this.mid, this.core, this.glow, this.tongues, this.sparks);

  /// Hari pertama level ini.
  final int min;
  final Color outer;

  /// Lapis tengah; juga warna level di teks, lencana, dan chip.
  final Color mid;
  final Color core;
  final Color glow;

  /// Lidah api tambahan di kiri (1) atau kiri dan kanan (2).
  final int tongues;

  /// Jumlah percikan.
  final int sparks;

  /// Nomor level 1-9.
  int get level => index + 1;

  /// Bintang berkilau di sekitar api (Emas dan Pelangi).
  bool get stars => this == emas || this == pelangi;

  /// Warna berputar saat beranimasi.
  bool get rainbow => this == pelangi;

  /// Level berikutnya; null untuk Pelangi.
  StreakTier? get next => this == pelangi ? null : values[index + 1];

  static StreakTier of(int count) {
    for (var i = values.length - 1; i > 0; i--) {
      if (count >= values[i].min) return values[i];
    }
    return bara;
  }
}
