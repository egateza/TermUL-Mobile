import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/streak/streak.dart';
import '../../core/streak/streak_tier.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/flame.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../shell/main_tab.dart';
import 'streak_cards.dart';
import 'streak_controller.dart';
import 'streak_help_sheet.dart';
import 'streak_text.dart';

/// Tab "Streak" (prototipe 8 `Streak`, 8b, 8c): api besar yang bisa diketuk untuk menyalakan api padam atau
/// memecahkan es, angka hari, pekan ini, statistik, progres level, kalender bulan ini, dan bantuan.
///
/// Sebagai tab, layar ini tanpa tombol kembali; tombol Pengaturan di header membuka tab Pengaturan. Animasi masuk
/// (cincin, angka bergulir, lencana, bilah level, sel hari ini) diputar saat tab pertama kali dibuka dan lewat
/// "Putar ulang animasi"; reduce motion melewatinya.
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> with TickerProviderStateMixin {
  /// Animasi masuk: 0..1 selama 1,3 detik.
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  /// Guncangan tiap ketukan (260 ms).
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  /// Serpihan es saat pecah (700 ms).
  late final _shards = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  bool _shakeLeft = true;
  bool _hideCorruptBanner = false;

  /// Api baru saja dinyalakan dari padam ([StreakGray]) atau beku ([StreakFrozen]); menentukan teks status.
  Type? _relitFrom;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playIntro());
  }

  @override
  void dispose() {
    _intro.dispose();
    _shake.dispose();
    _shards.dispose();
    super.dispose();
  }

  void _playIntro() {
    if (!mounted) return;
    if (_reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward(from: 0);
    }
  }

  void _tap() {
    final before = ref.read(streakControllerProvider).status;
    final effect = ref.read(streakControllerProvider.notifier).tap();
    if (effect == StreakTapEffect.poke) return;
    if (!_reduceMotion) {
      _shakeLeft = !_shakeLeft;
      _shake.forward(from: 0);
    }
    if (effect == StreakTapEffect.revive || effect == StreakTapEffect.shatter) {
      setState(() => _relitFrom = before.runtimeType);
      if (effect == StreakTapEffect.shatter && !_reduceMotion) _shards.forward(from: 0);
      _playIntro();
    }
  }

  void _openSettings() => ref.read(mainTabProvider.notifier).select('settings');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(streakControllerProvider);
    final report = ref.watch(bootReportProvider);
    final days = StreakDays(view);
    return Scaffold(
      backgroundColor: TermulPalette.ground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space8,
                TermulSpacing.space5,
                TermulSpacing.space3,
                TermulSpacing.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.streakTitle, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
                    ),
                  ),
                  TermulIconButton(
                    icon: TermulIconName.help,
                    label: l.streakHelpLabel,
                    onPressed: () => showStreakHelp(context, onOpenSettings: _openSettings),
                  ),
                  TermulIconButton(
                    icon: TermulIconName.settings,
                    label: l.streakSettingsLabel,
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  final t = _intro.value * 1300; // milidetik sejak animasi masuk dimulai
                  double phase(double start, double length) => ((t - start) / length).clamp(0.0, 1.0);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space5,
                      TermulSpacing.space1,
                      TermulSpacing.space5,
                      TermulSpacing.space8,
                    ),
                    children: [
                      if (report.streak.hadCorruptFile && !_hideCorruptBanner) ...[
                        TermulBanner(
                          tone: BannerTone.warn,
                          title: l.streakCorruptTitle,
                          action: TermulButton(
                            label: l.actionClose,
                            size: TermulButtonSize.sm,
                            variant: TermulButtonVariant.secondary,
                            onPressed: () => setState(() => _hideCorruptBanner = true),
                          ),
                          child: Text(l.streakCorruptBody(report.streak.quarantinedPath!.split(RegExp(r'[\\/]')).last)),
                        ),
                        const SizedBox(height: TermulSpacing.space5),
                      ],
                      _Hero(
                        view: view,
                        relitFrom: _relitFrom,
                        ring: phase(100, 700),
                        roll: phase(350, 450),
                        badge: phase(700, 350),
                        shake: _shake,
                        shakeLeft: _shakeLeft,
                        shards: _shards,
                        onTap: _tap,
                        onReplay: _playIntro,
                      ),
                      const SizedBox(height: TermulSpacing.space5),
                      StreakWeekCard(days: days, pop: phase(450, 450)),
                      const SizedBox(height: TermulSpacing.space5),
                      StreakStatsRow(view: view),
                      const SizedBox(height: TermulSpacing.space5),
                      StreakLevelCard(count: view.count, grow: view.todayCounted ? phase(500, 600) : 1),
                      const SizedBox(height: TermulSpacing.space5),
                      StreakCalendarCard(days: days, pop: phase(450, 450)),
                      const SizedBox(height: TermulSpacing.space5),
                      _HelpRow(onPressed: () => showStreakHelp(context, onOpenSettings: _openSettings)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu api besar: api yang bisa diketuk, angka hari, teks status, titik progres ketukan, dan "Hari ini selesai".
class _Hero extends StatelessWidget {
  const _Hero({
    required this.view,
    required this.relitFrom,
    required this.ring,
    required this.roll,
    required this.badge,
    required this.shake,
    required this.shakeLeft,
    required this.shards,
    required this.onTap,
    required this.onReplay,
  });

  final StreakView view;
  final Type? relitFrom;
  final double ring;
  final double roll;
  final double badge;
  final Animation<double> shake;
  final bool shakeLeft;
  final Animation<double> shards;
  final VoidCallback onTap;
  final VoidCallback onReplay;

  String _status(AppLocalizations l) {
    final status = view.status;
    final left = view.need - view.progress;
    return switch (status) {
      StreakGray() => view.progress > 0 ? l.streakStatusGrayLeft(left) : l.streakStatusGray,
      StreakFrozen(:final missed, :final clicks) =>
        view.progress > 0 ? l.streakStatusFrozenLeft(left) : l.streakStatusFrozen(missed, clicks),
      StreakKindling() => l.streakStatusKindling,
      _ when relitFrom == StreakGray => l.streakStatusGrayRelit,
      _ when relitFrom == StreakFrozen => l.streakStatusFrozenRelit,
      _ => l.streakStatusActive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = view.status;
    final waiting = view.waiting;
    final counted = view.todayCounted;
    final count = view.count;
    final mode = flameModeOf(status);
    final tier = StreakTier.of(count);
    final stageLabel = switch (status) {
      StreakGray() => l.streakStageGray,
      StreakFrozen() => l.streakStageFrozen,
      _ => l.streakStageActive,
    };
    final numberStyle = TermulText.countLg.copyWith(color: waiting ? TermulPalette.inkFaint : TermulPalette.ink);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space7, vertical: TermulSpacing.space8),
      decoration: BoxDecoration(
        color: TermulPalette.surface,
        borderRadius: BorderRadius.circular(TermulRadius.radius2xl),
        border: Border.all(color: TermulPalette.line),
      ),
      child: Column(
        spacing: TermulSpacing.space5,
        children: [
          SizedBox(
            width: 150,
            height: 140,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (counted && ring > 0 && ring < 1)
                  Positioned(
                    left: 25,
                    top: 25,
                    width: 100,
                    height: 100,
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: 1 + 0.9 * Curves.easeOut.transform(ring),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tier.mid.withValues(alpha: 0.55 * (1 - Curves.easeOut.transform(ring))),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedBuilder(
                  animation: shake,
                  builder: (context, child) {
                    final s = shake.value;
                    // shakeA/shakeB: geser kiri 5, kanan 4, kembali; miring sedikit.
                    final dx = s == 0 || s == 1
                        ? 0.0
                        : s < 0.25
                        ? -5 * (s / 0.25)
                        : s < 0.6
                        ? -5 + 9 * ((s - 0.25) / 0.35)
                        : 4 * (1 - (s - 0.6) / 0.4);
                    final rot = dx / 5 * 1.5 * math.pi / 180;
                    return Transform.translate(
                      offset: Offset(shakeLeft ? dx : -dx, 0),
                      child: Transform.rotate(angle: shakeLeft ? rot : -rot, child: child),
                    );
                  },
                  child: Pressable(
                    key: const ValueKey('streak-hero-flame'),
                    onPressed: waiting ? onTap : null,
                    semanticLabel: stageLabel,
                    builder: (context, pressed) => SizedBox(
                      width: 150,
                      height: 140,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 10,
                            bottom: 6,
                            child: Flame(
                              count: count,
                              mode: mode,
                              size: 100,
                              cracks: view.cracks,
                              need: view.need == 0 ? 5 : view.need,
                              animate: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: shards,
                  builder: (context, _) {
                    final s = shards.value;
                    if (s == 0 || s == 1) return const SizedBox.shrink();
                    final e = Curves.easeOut.transform(s);
                    const pieces = [
                      (-60.0, -46.0, -140.0),
                      (54.0, -56.0, 120.0),
                      (-66.0, 14.0, -90.0),
                      (62.0, 20.0, 160.0),
                      (-26.0, 62.0, -60.0),
                      (34.0, 66.0, 80.0),
                      (0.0, -66.0, 30.0),
                    ];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final (dx, dy, rot) in pieces)
                          Positioned(
                            left: 70 + dx * e,
                            top: 70 + dy * e,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 1 - e,
                                child: Transform.rotate(
                                  angle: rot * e * math.pi / 180,
                                  child: Container(
                                    width: 10,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: TermulPalette.flameIceCore,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: TermulSpacing.space3,
            children: [
              Flexible(
                child: SizedBox(
                  height: 56,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ClipRect(
                      child: counted && roll < 1
                          ? _Roll(
                              from: streakNumberText(l, math.max(0, count - 1)),
                              to: streakNumberText(l, count),
                              t: Curves.fastOutSlowIn.transform(roll),
                              style: numberStyle,
                            )
                          : Text(streakNumberText(l, count), style: numberStyle),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
                  child: Text(
                    l.streakUnitDays,
                    style: TermulText.body.copyWith(color: TermulPalette.inkMuted, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              _status(l),
              textAlign: TextAlign.center,
              style: TermulText.bodySm.copyWith(color: TermulPalette.inkSoft, fontSize: 14, height: 1.5),
            ),
          ),
          if (waiting)
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: TermulSpacing.space3,
                children: [
                  for (var i = 0; i < view.need; i++)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < view.progress ? TermulPalette.accent : Colors.transparent,
                        border: Border.all(color: TermulPalette.accent, width: 2),
                      ),
                    ),
                ],
              ),
            ),
          if (counted)
            Column(
              spacing: 2,
              children: [
                Opacity(
                  opacity: Curves.easeOut.transform(badge),
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - Curves.easeOut.transform(badge))),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: TermulSize.tapMin),
                      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space7),
                      decoration: BoxDecoration(
                        color: TermulPalette.okBg,
                        borderRadius: BorderRadius.circular(TermulRadius.radiusPill),
                        border: Border.all(color: TermulPalette.okLine),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: TermulSpacing.space3,
                        children: [
                          const TermulIcon(TermulIconName.check, size: 18, color: TermulPalette.ok),
                          Text(
                            l.streakTodayDone,
                            style: TermulText.bodySm.copyWith(
                              color: TermulPalette.ok,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Pressable(
                  onPressed: onReplay,
                  semanticLabel: l.streakReplay,
                  builder: (context, pressed) => Container(
                    constraints: const BoxConstraints(minHeight: TermulSize.tapMin),
                    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space5),
                    alignment: Alignment.center,
                    child: Text(
                      l.streakReplay,
                      style: TermulText.caption.copyWith(
                        color: TermulPalette.inkMuted,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: TermulPalette.inkMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Angka bergulir dari [from] ke [to] (roll di prototipe).
class _Roll extends StatelessWidget {
  const _Roll({required this.from, required this.to, required this.t, required this.style});

  final String from;
  final String to;
  final double t;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: to,
      excludeSemantics: true,
      // Dua angka bertumpuk: yang lama naik keluar, yang baru naik masuk (tinggi baris 56 = `count-lg`).
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, -56 * t),
            child: Text(from, style: style),
          ),
          Transform.translate(
            offset: Offset(0, 56 * (1 - t)),
            child: Text(to, style: style),
          ),
        ],
      ),
    );
  }
}

/// Baris pembuka bantuan di bawah kalender.
class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Pressable(
      onPressed: onPressed,
      semanticLabel: l.streakHelpRow,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6),
        decoration: BoxDecoration(
          color: pressed ? TermulPalette.surfaceRaised : TermulPalette.surface,
          borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
          border: Border.all(color: TermulPalette.line),
        ),
        child: Row(
          spacing: TermulSpacing.space5,
          children: [
            const TermulIcon(TermulIconName.help, size: 24, color: TermulPalette.inkMuted),
            Expanded(
              child: Text(
                l.streakHelpRow,
                style: TermulText.body.copyWith(color: TermulPalette.ink, fontWeight: FontWeight.w500),
              ),
            ),
            const TermulIcon(TermulIconName.chevronRight, size: 18, color: TermulPalette.inkMuted),
          ],
        ),
      ),
    );
  }
}
