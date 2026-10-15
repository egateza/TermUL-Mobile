import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';
import 'termul_icon.dart';

enum TermulButtonVariant { primary, secondary, ghost, danger }

enum TermulButtonSize {
  lg(TermulSize.buttonLg, 16),
  md(TermulSize.buttonMd, 15),
  sm(TermulSize.tapMin, 14);

  const TermulButtonSize(this.height, this.fontSize);

  final double height;
  final double fontSize;
}

/// Tombol teks. Satu `primary` per layar atau sheet; di dialog berisiko, pilihan aman jadi `primary`.
/// Label singkat tanpa titik. `onPressed` null = nonaktif (opasitas 0,4).
class TermulButton extends StatelessWidget {
  const TermulButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TermulButtonVariant.secondary,
    this.size = TermulButtonSize.md,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final TermulButtonVariant variant;
  final TermulButtonSize size;
  final TermulIconName? icon;

  /// Mengisi lebar yang tersedia.
  final bool expand;

  double get _radius => size == TermulButtonSize.lg ? TermulRadius.radiusXl : TermulRadius.radiusLg;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      radius: _radius,
      minHeight: size.height,
      builder: (context, pressed) {
        final (bg, fg, border) = _colors(pressed);
        return Container(
          constraints: BoxConstraints(minHeight: size.height),
          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_radius),
            border: border == null ? null : Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                TermulIcon(icon!, size: 18, color: fg),
                const SizedBox(width: TermulSpacing.space3),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TermulText.label.copyWith(
                    color: fg,
                    fontSize: size.fontSize,
                    fontWeight: variant == TermulButtonVariant.primary ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (Color, Color, Color?) _colors(bool pressed) {
    if (pressed && variant != TermulButtonVariant.primary) {
      return (TermulPalette.accent, TermulPalette.onAccent, TermulPalette.accent);
    }
    return switch (variant) {
      TermulButtonVariant.primary => (
        pressed ? TermulPalette.accentLine : TermulPalette.accent,
        pressed ? TermulPalette.ink : TermulPalette.onAccent,
        null,
      ),
      TermulButtonVariant.secondary => (Colors.transparent, TermulPalette.ink, TermulPalette.lineStrong),
      TermulButtonVariant.ghost => (Colors.transparent, TermulPalette.inkMuted, null),
      TermulButtonVariant.danger => (Colors.transparent, TermulPalette.bad, TermulPalette.bad),
    };
  }
}
