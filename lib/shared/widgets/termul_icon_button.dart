import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';
import 'termul_icon.dart';

enum IconButtonTone { plain, filled, accent }

/// Tombol persegi 44 px berisi ikon saja. [label] wajib (kata kerja: "Tutup", "Tambah host"); menjadi nama
/// aksesibilitas dan tooltip.
class TermulIconButton extends StatelessWidget {
  const TermulIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = IconButtonTone.plain,
    this.pressed = false,
  });

  final TermulIconName icon;
  final String label;
  final VoidCallback? onPressed;
  final IconButtonTone tone;

  /// Keadaan menyala (isian `accent`), bukan mengganti ikon.
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Pressable(
        onPressed: onPressed,
        semanticLabel: label,
        toggled: pressed ? true : null,
        minWidth: TermulSize.tapMin,
        builder: (context, down) {
          final on = down || pressed || tone == IconButtonTone.accent;
          final bg = on
              ? TermulPalette.accent
              : (tone == IconButtonTone.filled
                    ? TermulPalette.surfaceRaised
                    : Colors.transparent);
          final fg = on ? TermulPalette.onAccent : TermulPalette.ink;
          return Container(
            width: TermulSize.tapMin,
            height: TermulSize.tapMin,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
            ),
            alignment: Alignment.center,
            child: TermulIcon(icon, size: 22, color: fg),
          );
        },
      ),
    );
  }
}
