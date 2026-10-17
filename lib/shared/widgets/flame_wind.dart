import 'dart:math' as math;

/// Satu jenjang angin (artifact desktop `LEVELS`).
class WindLevel {
  const WindLevel({required this.amount, required this.base, required this.every, this.rain = 0});

  /// Kekuatan rata-rata hembusan (0 = tanpa hembusan).
  final double amount;

  /// Angin dasar yang terus bertiup di sela hembusan.
  final double base;

  /// Jeda antar hembusan, detik (terpendek, terpanjang).
  final (double, double) every;

  /// Hujan (0..1); hujan deras memunculkan kilat.
  final double rain;
}

/// Hembusan angin untuk api streak, port dari artifact desktop "Streak Api TermUL" (versi `1792273284-2261`, fungsi
/// `gust`, `windTick`, `windAt`). Satu sumber bersama untuk semua api yang bergoyang, supaya hembusan terasa satu.
///
/// Ada lima jenjang ([levels]): tenang, sepoi-sepoi, agak kencang, kencang, dan hujan badai. Aplikasi memakai mode
/// **naik bertahap otomatis** ([autoCycle]; keputusan pemilik 2026-10-18): sepoi-sepoi, agak kencang, dan kencang
/// masing-masing 8 detik, hujan badai 13 detik, tenang 4 detik, lalu berulang. Hembusan datang acak (85% dari kiri),
/// berlangsung 1,3-2,2 detik: kekuatan naik dengan sinus di 22% awal lalu meluruh dengan kosinus kuadrat, ditambah
/// getaran kecil. Mulai jenjang agak kencang ada angin dasar yang berdenyut pelan. Nilai [at] berkisar -1,5..1,5
/// (positif = bertiup ke kanan). [rain] dan [flash] menggerakkan hujan dan kilat (`FlameWeather`).
///
/// Waktu hanya maju saat ada yang membaca angin (api yang terlihat); tiap pembacaan maju paling banyak 0,05 detik,
/// sama dengan langkah bingkai desktop, jadi siklus berhenti selagi tidak ada api di layar.
class WindField {
  WindField({this.auto = true, this._level = 1, math.Random? random, double Function()? clock})
    : _random = random ?? math.Random(),
      _clock = clock ?? _stopwatchClock();

  static const levels = [
    WindLevel(amount: 0, base: 0, every: (9, 9)), // Tenang
    WindLevel(amount: 0.32, base: 0, every: (4.5, 8)), // Sepoi-sepoi
    WindLevel(amount: 0.6, base: 0.08, every: (3, 5.5)), // Agak kencang
    WindLevel(amount: 0.9, base: 0.25, every: (1.8, 3.4)), // Kencang
    WindLevel(amount: 1.1, base: 0.5, every: (0.9, 2), rain: 1), // Hujan badai
  ];

  /// Urutan otomatis: (jenjang, lama detik).
  static const autoCycle = [(1, 8.0), (2, 8.0), (3, 8.0), (4, 13.0), (0, 4.0)];

  /// Naik bertahap mengikuti [autoCycle].
  final bool auto;
  final math.Random _random;
  final double Function() _clock;
  final _gusts = <({double t0, double dur, double s, int dir})>[];

  int _level;
  int _autoIndex = 0;
  double _autoT = 0;
  double _base = 0;
  double _rain = 0;
  double _flash = 0;
  final _flashAt = <double>[];
  double _nextFlash = 0;
  double? _next;
  double? _last;

  static double Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMicroseconds / 1e6;
  }

  /// Detik sejak sumber angin dibuat.
  double get now => _clock();

  /// Jenjang sekarang (indeks [levels]).
  int get level {
    update();
    return _level;
  }

  /// Hujan sekarang (0..1), naik dan turun perlahan.
  double get rain {
    update();
    return _rain;
  }

  /// Kilat sekarang (0..1), meredup dalam sekitar 0,3 detik.
  double get flash {
    update();
    return _flash;
  }

  /// Pindah jenjang; hembusan pertama jenjang baru datang 0,3 detik kemudian.
  void setLevel(int level) {
    _level = level;
    _next = now + 0.3;
  }

  /// Hembusan manual (desktop: "Tiup sekarang").
  void gust({double strength = 1, int? dir}) => _gusts.add((
    t0: now,
    dur: 1.3 + _random.nextDouble() * 0.9,
    s: strength,
    dir: dir ?? (_random.nextDouble() < 0.85 ? 1 : -1),
  ));

  /// Memajukan angin ke waktu sekarang (desktop `windTick`). Dipanggil otomatis oleh [at], [rain], dan [flash].
  void update() {
    final t = now;
    final last = _last;
    _last = t;
    final dt = last == null ? 0.0 : (t - last).clamp(0.0, 0.05);
    if (auto && dt > 0) {
      _autoT += dt;
      if (_autoT >= autoCycle[_autoIndex].$2) {
        _autoT = 0;
        _autoIndex = (_autoIndex + 1) % autoCycle.length;
        setLevel(autoCycle[_autoIndex].$1);
      }
    }
    final l = levels[_level];
    _base += (l.base - _base) * math.min(1, dt * 0.8);
    _rain += (l.rain - _rain) * math.min(1, dt * 0.6);
    _next ??= t + 1.5;
    if (l.amount > 0 && t >= _next!) {
      gust(strength: l.amount * (0.75 + _random.nextDouble() * 0.25));
      _next = t + l.every.$1 + _random.nextDouble() * (l.every.$2 - l.every.$1);
    }
    _gusts.removeWhere((g) => t >= g.t0 + g.dur + 3);
    // Kilat hanya saat hujan sudah deras, kadang berkedip dua kali.
    if (_rain > 0.6 && t >= _nextFlash) {
      _flashAt.add(t);
      if (_random.nextDouble() < 0.6) _flashAt.add(t + 0.14 + _random.nextDouble() * 0.1);
      _nextFlash = t + 3.5 + _random.nextDouble() * 6;
    }
    if (_rain < 0.6) _nextFlash = math.max(_nextFlash, t + 1.5);
    _flashAt.removeWhere((f) {
      if (t < f) return false;
      _flash = 1;
      return true;
    });
    _flash = math.max(0, _flash - dt * 3.2);
  }

  /// Kekuatan angin [delay] detik yang lalu (lapisan dalam api memakai jeda kecil supaya terasa lentur).
  double at({double delay = 0}) {
    update();
    final t = now - delay;
    var w = _base * (1 + 0.35 * math.sin(t * 2.3) + 0.2 * math.sin(t * 7.1));
    for (final g in _gusts) {
      final u = (t - g.t0) / g.dur;
      if (u <= 0 || u >= 1) continue;
      final env = u < 0.22
          ? math.sin(u / 0.22 * math.pi / 2)
          : math.pow(math.cos((u - 0.22) / 0.78 * math.pi / 2), 2).toDouble();
      w += g.dir * g.s * env * (1 + 0.22 * math.sin(t * 19 + g.t0) + 0.1 * math.sin(t * 41));
    }
    return w.clamp(-1.5, 1.5);
  }
}

/// Angin bersama semua api di aplikasi.
final flameWind = WindField();
