import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';

enum CardTone { surface, inset, selected }

enum CardPadding {
  none(0),
  md(TermulSpacing.space6),
  lg(TermulSpacing.space7);

  const CardPadding(this.value);

  final double value;
}

/// Wadah dengan tepi 1 px (tanpa bayangan) dan sudut `radius-xl`. Bila [onTap] diberikan, jadi kontrol yang
/// bisa ditekan dan wajib punya nama ([semanticLabel]) bila isinya tidak cukup menjelaskan.
class TermulCard extends StatelessWidget {
  const TermulCard({
    super.key,
    required this.child,
    this.tone = CardTone.surface,
    this.padding = CardPadding.md,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final CardTone tone;
  final CardPadding padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget box(bool pressed) => Container(
      padding: EdgeInsets.all(padding.value),
      decoration: BoxDecoration(
        color: tone == CardTone.inset
            ? TermulPalette.groundDeep
            : TermulPalette.surface,
        borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
        border: Border.all(
          color: tone == CardTone.selected || pressed
              ? TermulPalette.accent
              : TermulPalette.line,
        ),
      ),
      child: child,
    );
    if (onTap == null) return box(false);
    return Pressable(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      radius: TermulRadius.radiusXl,
      builder: (context, pressed) => box(pressed),
    );
  }
}
