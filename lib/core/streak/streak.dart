/// Aturan streak api, port dari TermUL desktop (`core/streak/Streak.java`, `StreakStatus`, `StreakEvent`, commit
/// `b3d7854150`). Satu hari = tanggal kalender lokal; membuka berkali-kali di hari yang sama dihitung satu.
///
/// - Hari ke-1 dan ke-2 masih "bara"; streak aktif mulai hari ke-[Streak.activeFrom].
/// - Streak aktif lalu absen 1-2 hari: padam, dinyalakan lagi dengan tiga ketukan cepat.
/// - Absen 3-[Streak.maxFrozenMissed] hari: beku, dipecahkan dengan [clicksToThaw] ketukan.
/// - Absen lebih lama: hangus, mulai lagi dari hari ke-1.
///
/// Memulihkan (padam atau beku) tidak menghapus angka streak dan hari ini ikut dihitung; hari yang bolong tidak.
library;

/// Tanggal kalender tanpa jam: tengah malam UTC dari tanggal lokal [t], supaya selisih hari tidak terganggu
/// pergantian jam musim panas.
DateTime dayOf(DateTime t) => DateTime.utc(t.year, t.month, t.day);

/// Selisih hari dari [from] ke [to]; keduanya hasil [dayOf].
int daysBetween(DateTime from, DateTime to) => to.difference(from).inDays;

/// Tanggal ISO (`2026-10-13`), format yang sama dengan `streak.json` desktop.
String isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

final _isoDay = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Membaca tanggal ISO; melempar [FormatException] untuk teks yang bukan tanggal sah (mis. `2026-02-30`).
DateTime parseIsoDay(String text) {
  final m = _isoDay.firstMatch(text);
  if (m == null) throw FormatException('Bukan tanggal ISO', text);
  final day = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  if (isoDay(day) != text) throw FormatException('Tanggal tidak ada', text);
  return day;
}

/// Jumlah ketukan untuk memecahkan es: 5 untuk absen 3 hari, naik satu per hari, maksimal 10.
int clicksToThaw(int missed) => (5 + (missed - 3)).clamp(5, 10);

/// Keadaan streak di satu hari (lihat [Streak.status]).
sealed class StreakStatus {
  const StreakStatus();
}

/// Belum pernah dibuka, atau bara yang bolong sehari (mulai lagi saat dibuka).
final class StreakNone extends StreakStatus {
  const StreakNone();

  @override
  bool operator ==(Object other) => other is StreakNone;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'StreakNone';
}

/// Hari ke-1 atau ke-2: belum aktif, tampil sebagai bara `day/3`.
final class StreakKindling extends StreakStatus {
  const StreakKindling(this.day);

  final int day;

  @override
  bool operator ==(Object other) => other is StreakKindling && other.day == day;

  @override
  int get hashCode => Object.hash(1, day);

  @override
  String toString() => 'StreakKindling($day)';
}

/// Streak aktif dan sudah dihitung hari ini.
final class StreakBurning extends StreakStatus {
  const StreakBurning(this.count);

  final int count;

  @override
  bool operator ==(Object other) => other is StreakBurning && other.count == count;

  @override
  int get hashCode => Object.hash(2, count);

  @override
  String toString() => 'StreakBurning($count)';
}

/// Absen 1-2 hari: api padam (abu-abu), dinyalakan lagi dengan tiga ketukan cepat.
final class StreakGray extends StreakStatus {
  const StreakGray(this.count, this.missed);

  final int count;
  final int missed;

  @override
  bool operator ==(Object other) => other is StreakGray && other.count == count && other.missed == missed;

  @override
  int get hashCode => Object.hash(3, count, missed);

  @override
  String toString() => 'StreakGray($count, missed: $missed)';
}

/// Absen 3-10 hari: api beku, butuh [clicks] ketukan untuk memecahkan es.
final class StreakFrozen extends StreakStatus {
  const StreakFrozen(this.count, this.missed, this.clicks);

  final int count;
  final int missed;
  final int clicks;

  @override
  bool operator ==(Object other) =>
      other is StreakFrozen && other.count == count && other.missed == missed && other.clicks == clicks;

  @override
  int get hashCode => Object.hash(4, count, missed, clicks);

  @override
  String toString() => 'StreakFrozen($count, missed: $missed, clicks: $clicks)';
}

/// Absen lebih dari 10 hari: streak [count] hari hangus.
final class StreakExpired extends StreakStatus {
  const StreakExpired(this.count, this.missed);

  final int count;
  final int missed;

  @override
  bool operator ==(Object other) => other is StreakExpired && other.count == count && other.missed == missed;

  @override
  int get hashCode => Object.hash(5, count, missed);

  @override
  String toString() => 'StreakExpired($count, missed: $missed)';
}

/// Apa yang terjadi saat aplikasi dibuka (lihat [Streak.open]); menentukan splash yang diputar.
sealed class StreakEvent {
  const StreakEvent();
}

/// Sudah dihitung hari ini: tidak ada splash.
final class StreakSameDay extends StreakEvent {
  const StreakSameDay();

  @override
  bool operator ==(Object other) => other is StreakSameDay;

  @override
  int get hashCode => 10;

  @override
  String toString() => 'StreakSameDay';
}

/// Hari ini dihitung: streak naik dari [from] ke [to] ([from] 0 = mulai baru).
final class StreakCounted extends StreakEvent {
  const StreakCounted(this.from, this.to);

  final int from;
  final int to;

  @override
  bool operator ==(Object other) => other is StreakCounted && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(11, from, to);

