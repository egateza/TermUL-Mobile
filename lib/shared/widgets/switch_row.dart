import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';
import 'termul_chip.dart' show TagTone, TermulTag;

/// Baris pengaturan dengan label, deskripsi opsional, dan sakelar 48x28. Seluruh baris adalah target sentuh
/// (minimal 64 px). Label menyebut apa yang dinyalakan, deskripsi menyebut akibat dan batasnya.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.dangerTag,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Baris berisiko ("zona bahaya"): latar `bad-bg`, tepi `bad-line`, sakelar menyala `bad`, dan tag berisi kata ini
  /// di samping label (status tidak hanya warna). Null: baris biasa.
  final String? dangerTag;

  bool get danger => dangerTag != null;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: [label, ?dangerTag, ?description].join('. '),
      toggled: value,
      minHeight: TermulSize.rowComfy,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: TermulSize.rowComfy),
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space4),
        decoration: BoxDecoration(
          color: danger ? TermulPalette.badBg : TermulPalette.surface,
          borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
          border: Border.all(
            color: danger
                ? (pressed ? TermulPalette.bad : TermulPalette.badLine)
                : (pressed ? TermulPalette.accent : TermulPalette.line),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (danger)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: TermulSpacing.space3,
                      children: [
                        Text(label, style: TermulText.body.copyWith(color: TermulPalette.ink)),
                        TermulTag(dangerTag!, tone: TagTone.bad),
                      ],
                    )
                  else
                    Text(label, style: TermulText.body.copyWith(color: TermulPalette.ink)),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: TermulText.caption.copyWith(color: danger ? TermulPalette.badInk : TermulPalette.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: TermulSpacing.space6),
            _Track(on: value, danger: danger),
          ],
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.on, required this.danger});

  final bool on;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final onColor = danger ? TermulPalette.bad : TermulPalette.accent;
    return Container(
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? onColor : Colors.transparent,
        borderRadius: BorderRadius.circular(TermulRadius.radiusPill),
        border: Border.all(color: on ? onColor : (danger ? TermulPalette.badLine : TermulPalette.lineStrong), width: 1.5),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: on ? TermulPalette.onAccent : TermulPalette.inkMuted, shape: BoxShape.circle),
      ),
    );
  }
}
