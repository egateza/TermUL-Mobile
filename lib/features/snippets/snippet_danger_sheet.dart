import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_sheet.dart';

/// Peringatan sebelum memakai perintah snippet yang berbahaya (ditandai pemilik atau terdeteksi otomatis): peringatan
/// dan isi perintah ditampilkan, Batal menjadi tombol utama, dan [confirmLabel] ("Tetap salin" atau "Tetap tempel")
/// bervarian bahaya. Tanpa konfirmasi tidak ada yang disalin atau ditempel.
void showSnippetDangerSheet(
  BuildContext context, {
  required String command,
  required String confirmLabel,
  required VoidCallback onConfirm,
}) {
  final l = AppLocalizations.of(context);
  showTermulSheet<void>(
    context,
    title: l.snippetDangerWarnTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TermulSpacing.space5,
      children: [
        TermulBanner(tone: BannerTone.risk, child: Text(l.snippetDangerWarnBody)),
        Container(
          padding: const EdgeInsets.all(TermulSpacing.space5),
          decoration: BoxDecoration(
            color: TermulPalette.ground,
            borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
            border: Border.all(color: TermulPalette.badLine),
          ),
          child: Text(
            command,
            style: TermulText.terminal.copyWith(color: TermulPalette.inkSoft, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    ),
    cancelLabel: l.actionCancel,
    confirmLabel: confirmLabel,
    confirmIsDanger: true,
    cancelIsPrimary: true,
    onConfirm: onConfirm,
  );
}
