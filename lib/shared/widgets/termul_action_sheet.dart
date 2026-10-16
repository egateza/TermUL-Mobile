import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'termul_button.dart';
import 'termul_icon.dart';

class SheetAction {
  const SheetAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.danger = false,
    this.primary = false,
  });

  final String label;
  final VoidCallback onSelected;
  final TermulIconName? icon;
  final bool danger;

  /// Tombol utama (isian `accent`); satu per sheet.
  final bool primary;
}

/// Sheet berisi daftar aksi (satu tombol per aksi, penuh lebar). Menutup sheet lalu menjalankan aksinya.
/// Aksi berisiko memakai varian `danger` dan sebaiknya dikonfirmasi lagi oleh pemanggil.
Future<void> showTermulActions(
  BuildContext context, {
  required String title,
  required List<SheetAction> actions,

  /// Penjelasan di bawah judul (teks, banner, dan sejenisnya).
  Widget? child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
      side: BorderSide(color: TermulPalette.line),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TermulSpacing.space9,
          TermulSpacing.space5,
          TermulSpacing.space9,
          TermulSpacing.space9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: TermulPalette.lineStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: TermulSpacing.space7),
            Semantics(
              header: true,
              child: Text(
                title,
                style: TermulText.h2.copyWith(color: TermulPalette.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (child != null) ...[const SizedBox(height: TermulSpacing.space5), child],
            const SizedBox(height: TermulSpacing.space6),
            for (final a in actions) ...[
              TermulButton(
                label: a.label,
                icon: a.icon,
                variant: a.danger
                    ? TermulButtonVariant.danger
                    : (a.primary ? TermulButtonVariant.primary : TermulButtonVariant.secondary),
                size: TermulButtonSize.lg,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  a.onSelected();
                },
              ),
              const SizedBox(height: TermulSpacing.space3),
            ],
          ],
        ),
      ),
    ),
  );
}
