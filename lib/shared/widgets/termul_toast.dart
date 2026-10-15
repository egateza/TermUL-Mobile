import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'termul_icon.dart';

/// Konfirmasi sesaat satu baris (sekitar 2 detik), tanpa tombol. Sebut hasil dan jumlahnya
/// ("Disalin · 27 karakter"). Tidak menutup bar bawah atau tombol aksi bila [bottomOffset] diisi.
void showTermulToast(
  BuildContext context,
  String message, {
  TermulIconName icon = TermulIconName.check,
  double bottomOffset = 0,
}) {
  showTermulToastOn(ScaffoldMessenger.of(context), message, icon: icon, bottomOffset: bottomOffset);
}

/// Seperti [showTermulToast] tetapi memakai messenger yang sudah diambil sebelumnya, supaya aman dipakai
/// sesudah `await` tanpa menyentuh `BuildContext`.
void showTermulToastOn(
  ScaffoldMessengerState messenger,
  String message, {
  TermulIconName icon = TermulIconName.check,
  double bottomOffset = 0,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      margin: EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space8, TermulSpacing.space8 + bottomOffset),
      content: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            TermulIcon(icon, size: 18, color: TermulPalette.ok),
            const SizedBox(width: TermulSpacing.space4),
            Expanded(child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    ),
  );
}
