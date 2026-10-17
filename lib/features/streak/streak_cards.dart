import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/streak/streak.dart';
import '../../core/streak/streak_tier.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import 'streak_controller.dart';
import 'streak_text.dart';

/// Kartu berbingkai 1 px di layar Streak (`radius-xl`, `surface`, tanpa bayangan).
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.child, this.padding = const EdgeInsets.all(TermulSpacing.space6)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: TermulPalette.surface,
      borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
      border: Border.all(color: TermulPalette.line),
    ),
    child: child,
  );
}

TextStyle _cardTitle() =>
    TermulText.title.copyWith(color: TermulPalette.ink, fontSize: 15, fontWeight: FontWeight.w600);

/// Keadaan satu hari di pekan dan kalender.
enum DayKind {
  /// Dihitung (dibuka atau dinyalakan lagi).
  on,

  /// Hari ini, belum terhitung (api padam atau beku menunggu).
  pending,

  future,

  /// Hari lampau yang tidak dihitung.
  missed,

  /// Bagian dari absen yang membuat api padam atau beku.
  absent,
}

/// Menentukan [DayKind] tiap hari dari keadaan streak.
class StreakDays {
  StreakDays(this.view);

  final StreakView view;

  DateTime get today => view.today;

  /// Hari absen yang membuat api padam atau beku: sehari setelah hari terakhir dihitung sampai kemarin.
  ({DateTime from, DateTime to, int count})? get absence {
    if (!view.waiting) return null;
    final last = view.record.streak.lastDay;
    if (last == null) return null;
    final from = last.add(const Duration(days: 1));
    final to = today.subtract(const Duration(days: 1));
    if (to.isBefore(from)) return null;
    return (from: from, to: to, count: daysBetween(from, to) + 1);
  }

  DayKind kind(DateTime day) {
    if (day == today) return view.todayCounted ? DayKind.on : DayKind.pending;
    if (day.isAfter(today)) return DayKind.future;
    if (view.record.isActiveDay(day)) return DayKind.on;
    final a = absence;
    if (a != null && !day.isBefore(a.from) && !day.isAfter(a.to)) return DayKind.absent;
    return DayKind.missed;
  }

  /// Warna hari absen: es untuk beku, abu-abu untuk padam.
  Color get absentTone => view.status is StreakFrozen ? TermulPalette.chipIce : TermulPalette.chipGray;

  String stateLabel(AppLocalizations l, DayKind kind) => switch (kind) {
    DayKind.on => l.streakDayActive,
    DayKind.pending => l.streakDayToday,
    DayKind.future => l.streakDayFuture,
    DayKind.missed => l.streakDayMissed,
    DayKind.absent => l.streakDayAbsent,
  };
}

