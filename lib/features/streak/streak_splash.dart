import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/streak/streak.dart';
import '../../core/streak/streak_tier.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/flame.dart';
import '../../shared/widgets/flame_weather.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_button.dart';
import 'streak_controller.dart';
import 'streak_text.dart';

/// Membuka splash streak untuk [event] (prototipe 9a-9f) di atas layar sekarang.
Future<void> showStreakSplash(BuildContext context, StreakEvent event) => Navigator.of(context).push<void>(
  PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'streak-splash'),
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => StreakSplash(event: event),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);

// Nilai dari prototipe `StreakSplash` (belum ada token khusus splash).
const _bgCenter = Color(0xFF28160A);
const _bgEdge = Color(0xFF060709);
const _white65 = Color(0xA6FFFFFF);
const _white86 = Color(0xDBFFFFFF);
const _white35 = Color(0x59FFFFFF);
const _grayText = Color(0xFFB4B8BD);
const _iceText = Color(0xFFBFE6FF);
const _rainbowText = Color(0xFFFFD36B);
const _onBadge = Color(0xFF14100C);
const _shardColor = Color(0xEBCEEDFF);

/// Kurva "api masuk" dan "pop" di motion.md: cubic-bezier(0.3, 1.7, 0.5, 1).
const _overshoot = Cubic(0.3, 1.7, 0.5, 1);

enum _Kind { active, ember, gray, frozen, reset }

enum _Fx { puff, chips, shatter, burst }

/// Splash saat aplikasi dibuka atau tanggal berganti (motion.md "Splash saat aplikasi dibuka"): bertambah, naik
/// level, bara, padam, beku, dan hangus. Padam dan beku bisa diketuk di sini (aturan sama dengan tab Streak) dan
/// punya tombol "Nanti saja". Gerak tidak menahan input; reduce motion menampilkan keadaan akhir langsung.
class StreakSplash extends ConsumerStatefulWidget {
  const StreakSplash({super.key, required this.event});

  final StreakEvent event;

  @override
  ConsumerState<StreakSplash> createState() => _StreakSplashState();
}

class _StreakSplashState extends ConsumerState<StreakSplash> with TickerProviderStateMixin {
  /// Garis waktu splash dalam detik (hangus paling panjang: mulai lagi pada 3,2 detik).
  static const _length = 4.0;

