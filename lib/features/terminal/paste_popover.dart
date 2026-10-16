import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_button.dart';

/// Popover "Tempel" di kursor prompt (prototipe `TerminalPasteMenu`): tombol Tempel dan ringkasan isi papan klip.
/// Posisi diatur pemanggil (di atas kursor, rata kanan dengan kursor).
class PastePopover extends StatelessWidget {
  const PastePopover({super.key, required this.clipLines, required this.onPaste});

  /// Jumlah baris di papan klip; 0 bila kosong.
  final int clipLines;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('paste-popover'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: TermulPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
        border: Border.all(color: TermulPalette.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          TermulButton(
            label: l.keyPaste,
            variant: TermulButtonVariant.primary,
            size: TermulButtonSize.sm,
            expand: false,
            onPressed: onPaste,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
            child: Text(
              l.pasteMenuClipboard(clipLines == 0 ? l.pasteMenuClipboardEmpty : l.pasteMenuLines(clipLines)),
              style: TermulText.caption.copyWith(fontSize: 11.5, color: TermulPalette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
