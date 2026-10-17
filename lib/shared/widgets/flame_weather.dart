import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'flame.dart';
import 'flame_wind.dart';

/// Hujan badai dan kilat di sekitar api besar (artifact desktop "Streak Api TermUL" versi `1792273284-2261`, fungsi
/// `drawRain` dan `drawFlash`). Saat [WindField.rain] naik, tetes hujan jatuh miring mengikuti angin di seluruh area
/// [child]; tetes yang mengenai api ([flameKey], kecuali api beku) berubah jadi kepulan uap. Kilat menerangi area
/// sekejap. Tanpa hujan widget ini tidak menggambar apa-apa.
///
/// Reduce motion sistem mematikannya, dan `TickerMode` menghentikannya saat layar tidak terlihat. Gambarnya dipotong
/// ke area [child] (sudut [borderRadius]). Kilat digambar di belakang [child] ([flashBehind], untuk latar transparan
/// seperti splash) atau di atasnya (kartu yang berlatar sendiri).
class FlameWeather extends StatefulWidget {
  const FlameWeather({
    super.key,
    required this.flameKey,
    required this.child,
    this.wind,
    this.borderRadius = BorderRadius.zero,
    this.flashBehind = true,
  });

  /// Kunci [Flame] yang terkena hujan.
  final GlobalKey flameKey;
  final Widget child;

  /// Sumber angin; bawaan [flameWind].
  final WindField? wind;
  final BorderRadius borderRadius;
  final bool flashBehind;

  @override
  State<FlameWeather> createState() => _FlameWeatherState();
}

/// Tetes hujan (satuan piksel logis area cuaca).
class _Drop {
  _Drop(this.x, this.y, this.vy, this.length);

  double x;
  double y;
  final double vy;
  final double length;
}

/// Kepulan uap dari tetes yang mengenai api.
class _Steam {
  _Steam(this.x, this.y, this.vx, this.vy, this.r, this.life) : maxLife = life;

  double x;
  double y;
  double vx;
  final double vy;
  final double r;
  double life;
  final double maxLife;
}

class _FlameWeatherState extends State<FlameWeather> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier<int>(0);
  final _drops = <_Drop>[];
  final _steam = <_Steam>[];
  final _random = math.Random();
  Duration _last = Duration.zero;
  double _acc = 0;
  double _wind = 0;
  double _rain = 0;
  double _flash = 0;
  bool _painted = false;

  WindField get _source => widget.wind ?? flameWind;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = !MediaQuery.disableAnimationsOf(context);
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _drops.clear();
      _steam.clear();
      _rain = _flash = 0;
      _frame.value++;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Daerah api yang "panas" dan tinggi apinya, dalam koordinat area cuaca; null bila api tidak ada atau beku.
  ({Rect zone, double size})? _hot(RenderBox self) {
    final ctx = widget.flameKey.currentContext;
    final flame = ctx?.widget;
    if (ctx == null || flame is! Flame || flame.mode == FlameMode.frozen) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final r = MatrixUtils.transformRect(box.getTransformTo(self), Offset.zero & box.size);
    // Kotak Flame 1,3 x 1,25 kali tinggi api; pangkal api 1,15 tinggi dari atas kotak (viewBox -15..110).
    final s = r.height / 1.25;
    if (s <= 1) return null;
    final by = r.top + s * 1.15;
    return (zone: Rect.fromLTRB(r.center.dx - s * 0.26, by - s * 0.85, r.center.dx + s * 0.26, by), size: s);
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final self = context.findRenderObject();
    if (self is! RenderBox || !self.hasSize) return;
    final w = self.size.width, h = self.size.height;
    _rain = _source.rain;
    _flash = _source.flash;
    _wind = _source.at();
    final vx = _wind * 300;

    final hot = _hot(self);
    if (_rain > 0.02) {
      _acc += dt * _rain * w * 1.3;
      while (_acc > 1) {
        _acc--;
        _drops.add(
          _Drop(
            -w * 0.35 + _random.nextDouble() * w * 1.45,
            -12 - _random.nextDouble() * 20,
            620 + _random.nextDouble() * 260,
            8 + _random.nextDouble() * 8,
          ),
        );
      }
    }
    for (var i = _drops.length - 1; i >= 0; i--) {
      final d = _drops[i];
      d
        ..x += vx * dt
        ..y += d.vy * dt;
      if (hot != null && hot.zone.contains(Offset(d.x, d.y))) {
        if (_random.nextDouble() < 0.4) {
          final s = hot.size;
          _steam.add(
            _Steam(
              d.x,
              d.y,
              (_random.nextDouble() - 0.5) * s * 0.3,
              -s * (0.3 + _random.nextDouble() * 0.3),
              math.max(1.5, s * 0.035),
              0.45 + _random.nextDouble() * 0.3,
            ),
          );
        }
        _drops.removeAt(i);
        continue;
      }
      if (d.y > h + 10) _drops.removeAt(i);
    }
    final push = _wind * (hot?.size ?? 20);
    for (var i = _steam.length - 1; i >= 0; i--) {
      final p = _steam[i]..life -= dt;
      if (p.life <= 0) {
        _steam.removeAt(i);
        continue;
      }
      p
        ..vx += push * 1.6 * dt
        ..x += p.vx * dt
        ..y += p.vy * dt;
    }
    // Gambar ulang selama ada yang tampil, plus satu bingkai kosong untuk menghapus sisa terakhir.
    final visible = _drops.isNotEmpty || _steam.isNotEmpty || _flash > 0;
    if (visible || _painted) _frame.value++;
    _painted = visible;
  }

  @override
  Widget build(BuildContext context) {
    final flash = _FlashPainter(this);
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: CustomPaint(
        painter: widget.flashBehind ? flash : null,
        foregroundPainter: _RainPainter(this, flash: widget.flashBehind ? null : flash),
        child: widget.child,
      ),
    );
  }
}

class _FlashPainter extends CustomPainter {
  _FlashPainter(this.state) : super(repaint: state._frame);

  final _FlameWeatherState state;

  @override
  void paint(Canvas canvas, Size size) {
    if (state._flash <= 0) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = Color.fromRGBO(214, 226, 255, state._flash * 0.3));
  }

  @override
  bool shouldRepaint(_FlashPainter old) => old.state != state;
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.state, {this.flash}) : super(repaint: state._frame);

  final _FlameWeatherState state;

  /// Kilat yang digambar di atas [FlameWeather.child].
  final _FlashPainter? flash;

  @override
  void paint(Canvas canvas, Size size) {
    flash?.paint(canvas, size);
    final steam = Paint();
    for (final p in state._steam) {
      final a = p.life / p.maxLife;
      steam.color = Color.fromRGBO(227, 233, 240, a * 0.35);
      canvas.drawCircle(Offset(p.x, p.y), p.r * (1.8 - a), steam);
    }
    if (state._drops.isEmpty) return;
    final vx = state._wind * 300;
    final path = Path();
    for (final d in state._drops) {
      final k = d.length / math.sqrt(vx * vx + d.vy * d.vy);
      path
        ..moveTo(d.x, d.y)
        ..lineTo(d.x - vx * k, d.y - d.vy * k);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = Color.fromRGBO(185, 212, 255, 0.5 * math.min(1, 0.35 + state._rain * 0.65)),
    );
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.state != state || old.flash != flash;
}
