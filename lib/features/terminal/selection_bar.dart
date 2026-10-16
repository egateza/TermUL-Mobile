import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_icon.dart';

/// Bilah aksi yang menggantikan tombol cepat selama ada seleksi (layar seleksi di desain): jumlah karakter,
/// Batal, lalu Salin dan Semua. Cari, Kirim ke host lain, snippet, dan Bagikan di prototipe belum dibuat.
/// Tombol tidak mengambil fokus supaya keyboard sistem tetap terbuka.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onCopy,
    required this.onSelectAll,
    required this.onCancel,
    this.compact = false,
  });

  final int count;
  final VoidCallback onCopy;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;

  /// Landscape ringkas: satu baris, tanpa petunjuk, tombol 44 dp berdampingan dengan jumlah.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(l.selectionCount(count), style: TermulText.terminalSm.copyWith(color: TermulPalette.ink)),
        ),
        if (!compact) Text(l.selectionHint, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
      ],
    );
    final cancel = Pressable(
      semanticLabel: l.actionCancel,
      canRequestFocus: false,
      onPressed: onCancel,
      builder: (context, pressed) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space5),
        child: Center(
          widthFactor: 1,
          child: Text(l.actionCancel, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
        ),
      ),
    );
    final copy = _tile(l.selectionCopy, l.selectionCopyAria, TermulIconName.copy, onCopy, primary: true);
    final all = _tile(l.selectionAll, l.selectionAllAria, TermulIconName.selectAll, onSelectAll);
    return Semantics(
      container: true,
      child: Container(
        decoration: const BoxDecoration(
          color: TermulPalette.ground,
          border: Border(top: BorderSide(color: TermulPalette.line)),
        ),
        padding: const EdgeInsets.all(TermulSpacing.space3),
        child: compact
            ? Row(
                spacing: TermulSpacing.space3,
                children: [
                  Expanded(child: info),
                  SizedBox(width: 120, child: copy),
                  SizedBox(width: 120, child: all),
                  cancel,
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TermulSpacing.space3,
                children: [
                  Row(
                    children: [
                      Expanded(child: info),
                      cancel,
                    ],
                  ),
                  Row(
                    spacing: TermulSpacing.space3,
                    children: [
                      Expanded(child: copy),
                      Expanded(child: all),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tile(String label, String aria, TermulIconName icon, VoidCallback onPressed, {bool primary = false}) {
    return Pressable(
      semanticLabel: aria,
      canRequestFocus: false,
      onPressed: onPressed,
      minHeight: compact ? TermulSize.tapMin : 56,
      builder: (context, pressed) {
        final bg = primary ? (pressed ? TermulPalette.accentLine : TermulPalette.accent) : TermulPalette.surfaceRaised;
        final fg = primary ? (pressed ? TermulPalette.ink : TermulPalette.onAccent) : TermulPalette.ink;
        return Container(
          decoration: BoxDecoration(
            color: !primary && pressed ? TermulPalette.accentBg : bg,
            borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
            border: Border.all(color: primary ? TermulPalette.accent : TermulPalette.line),
          ),
          alignment: Alignment.center,
          child: compact
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: TermulSpacing.space3,
                  children: [
                    TermulIcon(icon, size: 20, color: fg),
                    Text(
                      label,
                      style: TermulText.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 4,
                  children: [
                    TermulIcon(icon, size: 20, color: fg),
                    Text(
                      label,
                      style: TermulText.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
