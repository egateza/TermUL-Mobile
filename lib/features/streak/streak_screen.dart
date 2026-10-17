import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_banner.dart';

/// Tab "Streak" di `NavBar`: sementara hanya pemberitahuan bahwa fitur streak api akan datang. Belum ada logika,
/// penyimpanan, atau api berwarna tier (itu untuk irisan streak yang sebenarnya, lihat `docs/design/streak.md`).
class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TermulPalette.ground,
      body: SafeArea(
        bottom: false,
        // Judul sejajar dengan judul tab Host dan Pengaturan; banner selebar kartu di tab itu.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space8,
                TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space5,
              ),
              child: Semantics(
                header: true,
                child: Text(l.streakTitle, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space5),
              child: TermulBanner(tone: BannerTone.info, title: l.streakSoonTitle, child: Text(l.streakSoonBody)),
            ),
          ],
        ),
      ),
    );
  }
}
