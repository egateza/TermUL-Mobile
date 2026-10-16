import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';
import 'termul_icon.dart';

/// Baris dengan label, nilai, dan dua tombol 44 px (kurangi dan tambah) untuk angka dalam rentang kecil
/// (ukuran font, tinggi baris). Tombol di batas rentang nonaktif (`onDecrement` atau `onIncrement` null).
/// Nilai ditulis dengan satuannya, mis. "13 px", bukan hanya angka.
class TermulStepper extends StatelessWidget {
  const TermulStepper({
    super.key,
    required this.label,
    required this.valueText,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String valueText;
  final String decrementLabel;
  final String incrementLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: TermulSize.rowMin),
      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space7, vertical: TermulSpacing.space3),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TermulPalette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TermulText.body.copyWith(color: TermulPalette.ink)),
          ),
          _StepButton(icon: TermulIconName.minus, label: decrementLabel, onPressed: onDecrement),
          Semantics(
            liveRegion: true,
            label: '$label: $valueText',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Text(
                valueText,
                textAlign: TextAlign.center,
                style: TermulText.key.copyWith(color: TermulPalette.ink),
              ),
            ),
          ),
          _StepButton(icon: TermulIconName.plus, label: incrementLabel, onPressed: onIncrement),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onPressed});

  final TermulIconName icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      radius: TermulRadius.radiusMd,
      minWidth: TermulSize.tapMin,
      builder: (context, pressed) => Container(
        width: TermulSize.tapMin,
        height: TermulSize.tapMin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? TermulPalette.accentBg : TermulPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
          border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
        ),
        child: TermulIcon(icon, color: TermulPalette.ink),
      ),
    );
  }
}
