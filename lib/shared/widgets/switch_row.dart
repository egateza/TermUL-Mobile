import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';

/// Baris pengaturan dengan label, deskripsi opsional, dan sakelar 48x28. Seluruh baris adalah target sentuh
/// (minimal 64 px). Label menyebut apa yang dinyalakan, deskripsi menyebut akibat dan batasnya.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: description == null ? label : '$label. $description',
      toggled: value,
      minHeight: TermulSize.rowComfy,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: TermulSize.rowComfy),
        padding: const EdgeInsets.symmetric(
          horizontal: TermulSpacing.space6,
          vertical: TermulSpacing.space4,
        ),
        decoration: BoxDecoration(
          color: TermulPalette.surface,
          borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
          border: Border.all(
            color: pressed ? TermulPalette.accent : TermulPalette.line,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TermulText.body.copyWith(color: TermulPalette.ink),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: TermulText.caption.copyWith(
                        color: TermulPalette.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: TermulSpacing.space6),
            _Track(on: value),
          ],
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? TermulPalette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(TermulRadius.radiusPill),
        border: Border.all(
          color: on ? TermulPalette.accent : TermulPalette.lineStrong,
          width: 1.5,
        ),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: on ? TermulPalette.onAccent : TermulPalette.inkMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
