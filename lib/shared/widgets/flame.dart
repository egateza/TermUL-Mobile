import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/streak/streak_tier.dart';
import '../../core/theme/termul_theme.dart';
import 'flame_wind.dart';

/// Bentuk api: menyala menurut tier, padam (abu-abu dengan asap), beku (di dalam balok es), atau hangus.
enum FlameMode { active, gray, frozen, reset }

/// Api streak tiga lapis (komponen `Flame` di design system; bentuk sama dengan `FlameArt` di prototipe dan
/// `FlamePainter` desktop). [size] adalah tinggi api; kotaknya 1,3 x 1,25 kali [size].
///
/// [animate] menggoyang api tanpa henti (motion.md). Pakai hanya di layar yang terlihat (splash, layar Streak),
/// bukan di daftar atau chip. Reduce motion sistem mematikannya, dan `TickerMode` menghentikannya saat tab tidak
/// terlihat. Selalu sertakan kata atau angka di dekat api; dengan [semanticLabel] null api disembunyikan dari pembaca
/// layar (dekoratif).
///
/// Api yang bergoyang juga tertiup angin ([flameWind]; artifact desktop "Streak Api TermUL" versi `1792273284-2261`):
/// ujung dan lengkung api miring searah hembusan, lapisan dalam tertinggal sedikit, percikan dan asap terdorong, dan
/// api setinggi 40 ke atas memperlihatkan garis hembusan. Saat hujan badai api mengecil sedikit (8%) dan bergoyang
/// lebih kuat; hujan dan kilatnya digambar `FlameWeather`. Api beku tidak tertiup.
class Flame extends StatefulWidget {
  const Flame({
    super.key,
    required this.count,
    this.mode = FlameMode.active,
    this.size = 48,
    this.cracks = 0,
    this.need = 5,
    this.animate = false,
    this.glow = true,
    this.semanticLabel,
    this.wind,
  });

  /// Hari streak; menentukan tier untuk [FlameMode.active].
  final int count;
  final FlameMode mode;
  final double size;

  /// Retakan es ([FlameMode.frozen]) dari [need] ketukan.
  final int cracks;
  final int need;
  final bool animate;

  /// Cahaya di sekitar api menyala.
  final bool glow;
  final String? semanticLabel;

  /// Sumber angin; bawaan [flameWind] (tes menyuntikkan yang terkendali).
  final WindField? wind;

  @override
  State<Flame> createState() => _FlameState();
}

