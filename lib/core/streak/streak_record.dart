import '../models/json_fields.dart';
import 'streak.dart';

/// Isi `streak.json`: streak desktop (`{"format": 1, "count": 23, "lastDay": "2026-10-13"}`) ditambah riwayat untuk
/// layar Streak (keputusan pemilik 2026-10-17): `days` (hari yang dihitung, tanggal ISO, urut naik, paling banyak
/// [maxDays]) dan `longest` (streak terpanjang). Desktop mengabaikan field tambahan, jadi berkasnya tetap terbaca di
/// sana. Riwayat mulai tercatat sejak fitur ini dipasang; hari sebelumnya tidak diketahui.
class StreakRecord {
  StreakRecord({Streak? streak, Iterable<DateTime> days = const [], int longest = 0})
    : streak = streak ?? Streak.none,
      days = _normalize(days, streak ?? Streak.none),
      longest = longest < (streak?.count ?? 0) ? streak!.count : longest;

  static const format = 1;

  /// Riwayat yang disimpan; cukup untuk kalender bulan ini dan setahun ke belakang.
  static const maxDays = 400;

  final Streak streak;

  /// Hari yang dihitung (dibuka atau dinyalakan lagi), urut naik, tanpa duplikat.
  final List<DateTime> days;

  final int longest;

  static List<DateTime> _normalize(Iterable<DateTime> days, Streak streak) {
    final set = {for (final d in days) dayOf(d)};
    final last = streak.lastDay;
    if (last != null) set.add(last);
    final sorted = set.toList()..sort();
    return List.unmodifiable(sorted.length > maxDays ? sorted.sublist(sorted.length - maxDays) : sorted);
  }

  /// Aplikasi dibuka di [today]: streak dihitung menurut aturan desktop dan hari yang dihitung dicatat.
  ({StreakRecord record, StreakEvent event}) open(DateTime today) {
    final opening = streak.open(today);
    if (identical(opening.streak, streak) || opening.streak == streak) return (record: this, event: opening.event);
    return (record: _with(opening.streak, today), event: opening.event);
  }

  /// Streak padam atau beku dinyalakan lagi di [today] (lihat [Streak.revive]).
  StreakRecord revive(DateTime today) => _with(streak.revive(today), today);

  StreakRecord _with(Streak next, DateTime today) => StreakRecord(
    streak: next,
    days: [...days, dayOf(today)],
    longest: next.count > longest ? next.count : longest,
  );

  bool isActiveDay(DateTime day) => days.contains(dayOf(day));

  factory StreakRecord.fromJson(Map<String, Object?> json) {
    final count = optInt(json, 'count') ?? 0;
    final lastText = optString(json, 'lastDay');
    final days = [
      for (final d in optList(json, 'days'))
        if (d is String) parseIsoDay(d) else throw const FormatException('Isi days bukan tanggal'),
    ];
    return StreakRecord(
      // Desktop menyamakan angka negatif dengan 0 (Math.max).
      streak: Streak(count < 0 ? 0 : count, lastText == null ? null : parseIsoDay(lastText)),
      days: days,
      longest: optInt(json, 'longest') ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'format': format,
    'count': streak.count,
    'lastDay': streak.lastDay == null ? null : isoDay(streak.lastDay!),
    'days': [for (final d in days) isoDay(d)],
    'longest': longest,
  };

  @override
  bool operator ==(Object other) {
    if (other is! StreakRecord || other.streak != streak || other.longest != longest) return false;
    if (other.days.length != days.length) return false;
    for (var i = 0; i < days.length; i++) {
      if (other.days[i] != days[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(streak, longest, Object.hashAll(days));
}
