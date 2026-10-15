import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/termul_theme.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/termul_banner.dart';

/// Ditampilkan bila penyimpanan tidak bisa dibuka saat mulai (mis. berkas rusak tidak bisa disisihkan).
/// Tidak ada data yang ditimpa; pengguna diminta memulai ulang.
class BootErrorApp extends StatelessWidget {
  const BootErrorApp({super.key});

  @override
  Widget build(BuildContext context) => termulMaterialApp(home: const _BootErrorScreen());
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TermulSpacing.space8),
          child: Center(
            child: TermulBanner(tone: BannerTone.risk, title: l.bootErrorTitle, child: Text(l.bootErrorBody)),
          ),
        ),
      ),
    );
  }
}
