import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/streak/streak.dart';
import '../../core/streak/streak_tier.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/flame.dart';
import '../../shared/widgets/pressable.dart';
import '../shell/main_tab.dart';
import 'streak_controller.dart';
import 'streak_text.dart';

/// Chip streak di header Daftar host (komponen `StreakChip`, prototipe `Main`): api mini dan angka `Nx` atau `N/3`.
/// Warna mengikuti keadaan: tier untuk aktif, `chip-ember` untuk bara, `chip-gray` untuk padam, `chip-ice` di atas
/// `ice-bg` untuk beku. Ketukan membuka tab Streak, tempat api bisa diketuk. Tidak tampil bila "Tampilkan streak api"
/// dimatikan atau hari ini belum dihitung.
class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(appSettingsProvider.select((s) => s.streak.show));
    final view = ref.watch(streakControllerProvider);
    if (!show || !view.opened || view.count == 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final status = view.status;
    final count = view.count;
    final tier = StreakTier.of(count);
    final (fg, border, bg, mode, label) = switch (status) {
      StreakKindling() => (
        TermulPalette.chipEmber,
        TermulPalette.line,
        TermulPalette.surface,
        FlameMode.active,
        l.streakChipKindling(count),
      ),
      StreakGray() || StreakExpired() || StreakNone() => (
        TermulPalette.chipGray,
        TermulPalette.line,
        TermulPalette.surface,
        FlameMode.gray,
        l.streakChipGray(count),
      ),
      StreakFrozen() => (
        TermulPalette.chipIce,
        TermulPalette.iceLine,
        TermulPalette.iceBg,
        FlameMode.frozen,
        l.streakChipFrozen(count),
      ),
      StreakBurning() => (
        tier.mid,
        TermulPalette.line,
        TermulPalette.surface,
        FlameMode.active,
        l.streakChipActive(count, tierName(l, tier)),
      ),
    };
    return Pressable(
      key: const ValueKey('streak-chip'),
      onPressed: () => ref.read(mainTabProvider.notifier).select('streak'),
      radius: TermulRadius.radiusPill,
      semanticLabel: label,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: TermulSize.tapMin),
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space5),
        decoration: BoxDecoration(
          color: pressed ? TermulPalette.surfaceRaised : bg,
          borderRadius: BorderRadius.circular(TermulRadius.radiusPill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: TermulSpacing.space2,
          children: [
            Flame(count: count, mode: mode, size: 18, cracks: view.cracks, need: view.need == 0 ? 5 : view.need),
            Text(streakCountText(l, count), style: streakMono(14).copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
