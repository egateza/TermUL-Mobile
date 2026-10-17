import 'dart:ui' show FontVariation, FontWeight;

import 'package:flutter/painting.dart' show TextStyle;

import '../../core/streak/streak.dart';
import '../../core/theme/termul_theme.dart';
import '../../core/streak/streak_tier.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/flame.dart';

/// Nama level api ("Api Merah").
String tierName(AppLocalizations l, StreakTier tier) => switch (tier) {
  StreakTier.bara => l.streakTier1,
  StreakTier.jingga => l.streakTier2,
  StreakTier.merah => l.streakTier3,
  StreakTier.magenta => l.streakTier4,
  StreakTier.ungu => l.streakTier5,
  StreakTier.biru => l.streakTier6,
  StreakTier.zamrud => l.streakTier7,
  StreakTier.emas => l.streakTier8,
  StreakTier.pelangi => l.streakTier9,
};

/// Angka streak: `N/3` di dua hari pertama (bara), `Nx` setelahnya (streak.md).
String streakCountText(AppLocalizations l, int count) =>
    count < Streak.activeFrom ? l.streakCountKindling(count) : l.streakCountActive(count);

/// Angka tanpa akhiran `x` (layar Streak dan splash): `N/3` di dua hari pertama.
String streakNumberText(AppLocalizations l, int count) =>
    count < Streak.activeFrom ? l.streakCountKindling(count) : '$count';

/// Bentuk api untuk keadaan [status].
FlameMode flameModeOf(StreakStatus status) => switch (status) {
  StreakGray() => FlameMode.gray,
  StreakFrozen() => FlameMode.frozen,
  StreakExpired() => FlameMode.reset,
  _ => FlameMode.active,
};

/// Nama api untuk pembaca layar.
String flameLabel(AppLocalizations l, FlameMode mode, int count) => switch (mode) {
  FlameMode.gray => l.streakFlameGray,
  FlameMode.frozen => l.streakFlameFrozen,
  FlameMode.reset => l.streakFlameExpired,
  FlameMode.active => tierName(l, StreakTier.of(count)),
};

String monthName(AppLocalizations l, int month) => [
  l.streakMonth1,
  l.streakMonth2,
  l.streakMonth3,
  l.streakMonth4,
  l.streakMonth5,
  l.streakMonth6,
  l.streakMonth7,
  l.streakMonth8,
  l.streakMonth9,
  l.streakMonth10,
  l.streakMonth11,
  l.streakMonth12,
][month - 1];

String monthShort(AppLocalizations l, int month) => [
  l.streakMonthShort1,
  l.streakMonthShort2,
  l.streakMonthShort3,
  l.streakMonthShort4,
  l.streakMonthShort5,
  l.streakMonthShort6,
  l.streakMonthShort7,
  l.streakMonthShort8,
  l.streakMonthShort9,
  l.streakMonthShort10,
  l.streakMonthShort11,
  l.streakMonthShort12,
][month - 1];

/// Nama hari singkat, Senin dulu.
List<String> weekdayShort(AppLocalizations l) => [
  l.streakDayMon,
  l.streakDayTue,
  l.streakDayWed,
  l.streakDayThu,
  l.streakDayFri,
  l.streakDaySat,
  l.streakDaySun,
];

/// Rentang hari absen untuk keterangan kalender: "14 Okt", "10-14 Okt", atau "30 Sep-2 Okt".
String dayRange(AppLocalizations l, DateTime from, DateTime to) {
  if (from == to) return '${from.day} ${monthShort(l, from.month)}';
  if (from.month == to.month && from.year == to.year) return '${from.day}-${to.day} ${monthShort(l, to.month)}';
  return '${from.day} ${monthShort(l, from.month)}-${to.day} ${monthShort(l, to.month)}';
}

/// Teks mono (JetBrains Mono) untuk angka streak di luar ukuran `count-*`, tebal 400 atau 500.
TextStyle streakMono(double size, {bool medium = true}) => TextStyle(
  fontFamily: TermulFonts.mono,
  fontSize: size,
  height: 1.2,
  fontWeight: medium ? FontWeight.w500 : FontWeight.w400,
  fontVariations: [FontVariation('wght', medium ? 500 : 400)],
);
