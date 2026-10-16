import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'termul_button.dart';

/// Panel yang naik dari bawah untuk keputusan atau detail. Susunan tetap: pegangan, judul, isi (bisa
/// digulir, tinggi maksimal sekitar 84% layar), tombol. Tombol utama di kanan dan lebih lebar; tombol batal
/// selalu ada. Untuk keputusan berisiko, tampilkan isi yang akan dikirim dan konsekuensinya di [child], dan
/// jadikan pilihan aman sebagai tombol utama.
Future<T?> showTermulSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  required String cancelLabel,
  required String confirmLabel,
  required VoidCallback onConfirm,
  VoidCallback? onCancel,
  bool confirmIsDanger = false,

  /// Pilihan aman (batal) menjadi tombol utama dan konfirmasi menjadi tombol biasa; untuk keputusan berisiko.
  bool cancelIsPrimary = false,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
      side: BorderSide(color: TermulPalette.line),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
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
              child: Text(title, style: TermulText.h2.copyWith(color: TermulPalette.ink)),
            ),
            const SizedBox(height: TermulSpacing.space5),
            Flexible(child: SingleChildScrollView(child: child)),
            const SizedBox(height: TermulSpacing.space8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TermulButton(
                    label: cancelLabel,
                    size: TermulButtonSize.lg,
                    variant: cancelIsPrimary ? TermulButtonVariant.primary : TermulButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onCancel?.call();
                    },
                  ),
                ),
                const SizedBox(width: TermulSpacing.space3),
                Expanded(
                  flex: 3,
                  child: TermulButton(
                    label: confirmLabel,
                    size: TermulButtonSize.lg,
                    variant: confirmIsDanger
                        ? TermulButtonVariant.danger
                        : (cancelIsPrimary ? TermulButtonVariant.secondary : TermulButtonVariant.primary),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
