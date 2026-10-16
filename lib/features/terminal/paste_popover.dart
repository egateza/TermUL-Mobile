import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_button.dart';

/// Popover "Tempel" untuk satu baris pendek yang aman (prototipe `TerminalPasteMenu`): menampilkan teks yang akan
/// ditempel supaya bisa diperiksa dulu, dengan tombol Tempel. Teks panjang, banyak baris, atau berisiko tidak lewat
/// sini, melainkan dialog konfirmasi. Posisi diatur pemanggil.
class PastePopover extends StatelessWidget {
  const PastePopover({super.key, required this.text, required this.onPaste});

  /// Teks bersih yang akan dikirim (satu baris, tanpa karakter kontrol).
  final String text;
  final VoidCallback onPaste;

  static const maxWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Container(
        key: const ValueKey('paste-popover'),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: TermulPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
          border: Border.all(color: TermulPalette.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Text(
                text,
                key: const ValueKey('paste-popover-text'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TermulText.terminalSm.copyWith(color: TermulPalette.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                l.pasteMenuHint,
                style: TermulText.caption.copyWith(fontSize: 11.5, color: TermulPalette.inkMuted),
              ),
            ),
            TermulButton(
              label: l.keyPaste,
              variant: TermulButtonVariant.primary,
              size: TermulButtonSize.sm,
              onPressed: onPaste,
            ),
          ],
        ),
      ),
    );
  }
}
