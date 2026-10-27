import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';

/// Tombol persegi untuk tombol khusus di atas keyboard dan di panel semua tombol. [pressed] untuk pengubah
/// yang menahan (Ctrl, Alt): menyala dengan isian `accent`. Tidak mengambil fokus, supaya keyboard sistem tidak
/// tertutup saat ditekan. Tinggi bawaan 44 px; [compact] (36 px) hanya untuk landscape ringkas.
class KeyButton extends StatelessWidget {
  const KeyButton({
    super.key,
    required this.label,
    required this.ariaLabel,
    required this.onPressed,
    this.pressed = false,
    this.compact = false,
    this.width = 56,
  });

  final String label;
  final String ariaLabel;
  final VoidCallback? onPressed;
  final bool pressed;
  final bool compact;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 36.0 : TermulSize.tapMin;
    return Pressable(
      onPressed: onPressed,
      semanticLabel: ariaLabel,
      toggled: pressed ? true : null,
      canRequestFocus: false,
      radius: TermulRadius.radiusMd,
      minWidth: width,
      minHeight: height,
      builder: (context, down) {
        final on = down || pressed;
        return Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? TermulPalette.accent : TermulPalette.surfaceRaised,
            borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
          ),
          // Label lebih dari empat huruf (mis. "Tempel") memakai 12 px supaya muat di tombol grid sekitar 47 dp.
          child: Text(
            label,
            style: TermulText.key.copyWith(
              color: on ? TermulPalette.onAccent : TermulPalette.ink,
              fontSize: label.length > 4 ? 12 : null,
            ),
          ),
        );
      },
    );
  }
}
