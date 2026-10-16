import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_button.dart';

/// Popover "Tempel" untuk satu baris pendek yang aman (prototipe `TerminalPasteMenu`): menampilkan teks yang akan
/// ditempel supaya bisa diperiksa dulu, dengan tombol Tempel. Teks panjang, banyak baris, atau berisiko tidak lewat
/// sini, melainkan dialog konfirmasi. Posisi diatur pemanggil.
///
/// Di layar pendek (landscape, tinggi kurang dari [compactBelowDp]) susunannya mendatar: teks dan keterangan di
/// kiri, tombol Tempel di kanan. Tingginya sekitar 56 dp, bukan sekitar 100 dp, karena dengan keyboard terbuka di
/// landscape area yang tersisa hanya sekitar 130 dp.
class PastePopover extends StatelessWidget {
  const PastePopover({super.key, required this.text, required this.onPaste});

  /// Teks bersih yang akan dikirim (satu baris, tanpa karakter kontrol).
  final String text;
  final VoidCallback onPaste;

  static const maxWidth = 280.0;
  static const compactMaxWidth = 420.0;
  static const compactBelowDp = 480.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).height < compactBelowDp;
    final label = Text(
      text,
      key: const ValueKey('paste-popover-text'),
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: TermulText.terminalSm.copyWith(color: TermulPalette.ink),
    );
    final hint = Text(
      l.pasteMenuHint,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TermulText.caption.copyWith(fontSize: 11.5, color: TermulPalette.inkMuted),
    );
    final button = TermulButton(
      label: l.keyPaste,
      variant: TermulButtonVariant.primary,
      size: TermulButtonSize.sm,
      expand: !compact,
      onPressed: onPaste,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? compactMaxWidth : maxWidth),
      child: Container(
        key: const ValueKey('paste-popover'),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: TermulPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
          border: Border.all(color: TermulPalette.line),
        ),
        child: compact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                spacing: TermulSpacing.space5,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [label, hint],
                      ),
                    ),
                  ),
                  button,
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 0), child: label),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: hint),
                  button,
                ],
              ),
      ),
    );
  }
}