  late final _timeline = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));
  late final _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  /// Api baru dinyalakan di splash (0..1 selama 0,75 detik): angka bergulir dan lencana muncul.
  late final _relit = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

  _Fx? _fxKind;

  /// Api yang terkena hujan badai (`FlameWeather`).
  final _flameKey = GlobalKey();
  bool _shakeLeft = true;

  late final _Kind _kind = switch (widget.event) {
    StreakCounted(:final to) when to < Streak.activeFrom => _Kind.ember,
    StreakCounted() => _Kind.active,
    StreakNeedsRevival(status: StreakFrozen()) => _Kind.frozen,
    StreakNeedsRevival() => _Kind.gray,
    StreakExpiredEvent() => _Kind.reset,
    StreakSameDay() => _Kind.active,
  };

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _timeline.dispose();
    _fx.dispose();
    _shake.dispose();
    _relit.dispose();
    super.dispose();
  }

  void _play() {
    if (!mounted) return;
    if (_reduceMotion) {
      _timeline.value = 1;
    } else {
      _timeline.forward(from: 0);
    }
  }

  void _tap() {
    final effect = ref.read(streakControllerProvider.notifier).tap();
    final fx = switch (effect) {
      StreakTapEffect.tap => _Fx.puff,
      StreakTapEffect.crack => _Fx.chips,
      StreakTapEffect.shatter => _Fx.shatter,
      StreakTapEffect.revive => _Fx.burst,
      StreakTapEffect.poke => null,
    };
    if (fx == null) return;
    if (effect == StreakTapEffect.revive || effect == StreakTapEffect.shatter) {
      if (_reduceMotion) {
        _relit.value = 1;
      } else {
        _relit.forward(from: 0);
      }
    }
    if (_reduceMotion) return;
    setState(() {
      _fxKind = fx;
      _shakeLeft = !_shakeLeft;
    });
    _fx.forward(from: 0);
    _shake.forward(from: 0);
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(streakControllerProvider);
    final waiting = (_kind == _Kind.gray || _kind == _Kind.frozen) && view.waiting;
    final revived = (_kind == _Kind.gray || _kind == _Kind.frozen) && !view.waiting;
    return Scaffold(
      backgroundColor: _bgEdge,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [_bgCenter, _bgEdge],
            stops: [0, 0.85],
          ),
        ),
        child: FlameWeather(
          flameKey: _flameKey,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space5, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.streakSplashHeader.toUpperCase(),
                          style: streakMono(12, medium: false).copyWith(color: _white65, letterSpacing: 0.96),
                        ),
                      ),
                      Pressable(
                        onPressed: _play,
                        semanticLabel: l.streakSplashReplay,
                        builder: (context, pressed) => Container(
                          constraints: const BoxConstraints(minHeight: TermulSize.tapMin),
                          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space5),
                          alignment: Alignment.center,
                          child: Text(
                            l.streakSplashReplay,
                            style: TermulText.caption.copyWith(
                              color: _white65,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: _white65,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space9,
                      0,
                      TermulSpacing.space9,
                      TermulSpacing.space9 + 4,
                    ),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_timeline, _fx, _shake, _relit]),
                      builder: (context, _) => Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: TermulSpacing.space3,
                                  children: [
                                    _stage(l, view, waiting: waiting, revived: revived),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(minHeight: 210),
                                      child: _blocks(l, view, waiting: waiting, revived: revived),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (waiting)
                            Pressable(
                              key: const ValueKey('streak-splash-later'),
                              onPressed: _close,
                              semanticLabel: l.streakSplashLater,
                              builder: (context, pressed) => Container(
                                constraints: const BoxConstraints(minHeight: TermulSize.buttonLg),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
                                  border: Border.all(color: _white35),
                                  color: pressed ? const Color(0x14FFFFFF) : Colors.transparent,
                                ),
                                child: Text(
                                  l.streakSplashLater,
                                  style: TermulText.body.copyWith(color: Colors.white, fontSize: 16),
                                ),
                              ),
                            )
                          else
                            TermulButton(
                              key: const ValueKey('streak-splash-continue'),
                              label: l.streakSplashContinue,
                              variant: TermulButtonVariant.primary,
                              size: TermulButtonSize.lg,
                              onPressed: _close,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double get _t => _timeline.value * _length;

  double _phase(double start, double length) => ((_t - start) / length).clamp(0.0, 1.0);

  /// Warna angka dan lencana (`--tc` di prototipe).
  Color _textColor(StreakView view, {required bool waiting, required bool revived}) {
    Color tierText(int count) {
      final tier = StreakTier.of(count);
      return tier.rainbow ? _rainbowText : tier.mid;
    }

    return switch (_kind) {
      _Kind.gray when waiting => _grayText,
      _Kind.frozen when waiting => _iceText,
      _Kind.reset => _grayText,
      _Kind.ember => StreakTier.bara.mid,
      _ when revived => tierText(view.count),
      _ => tierText(_to),
    };
  }

  int get _to => switch (widget.event) {
    StreakCounted(:final to) => to,
    _ => 0,
  };

  int get _from => switch (widget.event) {
    StreakCounted(:final from) => from,
    _ => 0,
  };

  Widget _stage(AppLocalizations l, StreakView view, {required bool waiting, required bool revived}) {
    final entry = _overshoot.transform(_phase(0, 0.7));
    final flames = <Widget>[];
    Widget place(Widget flame, {double scale = 1, double opacity = 1, double dy = 0, double gray = 0}) {
      Widget child = Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(scale: math.max(0, scale), alignment: Alignment.bottomCenter, child: flame),
      );
      if (gray > 0) {
        final s = 1 - gray; // saturasi
        child = ColorFiltered(
          colorFilter: ColorFilter.matrix([
            0.2126 + 0.7874 * s, 0.7152 - 0.7152 * s, 0.0722 - 0.0722 * s, 0, 0, //
            0.2126 - 0.2126 * s, 0.7152 + 0.2848 * s, 0.0722 - 0.0722 * s, 0, 0, //
            0.2126 - 0.2126 * s, 0.7152 - 0.7152 * s, 0.0722 + 0.9278 * s, 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      }
      return Positioned(
        left: 35,
        bottom: 6,
        child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      );
    }

    switch (_kind) {
      case _Kind.active:
        final changed = StreakTier.of(_from) != StreakTier.of(_to);
        if (changed) {
          final swap = _phase(1, 0.3);
          flames
            ..add(
              place(
                Flame(count: _from, size: 130, animate: true),
                scale: entry,
                opacity: 1 - swap,
              ),
            )
            ..add(
              place(
                Flame(key: _flameKey, count: _to, size: 130, animate: true),
                opacity: swap,
              ),
            );
        } else {
          flames.add(
            place(
              Flame(key: _flameKey, count: _to, size: 130, animate: true),
              scale: entry,
            ),
          );
        }
      case _Kind.ember:
        flames.add(
          place(
            Flame(key: _flameKey, count: _to, size: 130, animate: true),
            scale: entry,
          ),
        );
      case _Kind.gray || _Kind.frozen:
        flames.add(
          place(
            Flame(
              key: _flameKey,
              count: view.count,
              mode: waiting ? (_kind == _Kind.frozen ? FlameMode.frozen : FlameMode.gray) : FlameMode.active,
              size: 130,
              cracks: view.cracks,
              need: view.need == 0 ? 5 : view.need,
              animate: true,
            ),
            scale: revived ? 1 : entry,
          ),
        );
      case _Kind.reset:
        final lost = (widget.event as StreakExpiredEvent).lost;
        final dying = Curves.easeIn.transform(_phase(1, 1.6));
        flames.add(
          place(
            Flame(key: _t < 3.2 ? _flameKey : null, count: lost, size: 130, animate: true),
            scale: entry * (1 - 0.92 * dying),
            dy: 18 * dying,
            opacity: 1 - dying,
            gray: math.min(1, dying / 0.55),
          ),
        );
        final again = _overshoot.transform(_phase(3.2, 0.5));
        if (_t >= 3.2) flames.add(place(Flame(key: _flameKey, count: 1, size: 130, animate: true), scale: again));
    }

    final s = _shake.value;
    final shake = s == 0 || s == 1
        ? 0.0
        : s < 0.2
        ? -7 * (s / 0.2)
        : s < 0.45
        ? -7 + 13 * ((s - 0.2) / 0.25)
        : s < 0.7
        ? 6 - 10 * ((s - 0.45) / 0.25)
        : -4 * (1 - (s - 0.7) / 0.3);
    final stageLabel = switch (_kind) {
      _Kind.gray when waiting => l.streakSplashStageGray,
      _Kind.frozen when waiting => l.streakSplashStageFrozen,
      _ => l.streakStageActive,
    };
    final palette = switch (_kind) {
      _Kind.reset => StreakTier.bara,
      _Kind.gray || _Kind.frozen => StreakTier.of(view.count),
      _ => StreakTier.of(_to),
    };
    return SizedBox(
      width: 240,
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ParticlePainter(
                  kind: _kind,
                  palette: palette,
                  t: _timeline.isAnimating || _timeline.value < 1 ? _t : null,
                  fx: _fxKind,
                  fxT: _fx.isAnimating ? _fx.value : null,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(_shakeLeft ? shake : -shake, 0),
              // Hanya api yang menunggu ketukan yang menjadi tombol; Pressable nonaktif akan meredupkan api.
              child: waiting
                  ? Pressable(
                      key: const ValueKey('streak-splash-flame'),
                      onPressed: _tap,
                      semanticLabel: stageLabel,
                      builder: (context, pressed) => Stack(clipBehavior: Clip.none, children: flames),
                    )
                  : Semantics(
                      key: const ValueKey('streak-splash-flame'),
                      label: stageLabel,
                      image: true,
                      child: Stack(clipBehavior: Clip.none, children: flames),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blocks(AppLocalizations l, StreakView view, {required bool waiting, required bool revived}) {
    final color = _textColor(view, waiting: waiting, revived: revived);
    final number = TermulText.countXl.copyWith(color: color);
    Widget unit(String text) => Text(
      text.toUpperCase(),
      textAlign: TextAlign.center,
      style: streakMono(11.5, medium: false).copyWith(color: _white65, letterSpacing: 1.38),
    );
    Widget message(String text) => Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TermulText.bodySm.copyWith(color: _white86, fontSize: 14, height: 1.45),
        ),
      ),
    );
    Widget badge(String text, double pop) => Transform.scale(
      scale: 0.55 + 0.45 * _overshoot.transform(pop),
      child: Opacity(
        opacity: pop > 0 ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(TermulRadius.radiusPill)),
          child: Text(
            text,
            style: TermulText.caption.copyWith(color: _onBadge, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
    Widget roll(String from, String to, double t) => SizedBox(
      height: 72,
      child: ClipRect(
        child: Semantics(
          label: to,
          excludeSemantics: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, -72 * t),
                child: Text(from, style: number),
              ),
              Transform.translate(
                offset: Offset(0, 72 * (1 - t)),
                child: Text(to, style: number),
              ),
            ],
          ),
        ),
      ),
    );
    Widget column(List<Widget> children, {double opacity = 1}) => Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Column(mainAxisSize: MainAxisSize.min, spacing: TermulSpacing.space3, children: children),
    );

    switch (_kind) {
      case _Kind.active:
        final tier = StreakTier.of(_to);
        final changed = StreakTier.of(_from) != tier;
        final label = _from < Streak.activeFrom
            ? l.streakSplashLit(tierName(l, tier))
            : changed
            ? l.streakSplashLevelUp(tierName(l, tier))
            : null;
        return column([
          roll(streakNumberText(l, _from), streakNumberText(l, _to), Curves.fastOutSlowIn.transform(_phase(1, 0.45))),
          unit(_from < Streak.activeFrom ? l.streakUnitDays : l.streakSplashUnit),
          if (label != null) badge(label, _phase(1, 0.45)),
        ]);
      case _Kind.ember:
        return column([
          Transform.scale(
            scale: 0.55 + 0.45 * _overshoot.transform(_phase(0.1, 0.45)),
            child: SizedBox(
              height: 72,
              child: Center(child: Text(l.streakCountKindling(_to), style: number)),
            ),
          ),
          unit(l.streakUnitDays),
          message(l.streakStatusKindling),
        ]);
      case _Kind.gray || _Kind.frozen:
        if (revived) {
          final r = _relit.value;
          return column([
            roll(
              streakNumberText(l, view.count - 1),
              streakNumberText(l, view.count),
              Curves.fastOutSlowIn.transform(((r * 0.75 - 0.3) / 0.45).clamp(0.0, 1.0)),
            ),
            unit(l.streakSplashUnit),
            badge(tierName(l, StreakTier.of(view.count)), ((r * 0.75 - 0.3) / 0.45).clamp(0.0, 1.0)),
            message(l.streakSplashRelit),
          ]);
        }
        final status = view.status;
        return column([
          SizedBox(
            height: 72,
            child: Center(child: Text('${view.count}', style: number)),
          ),
          unit(l.streakSplashUnit),
          if (status case StreakFrozen(:final missed, :final clicks)) ...[
            message(l.streakStatusFrozen(missed, clicks)),
            Text(l.streakSplashCracks(view.cracks, clicks), style: streakMono(12).copyWith(color: _iceText)),
          ] else
            message(l.streakStatusGray),
        ]);
      case _Kind.reset:
        final event = widget.event as StreakExpiredEvent;
        final struck = _t >= 1;
        final first = column([
          SizedBox(
            height: 72,
            child: Center(
              child: Text(
                '${event.lost}',
                style: number.copyWith(
                  decoration: struck ? TextDecoration.lineThrough : null,
                  decorationThickness: 4,
                  decorationColor: color,
                  color: struck ? color.withValues(alpha: 0.7) : color,
                ),
              ),
            ),
          ),
          unit(l.streakSplashUnit),
          message(l.streakSplashExpired(event.missed, event.lost)),
        ], opacity: 1 - _phase(3, 0.25));
        final second = column([
          Transform.scale(
            scale: 0.55 + 0.45 * _overshoot.transform(_phase(3.2, 0.45)),
            child: SizedBox(
              height: 72,
              child: Center(child: Text(l.streakCountKindling(1), style: number)),
            ),
          ),
          unit(l.streakUnitDays),
          message(l.streakSplashRestart),
        ], opacity: _phase(3.2, 0.35));
        // Dua blok bertumpuk; yang tidak terlihat dikeluarkan dari pembaca layar.
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ExcludeSemantics(excluding: _t >= 3.2, child: first),
            ExcludeSemantics(excluding: _t < 3.2, child: second),
          ],
        );
    }
  }
}