/// Sel hari: lingkaran di pekan ini, kotak di kalender. [pop] (0..1) membesarkan sel hari ini saat terisi.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.kind,
    required this.text,
    required this.absentTone,
    required this.round,
    required this.semanticLabel,
    this.pop = 1,
  });

  final DayKind kind;
  final String text;
  final Color absentTone;
  final bool round;
  final String semanticLabel;
  final double pop;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, dashed) = switch (kind) {
      DayKind.on => (TermulPalette.accent, TermulPalette.onAccent, TermulPalette.accent, false),
      DayKind.pending => (Colors.transparent, TermulPalette.accent, TermulPalette.accent, true),
      DayKind.future => (
        Colors.transparent,
        TermulPalette.lineStrong,
        round ? TermulPalette.line : Colors.transparent,
        false,
      ),
      DayKind.missed => (
        Colors.transparent,
        TermulPalette.inkMuted,
        round ? TermulPalette.line : Colors.transparent,
        false,
      ),
      DayKind.absent => (Colors.transparent, absentTone, absentTone, true),
    };
    final radius = round ? 18.0 : TermulRadius.radiusMd;
    // Hari ini membesar sedikit lalu kembali (fillIn di prototipe).
    final scale = kind == DayKind.on && pop < 1 ? 0.7 + 0.3 * Curves.elasticOut.transform(pop.clamp(0.0, 1.0)) : 1.0;
    final filled = kind == DayKind.on && pop < 0.35 ? Colors.transparent : bg;
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Transform.scale(
        scale: scale,
        child: CustomPaint(
          painter: DashedBorderPainter(color: border, radius: radius, dashed: dashed),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: filled, borderRadius: BorderRadius.circular(radius)),
            child: Text(
              text,
              // Sebelum terisi (awal animasi), angka hari ini memakai aksen di atas latar kosong.
              style: streakMono(13, medium: false).copyWith(color: filled == bg ? fg : TermulPalette.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tepi 2 px, utuh atau putus-putus (hari ini belum terhitung dan hari absen).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, required this.radius, this.dashed = false, this.width = 2});

  final Color color;
  final double radius;
  final bool dashed;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.circular(math.max(0, radius - width / 2)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (!dashed) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.dashed != dashed || old.width != width;
}

/// Kartu "Pekan ini": Senin sampai Minggu pekan berjalan.
class StreakWeekCard extends StatelessWidget {
  const StreakWeekCard({super.key, required this.days, this.pop = 1});

  final StreakDays days;
  final double pop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = days.today;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final labels = weekdayShort(l);
    return StreakCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space5,
        children: [
          Semantics(header: true, child: Text(l.streakWeek, style: _cardTitle())),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                () {
                  final day = monday.add(Duration(days: i));
                  final kind = days.kind(day);
                  return SizedBox(
                    width: 40,
                    child: Column(
                      spacing: TermulSpacing.space2,
                      children: [
                        ExcludeSemantics(
                          child: Text(labels[i], style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                        ),
                        SizedBox.square(
                          dimension: 36,
                          child: _DayCell(
                            kind: kind,
                            text: '${day.day}',
                            absentTone: days.absentTone,
                            round: true,
                            pop: day == today ? pop : 1,
                            semanticLabel: l.streakDayState(
                              day.day,
                              '${labels[i]}, ${monthShort(l, day.month)}',
                              days.stateLabel(l, kind),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tiga statistik: terpanjang, aktif bulan ini, level api.
class StreakStatsRow extends StatelessWidget {
  const StreakStatsRow({super.key, required this.view});

  final StreakView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = view.today;
    final activeMonth = view.record.days.where((d) => d.year == today.year && d.month == today.month).length;
    final tier = StreakTier.of(view.count);
    Widget stat(String label, String value) => Expanded(
      child: StreakCard(
        padding: const EdgeInsets.all(TermulSpacing.space5),
        child: Semantics(
          container: true,
          label: '$label: $value',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TermulSpacing.space1,
            children: [
              Text(label, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: streakMono(18).copyWith(color: TermulPalette.ink)),
              ),
            ],
          ),
        ),
      ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space3,
        children: [
          stat(l.streakLongest, l.streakDays(view.record.longest)),
          stat(l.streakActiveMonth, l.streakDays(activeMonth)),
          stat(l.streakLevel, l.streakLevelValue(tier.level, tierName(l, tier))),
        ],
      ),
    );
  }
}

/// "Menuju Level N": bilah progres ke level berikutnya dan sembilan lencana level. [grow] (0..1) menganimasikan
/// bilah dari hari sebelumnya ke hari ini.
class StreakLevelCard extends StatelessWidget {
  const StreakLevelCard({super.key, required this.count, this.grow = 1});

  final int count;
  final double grow;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tier = StreakTier.of(count);
    final next = tier.next;
    final double pct;
    final double from;
    if (next == null) {
      pct = 1;
      from = 1;
    } else {
      final span = math.max(1, next.min - tier.min);
      pct = ((count - tier.min) / span).clamp(0.0, 1.0);
      from = ((count - 1 - tier.min) / span).clamp(0.0, 1.0);
    }
    final width = from + (pct - from) * Curves.easeInOut.transform(grow.clamp(0.0, 1.0));
    return StreakCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space5,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    next == null ? l.streakMaxLevel(tierName(l, tier)) : l.streakNextLevel(next.level, next.min),
                    style: _cardTitle(),
                  ),
                ),
              ),
              if (next != null)
                Text(
                  l.streakNextProgress(count, next.min),
                  style: streakMono(12.5, medium: false).copyWith(color: TermulPalette.inkMuted),
                ),
            ],
          ),
          Semantics(
            value: '${(pct * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 8,
                color: TermulPalette.line,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: width,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(color: TermulPalette.accent, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ),
          ),
          Text(
            next == null ? l.streakMaxLevelText : l.streakDaysLeft(math.max(0, next.min - count)),
            style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted, fontSize: 13),
          ),
          Row(
            spacing: 4,
            children: [
              for (final t in StreakTier.values)
                Expanded(
                  child: () {
                    final current = t == tier;
                    final reached = t.level <= tier.level;
                    return Semantics(
                      container: true,
                      label: l.streakLevelBadge(
                        t.level,
                        tierName(l, t),
                        current ? l.streakBadgeCurrent : (reached ? l.streakBadgeReached : l.streakBadgeLocked),
                      ),
                      excludeSemantics: true,
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: current ? t.mid : Colors.transparent,
                          borderRadius: BorderRadius.circular(TermulRadius.radiusSm),
                          border: Border.all(color: reached ? t.mid : TermulPalette.line),
                        ),
                        child: Text(
                          '${t.level}',
                          style: streakMono(13).copyWith(
                            color: current ? TermulPalette.onLevel : (reached ? t.mid : TermulPalette.inkFaint),
                          ),
                        ),
                      ),
                    );
                  }(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kalender bulan berjalan dengan keterangan dan, bila api menunggu, keterangan absennya.
class StreakCalendarCard extends StatelessWidget {
  const StreakCalendarCard({super.key, required this.days, this.pop = 1});

  final StreakDays days;
  final double pop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = days.today;
    final first = DateTime.utc(today.year, today.month);
    final length = DateTime.utc(today.year, today.month + 1).difference(first).inDays;
    final lead = first.weekday - 1;
    final cells = lead + length;
    final rows = (cells / 7).ceil();
    final labels = weekdayShort(l);
    final absence = days.absence;
    final view = days.view;
    return StreakCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space4,
        children: [
          Semantics(
            header: true,
            child: Text(l.streakMonthTitle(monthName(l, today.month), '${today.year}'), style: _cardTitle()),
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final d in labels)
                  Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
          for (var r = 0; r < rows; r++)
            Row(
              spacing: 4,
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: () {
                        final index = r * 7 + c - lead;
                        if (index < 0 || index >= length) return const SizedBox.shrink();
                        final day = first.add(Duration(days: index));
                        final kind = days.kind(day);
                        return _DayCell(
                          kind: kind,
                          text: '${day.day}',
                          absentTone: days.absentTone,
                          round: false,
                          pop: day == today ? pop : 1,
                          semanticLabel: l.streakDayState(day.day, monthName(l, day.month), days.stateLabel(l, kind)),
                        );
                      }(),
                    ),
                  ),
              ],
            ),
          Text(l.streakLegend, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
          if (absence != null)
            Text(
              view.status is StreakFrozen
                  ? l.streakAbsentFrozen(absence.count, dayRange(l, absence.from, absence.to), view.need)
                  : l.streakAbsentGray(absence.count, dayRange(l, absence.from, absence.to)),
              style: TermulText.bodySm.copyWith(color: TermulPalette.ink, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
