import 'dart:math' as math;

/// Hembusan angin untuk api streak, port dari artifact desktop "Streak Api TermUL" (versi `1792078599-27c9`, fungsi
/// `gust`, `windTick`, `windAt`). Satu sumber bersama untuk semua api yang bergoyang, supaya hembusan terasa satu.
///
/// Hembusan datang acak (80% dari kiri), berlangsung 1,3-2,2 detik: kekuatan naik dengan sinus di 22% awal lalu
/// meluruh dengan kosinus kuadrat, ditambah getaran kecil. Nilai yang dikembalikan [at] berkisar -1,2..1,2 (positif =
/// bertiup ke kanan). Aplikasi memakai kekuatan tetap "sepoi" (0,6; keputusan pemilik 2026-10-18).
class WindField {
  WindField({this.amount = sepoi, math.Random? random, double Function()? clock})
    : _random = random ?? math.Random(),
      _clock = clock ?? _stopwatchClock();

  /// Kekuatan "Sepoi" di demo desktop.
  static const sepoi = 0.6;

  /// Kekuatan rata-rata hembusan otomatis (0 = mati).
  final double amount;
  final math.Random _random;
  final double Function() _clock;
  final _gusts = <({double t0, double dur, double s, int dir})>[];
  double? _next;

  static double Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMicroseconds / 1e6;
  }

  /// Detik sejak sumber angin dibuat.
  double get now => _clock();

  /// Hembusan manual (desktop: "Tiup sekarang").
  void gust({double strength = 1, int? dir}) => _gusts.add((
    t0: now,
    dur: 1.3 + _random.nextDouble() * 0.9,
    s: strength,
    dir: dir ?? (_random.nextDouble() < 0.8 ? 1 : -1),
  ));

  void _tick(double t) {
    _next ??= t + 2.2;
    if (amount > 0 && t >= _next!) {
      gust(strength: amount * (0.75 + _random.nextDouble() * 0.25));
      _next = t + (amount > 0.8 ? 2.5 + _random.nextDouble() * 2.5 : 4.5 + _random.nextDouble() * 4);
    }
    _gusts.removeWhere((g) => t >= g.t0 + g.dur + 3);
  }

  /// Kekuatan angin [delay] detik yang lalu (lapisan dalam api memakai jeda kecil supaya terasa lentur).
  double at({double delay = 0}) {
    final current = now;
    _tick(current);
    final t = current - delay;
    var w = 0.0;
    for (final g in _gusts) {
      final u = (t - g.t0) / g.dur;
      if (u <= 0 || u >= 1) continue;
      final env = u < 0.22
          ? math.sin(u / 0.22 * math.pi / 2)
          : math.pow(math.cos((u - 0.22) / 0.78 * math.pi / 2), 2).toDouble();
      w += g.dir * g.s * env * (1 + 0.22 * math.sin(t * 19 + g.t0) + 0.1 * math.sin(t * 41));
    }
    return w.clamp(-1.2, 1.2);
  }
}

/// Angin bersama semua api di aplikasi.
final flameWind = WindField();