/// Percikan, cincin, serpihan es, dan asap di panggung splash (koordinat 240 x 210, pusat 120, 128).
class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.kind, required this.palette, this.t, this.fx, this.fxT});

  final _Kind kind;
  final StreakTier palette;

  /// Detik garis waktu; null bila sudah selesai.
  final double? t;
  final _Fx? fx;

  /// 0..1 efek ketukan; null bila tidak berjalan.
  final double? fxT;

  static const _cx = 120.0;
  static const _cy = 128.0;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t;
    if (time != null) {
      if (kind == _Kind.active) {
        _ring(canvas, (time - 1) / 0.6);
        _sparks(canvas, 18, (time - 1) / 0.9, 110);
      }
      if (kind == _Kind.reset) _sparks(canvas, 10, (time - 3.2) / 0.9, 80, tier: StreakTier.bara);
    }
    final p = fxT;
    if (p == null || fx == null) return;
    switch (fx!) {
      case _Fx.puff:
        for (var i = 0; i < 5; i++) {
          final local = ((p - i * 0.08) / 1).clamp(0.0, 1.0);
          if (local <= 0 || local >= 1) continue;
          final e = Curves.easeOut.transform(local);
          canvas.drawCircle(
            Offset(_cx - 30 + i * 12 + 7, _cy - 70 + 7 - 46 * e),
            7 * (0.8 + 1.1 * e),
            Paint()..color = const Color(0xFFB4B8BD).withValues(alpha: 0.4 * (1 - e)),
          );
        }
      case _Fx.chips:
        _shards(canvas, 4, p / 0.8, 70);
      case _Fx.shatter:
        _shards(canvas, 18, p / 0.8, 130);
        _ring(canvas, p / 0.6);
        _sparks(canvas, 18, p / 0.9, 110);
      case _Fx.burst:
        _ring(canvas, p / 0.6);
        _sparks(canvas, 18, p / 0.9, 110);
    }
  }

  void _ring(Canvas canvas, double p) {
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeOut.transform(p);
    canvas.drawCircle(
      const Offset(_cx, _cy),
      36 * (0.3 + 1.9 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (0.3 + 1.9 * e)
        ..color = palette.mid.withValues(alpha: 0.9 * (1 - e)),
    );
  }

  void _sparks(Canvas canvas, int n, double p, double radius, {StreakTier? tier}) {
    if (p <= 0 || p >= 1) return;
    final pal = tier ?? palette;
    final e = Curves.easeOut.transform(p);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + (i % 3) * 0.2;
      final r = radius * (0.7 + ((i * 37) % 10) / 12);
      final dx = math.cos(a) * r;
      final dy = math.sin(a) * r - 20;
      // sp-bA: sampai 60% mendekati ujung sambil naik sedikit, lalu jatuh 46 px dan memudar.
      final Offset off;
      final double scale;
      final double alpha;
      if (e < 0.6) {
        final k = e / 0.6;
        off = Offset(dx * 0.85 * k, (dy * 0.85 - 14) * k);
        scale = 1 - 0.2 * k;
        alpha = 1;
      } else {
        final k = (e - 0.6) / 0.4;
        off = Offset(dx * (0.85 + 0.15 * k), (dy * 0.85 - 14) + (dy + 46 - (dy * 0.85 - 14)) * k);
        scale = 0.8 - 0.5 * k;
        alpha = 1 - k;
      }
      canvas.drawCircle(
        const Offset(_cx, _cy) + off,
        3 * scale,
        Paint()..color = (i.isEven ? pal.core : pal.mid).withValues(alpha: alpha),
      );
    }
  }

  void _shards(Canvas canvas, int n, double p, double spread) {
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeOut.transform(p);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + 0.4;
      final start = Offset(_cx - 7 + ((i * 17) % 40) - 20, _cy - 8 + ((i * 29) % 50) - 25);
      final move = Offset(math.cos(a) * spread, math.sin(a) * spread - 30 + 70);
      final rot = (((i * 53) % 360) - 180) * math.pi / 180 * e;
      canvas
        ..save()
        ..translate(start.dx + 7 + move.dx * e, start.dy + 8 + move.dy * e)
        ..rotate(rot);
      final path = Path()
        ..moveTo(0, -8)
        ..lineTo(7, 4.8)
        ..lineTo(-7, 3.2)
        ..close();
      canvas
        ..drawPath(path, Paint()..color = _shardColor.withValues(alpha: _shardColor.a * (1 - e)))
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.t != t || old.fxT != fxT || old.fx != fx || old.kind != kind || old.palette != palette;
}