class _FlameState extends State<Flame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _time = ValueNotifier<double>(0);
  final _gusts = <GustLine>[];
  final _random = math.Random();
  double _gustAcc = 0;

  WindField get _wind => widget.wind ?? flameWind;

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    _updateGusts((t - _time.value).clamp(0.0, 0.05));
    _time.value = t;
  }

  /// Garis hembusan (hanya api besar), dalam satuan viewBox: muncul di sisi datangnya angin lalu melesat melewati api.
  void _updateGusts(double dt) {
    for (final g in _gusts) {
      g.life -= dt;
      g.x += g.vx * dt;
    }
    _gusts.removeWhere((g) => g.life <= 0);
    final w = _wind.at();
    if (widget.size < 40 || w.abs() <= 0.2) return;
    final dir = w > 0 ? 1 : -1;
    _gustAcc += dt * w.abs() * 7;
    while (_gustAcc > 1) {
      _gustAcc--;
      _gusts.add(
        GustLine(
          x: -dir * 100 * (0.7 + _random.nextDouble() * 0.5),
          y: 100 - 100 * (0.1 + _random.nextDouble()),
          vx: dir * 100 * (3.2 + _random.nextDouble() * 1.6),
          dir: dir,
          length: 100 * (0.3 + _random.nextDouble() * 0.35),
          life: 0.4 + _random.nextDouble() * 0.25,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Flame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _time.value = 0;
      _gusts.clear();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animated = _ticker.isActive;
    final paint = SizedBox(
      width: widget.size * 1.3,
      height: widget.size * 1.25,
      child: CustomPaint(
        painter: FlamePainter(
          count: widget.count,
          mode: widget.mode,
          cracks: widget.cracks,
          need: widget.need,
          glow: widget.glow,
          time: animated ? _time : null,
          wind: animated ? _wind : null,
          gusts: _gusts,
        ),
      ),
    );
    final label = widget.semanticLabel;
    return label == null ? ExcludeSemantics(child: paint) : Semantics(label: label, image: true, child: paint);
  }
}

/// Garis hembusan angin yang sedang melintas (satuan viewBox api).
class GustLine {
  GustLine({
    required this.x,
    required this.y,
    required this.vx,
    required this.dir,
    required this.length,
    required this.life,
  }) : maxLife = life;

  double x;
  final double y;
  final double vx;
  final int dir;
  final double length;
  double life;
  final double maxLife;
}

/// Satu bentuk yang digambar, dengan gerak opsionalnya.
class _Item {
  _Item(
    this.path,
    this.color, {
    this.motion,
    this.opacity = 1,
    this.centerOrigin = false,
    this.swayGain = 1,
    this.push = 0,
  });

  final Path path;
  final Color color;
  final _Motion? motion;
  final double opacity;

  /// Titik tumpu gerak di tengah bentuk (percikan, bintang, asap); selain itu di tengah bawah (lapis api).
  final bool centerOrigin;

  /// Pengali goyangan (api bergoyang lebih kuat saat tertiup angin).
  final double swayGain;

  /// Seberapa jauh angin penuh mendorong partikel ini sepanjang hidupnya (percikan, asap), dalam satuan viewBox.
  final double push;
}

typedef _Frame = ({double skew, double scaleX, double scaleY, double dy, double opacity, double p});

/// Gerak berulang dengan keyframe CSS dari `FlameArt` (durasi dan jeda dalam detik; jeda negatif = mulai di tengah).
class _Motion {
  const _Motion(this.keys, this.duration, this.delay, {this.easeOut = false});

  final List<(double, _Frame)> keys;
  final double duration;
  final double delay;

  /// `ease-out` untuk percikan dan asap; selain itu `ease-in-out` per segmen.
  final bool easeOut;

  _Frame at(double t) {
    final since = t - delay;
    if (since < 0) return keys.first.$2; // belum mulai: keadaan dasar
    final p = (since / duration) % 1.0;
    for (var i = 0; i < keys.length - 1; i++) {
      final (a, fa) = keys[i];
      final (b, fb) = keys[i + 1];
      if (p <= b) {
        final local = (p - a) / (b - a);
        final e = (easeOut ? Curves.easeOut : Curves.easeInOut).transform(local.clamp(0.0, 1.0));
        double lerp(double x, double y) => x + (y - x) * e;
        return (
          skew: lerp(fa.skew, fb.skew),
          scaleX: lerp(fa.scaleX, fb.scaleX),
          scaleY: lerp(fa.scaleY, fb.scaleY),
          dy: lerp(fa.dy, fb.dy),
          opacity: lerp(fa.opacity, fb.opacity),
          p: p,
        );
      }
    }
    return keys.last.$2;
  }
}

_Frame _f({double skew = 0, double sx = 1, double sy = 1, double dy = 0, double op = 1}) =>
    (skew: skew, scaleX: sx, scaleY: sy, dy: dy, opacity: op, p: 0);

_Frame _sway(double skew, double sy) => _f(skew: skew, sy: sy);

// Keyframe `fa-l1`, `fa-l2`, `fa-l3`, `fa-tl`, `fa-tr`, `fa-spark`, `fa-twinkle`, `fa-smoke`.
final _l1 = [(0.0, _sway(0, 1)), (0.30, _sway(-3.5, 1.035)), (0.65, _sway(3, 0.97)), (1.0, _sway(0, 1))];
final _l2 = [(0.0, _sway(0, 1)), (0.35, _sway(4, 0.965)), (0.70, _sway(-3, 1.04)), (1.0, _sway(0, 1))];
final _l3 = [(0.0, _sway(0, 1)), (0.40, _sway(-4, 1.05)), (0.75, _sway(3.5, 0.95)), (1.0, _sway(0, 1))];
final _tl = [(0.0, _sway(0, 1)), (0.5, _sway(-6, 1.07)), (1.0, _sway(0, 1))];
final _tr = [(0.0, _sway(0, 1)), (0.5, _sway(6, 1.07)), (1.0, _sway(0, 1))];
final _spark = [(0.0, _f(op: 0.95)), (1.0, _f(dy: -30, sx: 0.4, sy: 0.4, op: 0))];
final _twinkle = [(0.0, _f(sx: 0.25, sy: 0.25, op: 0.5)), (0.5, _f()), (1.0, _f(sx: 0.25, sy: 0.25, op: 0.5))];
final _smoke = [(0.0, _f(sx: 0.8, sy: 0.8, op: 0.4)), (1.0, _f(dy: -28, sx: 1.7, sy: 1.7, op: 0))];

const _gray = (outer: TermulPalette.flameGrayOuter, mid: TermulPalette.flameGrayMid, core: TermulPalette.flameGrayCore);
const _ice = (outer: TermulPalette.flameIceOuter, mid: TermulPalette.flameIceMid, core: TermulPalette.flameIceCore);

/// Asap api padam (`#9a9ea4` di `FlameArt`).
const _smokeColor = Color(0xFF9A9EA4);

/// Menggambar api di kotak viewBox `-65 -15 130 125` (sama dengan `FlameArt`), diskalakan ke ukuran kanvas.
class FlamePainter extends CustomPainter {
  FlamePainter({
    required this.count,
    required this.mode,
    this.cracks = 0,
    this.need = 5,
    this.glow = true,
    this.time,
    this.wind,
    this.gusts = const [],
  }) : super(repaint: time);

  final int count;
  final FlameMode mode;
  final int cracks;
  final int need;
  final bool glow;

  /// Detik sejak gerak dimulai; null = diam.
  final ValueListenable<double>? time;

  /// Sumber angin; null = tanpa angin.
  final WindField? wind;

  /// Garis hembusan yang sedang melintas.
  final List<GustLine> gusts;

  /// Lapis api. [lean] (kira-kira -1..1, dari angin) menggeser ujung dan titik kontrol searah hembusan; pangkalnya
  /// tetap (desktop `flamePath`).
  static Path _flame(double cx, double by, double h, double sway, {double lean = 0}) {
    final w = h * 0.62, r = w / 2, top0 = by - h * 0.97, cy = top0 + h * 0.66;
    final top = top0 + lean.abs() * h * 0.12, tx = cx + sway + lean * h * 0.6;
    final sh = lean * h * 0.22, sm = lean * h * 0.06;
    return Path()
      ..moveTo(tx, top)
      ..cubicTo(tx + r * 0.35 + sm, top + h * 0.22, cx + r * 1.08 + sh, cy - h * 0.22, cx + r, cy)
      ..arcToPoint(Offset(cx - r, cy), radius: Radius.circular(r))
      ..cubicTo(cx - r * 1.08 + sh, cy - h * 0.22, tx - r * 0.35 + sm, top + h * 0.22, tx, top)
      ..close();
  }

  static Path _ellipse(double cx, double cy, double rx, double ry) =>
      Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));

  static Path _star(double x, double y, double s) => Path()
    ..moveTo(x, y - s)
    ..quadraticBezierTo(x, y, x + s, y)
    ..quadraticBezierTo(x, y, x, y + s)
    ..quadraticBezierTo(x, y, x - s, y)
    ..quadraticBezierTo(x, y, x, y - s)
    ..close();

  static const _iceRect = Rect.fromLTWH(-49, -3, 98, 106);
  static final _iceBlock = RRect.fromRectAndRadius(_iceRect, const Radius.circular(18));

  /// Sepuluh retakan es dengan pola acak tetap (seed 42), sama dengan desktop; urutan tampil berselang-seling.
  static final List<Path> _crackPaths = () {
    var seed = 42;
    double rnd() {
      seed = (seed * 16807) % 2147483647;
      return (seed - 1) / 2147483646;
    }

    final raw = <List<Offset>>[];
    for (var i = 0; i < 10; i++) {
      var a = (i / 10) * math.pi * 2 + (rnd() - 0.5) * 0.5;
      var x = 0.52, y = 0.46;
      final pts = [Offset(x, y)];
      final n = 3 + (rnd() * 2).floor();
      for (var j = 0; j < n; j++) {
        a += (rnd() - 0.5) * 0.8;
        final l = 0.08 + rnd() * 0.11;
        x += math.cos(a) * l;
        y += math.sin(a) * l;
        pts.add(Offset(x, y));
      }
      raw.add(pts);
    }
    return [
      for (final i in const [0, 3, 6, 9, 2, 5, 8, 1, 4, 7])
        Path()..addPolygon([for (final p in raw[i]) Offset(-49 + p.dx * 98, -3 + p.dy * 106)], false),
    ];
  }();

  static double _noLean(double k) => 0;

  /// Tiga lapis api dan lidahnya. [lean] memberi kemiringan angin untuk lapis ke-k (lapisan dalam memakai angin sedikit
  /// lebih lama, 0,07 detik per lapis, supaya terasa lentur); [gain] menguatkan goyangan saat tertiup.
  List<_Item> _layers(
    double cx,
    double by,
    double s,
    ({Color outer, Color mid, Color core}) pal,
    int tongues, {
    double Function(double k) lean = _noLean,
    double gain = 1,
  }) => [
    if (tongues >= 1)
      _Item(
        _flame(cx - s * 0.2, by - s * 0.06, s * 0.5, -s * 0.5 * 0.14, lean: lean(0.6) * 1.15),
        pal.outer,
        motion: _Motion(_tl, 0.9, -0.3),
        swayGain: gain,
      ),
    if (tongues >= 2)
      _Item(
        _flame(cx + s * 0.2, by - s * 0.07, s * 0.42, s * 0.42 * 0.14, lean: lean(0.4) * 1.15),
        pal.outer,
        motion: _Motion(_tr, 0.75, -0.5),
        swayGain: gain,
      ),
    _Item(
      _flame(cx, by, s, 0, lean: lean(0)),
      pal.outer,
      motion: _Motion(_l1, 1.1, 0),
      swayGain: gain,
    ),
    _Item(
      _flame(cx, by - s * 0.02, s * 0.7, 0, lean: lean(1)),
      pal.mid,
      motion: _Motion(_l2, 0.85, -0.2),
      swayGain: gain,
    ),
    _Item(
      _flame(cx, by - s * 0.05, s * 0.4, 0, lean: lean(2) * 0.9),
      pal.core,
      motion: _Motion(_l3, 0.65, -0.4),
      swayGain: gain,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = time?.value;
    final animate = t != null;
    final k = size.height / 125;
    canvas
      ..save()
      ..scale(k)
      ..translate(65, 15);

    final tier = StreakTier.of(count);
    final items = <_Item>[];
    final fx = <_Item>[];
    Color? glowColor;

    // Angin: beku tidak tertiup, padam 0,8, bara 0,7 (desktop `windAmt`).
    final windAmt = switch (mode) {
      FlameMode.frozen => 0.0,
      FlameMode.gray || FlameMode.reset => 0.8,
      FlameMode.active when tier == StreakTier.bara => 0.7,
      FlameMode.active => 1.0,
    };
    final source = animate ? wind : null;
    double lean(double k) =>
        source == null || windAmt == 0 ? 0 : (source.at(delay: k * 0.07) * windAmt * 0.72).clamp(-1.0, 1.0);
    final rain = source == null ? 0.0 : source.rain;
    final gain = 1 + lean(0).abs() * 1.2 + rain * 0.5 * windAmt;
    // Dorongan percikan dan asap memakai angin saat ini.
    final push = source == null ? 0.0 : source.at();
    // Hujan badai mengecilkan api (bukan es) dengan pangkal tetap.
    if (rain > 0 && mode != FlameMode.frozen) {
      final shrink = 1 - rain * 0.08;
      canvas
        ..translate(0, 100)
        ..scale(shrink)
        ..translate(0, -100);
    }

    switch (mode) {
      case FlameMode.frozen:
        items.addAll(_layers(0, 92, 78, _ice, 0));
        for (var i = 0; i < 3; i++) {
          final sx = _iceRect.left + _iceRect.width * (0.3 + i * 0.25);
          final sy = _iceRect.top + _iceRect.height * (0.22 + ((i * 37) % 5) * 0.12);
          fx.add(
            _Item(
              _star(sx, sy, 3.5),
              const Color(0xF2FFFFFF),
              motion: _Motion(_twinkle, 1.8, i * 0.6),
              centerOrigin: true,
            ),
          );
        }
      case FlameMode.gray || FlameMode.reset:
        items.addAll(_layers(0, 100, 100, _gray, 0, lean: lean, gain: gain));
        for (var i = 0; i < 3; i++) {
          fx.add(
            _Item(
              _ellipse(-6.0 + i * 6, 4.0 - i * 4, 4.0 + i, 4.0 + i),
              _smokeColor,
              motion: _Motion(_smoke, 2, i * 0.7, easeOut: true),
              opacity: animate ? 0.4 : 0.3,
              centerOrigin: true,
              push: 50,
            ),
          );
        }
      case FlameMode.active when tier == StreakTier.bara:
        glowColor = tier.glow;
        items
          ..add(_Item(_ellipse(0, 95, 30, 8), TermulPalette.coal))
          ..addAll(_layers(0, 92, 70, (outer: tier.outer, mid: tier.mid, core: tier.core), 0, lean: lean, gain: gain));
      case FlameMode.active:
        glowColor = tier.glow;
        items.addAll(
          _layers(
            0,
            100,
            100,
            (outer: tier.outer, mid: tier.mid, core: tier.core),
            tier.tongues,
            lean: lean,
            gain: gain,
          ),
        );
        const sx = <double>[-12, 10, -4, 14, 0];
        const sy = <double>[48, 40, 34, 52, 30];
        for (var i = 0; i < tier.sparks; i++) {
          fx.add(
            _Item(
              _ellipse(sx[i], sy[i], 1.6, 1.6),
              i.isEven ? tier.core : tier.mid,
              motion: _Motion(_spark, 0.9 + i * 0.12, i * 0.3, easeOut: true),
              opacity: animate ? 1 : 0.85,
              centerOrigin: true,
              push: 80,
            ),
          );
        }
        if (tier.stars) {
          for (var i = 0; i < 3; i++) {
            final a = i * 2.1 + 0.6;
            fx.add(
              _Item(
                _star(math.cos(a) * 52, 45 + math.sin(a) * 40, 7),
                tier.core,
                motion: _Motion(_twinkle, 2.2, i * 0.7),
                centerOrigin: true,
              ),
            );
          }
        }
    }

    // Api pelangi memutar warnanya (6 detik per putaran) selama beranimasi.
    final hue = mode == FlameMode.active && tier.rainbow && animate ? (t / 6 * 360) % 360 : 0.0;
    Color tint(Color c) =>
        hue == 0 ? c : HSVColor.fromColor(c).withHue((HSVColor.fromColor(c).hue + hue) % 360).toColor();

    if (glow && glowColor != null) {
      // drop-shadow(0 0 size*0.17) di FlameArt: simpangan baku setengahnya, dalam satuan viewBox.
      const sigma = 8.5;
      canvas.saveLayer(null, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
      final paint = Paint()..color = tint(glowColor);
      for (final item in items) {
        _draw(canvas, item, t, paint);
      }
      canvas.restore();
    }

    for (final item in items) {
      _draw(canvas, item, t, Paint()..color = tint(item.color).withValues(alpha: item.opacity));
    }

    if (mode == FlameMode.frozen) {
      canvas
        ..drawRRect(
          _iceBlock,
          Paint()
            ..shader = ui.Gradient.linear(_iceRect.topLeft, _iceRect.bottomRight, const [
              TermulPalette.iceBlockTop,
              TermulPalette.iceBlockBottom,
            ]),
        )
        ..drawRRect(
          _iceBlock,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xF2ECFAFF),
        );
      final shine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xE6FFFFFF);
      final x = _iceRect.left + _iceRect.width * 0.2;
      canvas
        ..drawLine(
          Offset(x, _iceRect.top + _iceRect.height * 0.15),
          Offset(x, _iceRect.top + _iceRect.height * 0.36),
          shine..strokeWidth = 4.5,
        )
        ..drawLine(
          Offset(x, _iceRect.top + _iceRect.height * 0.45),
          Offset(x, _iceRect.top + _iceRect.height * 0.5),
          shine..strokeWidth = 4,
        );
      final shown = need <= 0 ? 0 : ((cracks / need) * 10).round().clamp(0, 10);
      if (shown > 0) {
        canvas
          ..save()
          ..clipRRect(_iceBlock);
        final crack = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xF2FFFFFF);
        for (var i = 0; i < shown; i++) {
          canvas.drawPath(_crackPaths[i], crack);
        }
        canvas.restore();
      }
    }

    for (final item in fx) {
      _draw(canvas, item, t, Paint()..color = tint(item.color).withValues(alpha: item.opacity), wind: push);
    }

    // Garis hembusan: lengkung tipis putih yang muncul lalu memudar (desktop `gust`).
    if (animate && gusts.isNotEmpty) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.4;
      for (final g in gusts) {
        final a = g.life / g.maxLife;
        final f = math.min(1.0, math.min(a * 3, (1 - a) * 5));
        if (f <= 0) continue;
        line.color = const Color(0xFFFFFFFF).withValues(alpha: f * 0.45);
        canvas.drawPath(
          Path()
            ..moveTo(g.x - g.dir * g.length, g.y + g.length * 0.07)
            ..quadraticBezierTo(g.x - g.dir * g.length * 0.45, g.y - g.length * 0.1, g.x, g.y),
          line,
        );
      }
    }
    canvas.restore();
  }

  void _draw(Canvas canvas, _Item item, double? t, Paint paint, {double wind = 0}) {
    final motion = item.motion;
    if (t == null || motion == null) {
      canvas.drawPath(item.path, paint);
      return;
    }
    final f = motion.at(t);
    final b = item.path.getBounds();
    final origin = item.centerOrigin ? b.center : b.bottomCenter;
    // Partikel terdorong angin makin jauh sepanjang hidupnya (percepatan tetap, jadi kuadrat).
    final dx = item.push * wind * f.p * f.p;
    // Opasitas gerak menggantikan opasitas dasar (seperti properti CSS yang dianimasikan).
    paint.color = paint.color.withValues(alpha: f.opacity.clamp(0.0, 1.0));
    canvas
      ..save()
      ..translate(origin.dx + dx, origin.dy + f.dy)
      ..transform(
        (Matrix4.skewX(f.skew * item.swayGain * math.pi / 180)..scaleByDouble(f.scaleX, f.scaleY, 1, 1)).storage,
      )
      ..translate(-origin.dx, -origin.dy)
      ..drawPath(item.path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(FlamePainter old) =>
      old.count != count ||
      old.mode != mode ||
      old.cracks != cracks ||
      old.need != need ||
      old.glow != glow ||
      old.time != time ||
      old.wind != wind;
}
