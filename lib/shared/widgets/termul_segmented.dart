import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Kontrol segmen untuk memilih satu dari dua sampai empat opsi yang selalu terlihat. Setiap opsi minimal
/// 44 px dan berbagi lebar sama; opsi terpilih berisi `accent` dengan teks `on-accent`. Lebih dari empat opsi:
/// pakai daftar.
class TermulSegmented<T> extends StatelessWidget {
  const TermulSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
  }) : assert(options.length >= 2 && options.length <= 4, 'Segmented untuk 2 sampai 4 opsi');

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Nama kelompok untuk pembaca layar.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: TermulPalette.surface,
          borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
          border: Border.all(color: TermulPalette.lineStrong),
        ),
        child: Row(
          children: [
            for (final o in options)
              Expanded(
                child: Pressable(
                  onPressed: () => onChanged(o.value),
                  radius: TermulRadius.radiusSm,
                  toggled: o.value == value,
                  builder: (context, pressed) {
                    final on = o.value == value || pressed;
                    return Container(
                      constraints: const BoxConstraints(minHeight: TermulSize.tapMin - 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? TermulPalette.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(TermulRadius.radiusSm),
                      ),
                      child: Text(
                        o.label,
                        style: TermulText.label.copyWith(color: on ? TermulPalette.onAccent : TermulPalette.inkSoft),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