  @override
  String toString() => 'StreakCounted($from -> $to)';
}

/// Streak padam atau beku dan menunggu dinyalakan lagi; angka belum berubah.
final class StreakNeedsRevival extends StreakEvent {
  const StreakNeedsRevival(this.status);

  /// [StreakGray] atau [StreakFrozen].
  final StreakStatus status;

  @override
  bool operator ==(Object other) => other is StreakNeedsRevival && other.status == status;

  @override
  int get hashCode => Object.hash(12, status);

  @override
  String toString() => 'StreakNeedsRevival($status)';
}

/// Streak [lost] hari hangus setelah absen [missed] hari; hari ini jadi hari ke-1.
final class StreakExpiredEvent extends StreakEvent {
  const StreakExpiredEvent(this.lost, this.missed);

  final int lost;
  final int missed;

  @override
  bool operator ==(Object other) => other is StreakExpiredEvent && other.lost == lost && other.missed == missed;

  @override
  int get hashCode => Object.hash(13, lost, missed);

  @override
  String toString() => 'StreakExpiredEvent(lost: $lost, missed: $missed)';
}

/// Hasil [Streak.open]: streak baru (simpan bila berubah) dan apa yang terjadi.
class StreakOpening {
  const StreakOpening(this.streak, this.event);

  final Streak streak;
  final StreakEvent event;
}

/// Streak harian: berapa hari berturut-turut TermUL dibuka. Immutable.
class Streak {
  /// [count] 0 atau [lastDay] null berarti belum pernah dibuka; keduanya disamakan menjadi kosong.
  Streak(int count, DateTime? lastDay)
    : count = (count <= 0 || lastDay == null) ? 0 : count,
      lastDay = (count <= 0 || lastDay == null) ? null : dayOf(lastDay) {
    if (count < 0) throw ArgumentError.value(count, 'count', 'negatif');
  }

  static const activeFrom = 3;
  static const maxGrayMissed = 2;
  static const maxFrozenMissed = 10;
  static final none = Streak(0, null);

  /// Jumlah hari yang sudah dihitung; 0 = belum pernah dibuka.
  final int count;

  /// Hari terakhir yang dihitung; null bila [count] 0.
  final DateTime? lastDay;

  bool get active => count >= activeFrom;

  /// Keadaan streak di hari [today], dengan anggapan [open] hari itu sudah dijalankan.
  StreakStatus status(DateTime today) {
    final last = lastDay;
    if (last == null) return const StreakNone();
    final missed = daysBetween(last, dayOf(today)) - 1;
    if (missed < 0 || !active && missed == 0) {
      return active ? StreakBurning(count) : StreakKindling(count);
    }
    if (!active) return const StreakNone(); // bara yang bolong tidak padam atau beku, langsung mulai lagi
    if (missed == 0) return StreakBurning(count);
    if (missed <= maxGrayMissed) return StreakGray(count, missed);
    if (missed <= maxFrozenMissed) return StreakFrozen(count, missed, clicksToThaw(missed));
    return StreakExpired(count, missed);
  }

  /// Aplikasi dibuka (atau tetap terbuka saat tanggal berganti) di hari [today]. Jam yang mundur ke hari sebelumnya
  /// diperlakukan seperti hari yang sama.
  StreakOpening open(DateTime today) {
    final day = dayOf(today);
    final last = lastDay;
    if (last == null) return StreakOpening(Streak(1, day), const StreakCounted(0, 1));
    final gap = daysBetween(last, day);
    if (gap <= 0) return StreakOpening(this, const StreakSameDay());
    if (gap == 1) return StreakOpening(Streak(count + 1, day), StreakCounted(count, count + 1));
    return switch (status(day)) {
      final StreakGray g => StreakOpening(this, StreakNeedsRevival(g)),
      final StreakFrozen f => StreakOpening(this, StreakNeedsRevival(f)),
      final StreakExpired e => StreakOpening(Streak(1, day), StreakExpiredEvent(e.count, e.missed)),
      _ => StreakOpening(Streak(1, day), const StreakCounted(0, 1)), // bara yang bolong
    };
  }

  /// Streak yang padam atau beku dinyalakan lagi: angka lanjut dan hari ini dihitung. Melempar [StateError] bila
  /// streak tidak sedang padam atau beku.
  Streak revive(DateTime today) {
    final s = status(today);
    if (s is! StreakGray && s is! StreakFrozen) throw StateError('Streak tidak sedang padam atau beku: $s');
    return Streak(count + 1, today);
  }

  @override
  bool operator ==(Object other) => other is Streak && other.count == count && other.lastDay == lastDay;

  @override
  int get hashCode => Object.hash(count, lastDay);

  @override
  String toString() => 'Streak($count, ${lastDay == null ? '-' : isoDay(lastDay!)})';
}

/// Menghitung ketukan beruntun (tiga ketukan cepat untuk api padam): jeda antar ketukan harus di bawah [windowMs].
class TapCounter {
  TapCounter(this.needed);

  static const windowMs = 500;

  final int needed;
  int _taps = 0;
  int? _last;

  /// Ketukan beruntun yang sudah terkumpul (untuk titik progres).
  int get taps => _taps;

  /// True bila ketukan ini menggenapi [needed] ketukan beruntun (hitungan lalu mulai dari nol).
  bool tap(int nowMs) {
    final last = _last;
    _taps = last != null && nowMs - last < windowMs ? _taps + 1 : 1;
    _last = nowMs;
    if (_taps >= needed) {
      reset();
      return true;
    }
    return false;
  }

  void reset() {
    _taps = 0;
    _last = null;
  }
}
