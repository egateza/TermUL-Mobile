import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';

/// Chip filter: tombol 44 px, satu terpilih dalam satu baris yang bisa digulir mendatar.
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      radius: TermulRadius.radiusPill,
      toggled: selected,
      builder: (context, pressed) {
        final on = selected || pressed;
        return Container(
          constraints: const BoxConstraints(minHeight: TermulSize.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? TermulPalette.accent : TermulPalette.surface,
            borderRadius: BorderRadius.circular(TermulRadius.radiusPill),
            border: Border.all(
              color: on ? TermulPalette.accent : TermulPalette.lineStrong,
            ),
          ),
          child: Text(
            label,
            style: TermulText.label.copyWith(
              color: on ? TermulPalette.onAccent : TermulPalette.inkSoft,
            ),
          ),
        );
      },
    );
  }
}

enum TagTone { neutral, accent, bad, ok, ice }

/// Tag statis berisi kata (bukan hanya warna); tag berisiko berbunyi "berisiko".
class TermulTag extends StatelessWidget {
  const TermulTag(this.label, {super.key, this.tone = TagTone.neutral});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, line, fg) = switch (tone) {
      TagTone.neutral => (
        TermulPalette.surfaceRaised,
        TermulPalette.line,
        TermulPalette.inkSoft,
      ),
      TagTone.accent => (
        TermulPalette.accentBg,
        TermulPalette.accentLine,
        TermulPalette.accent,
      ),
      TagTone.bad => (
        TermulPalette.badBg,
        TermulPalette.badLine,
        TermulPalette.bad,
      ),
      TagTone.ok => (
        TermulPalette.okBg,
        TermulPalette.okLine,
        TermulPalette.ok,
      ),
      TagTone.ice => (
        TermulPalette.iceBg,
        TermulPalette.iceLine,
        TermulPalette.ice,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermulSpacing.space3,
        vertical: TermulSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
        border: Border.all(color: line),
      ),
      child: Text(
        label,
        style: TermulText.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
