import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'termul_icon.dart';

enum BannerTone { info, warn, risk, ice, ok }

/// Pesan sebaris berwarna nada untuk menjelaskan keadaan atau risiko. `risk` dan `warn` diumumkan sebagai
/// peringatan. Konfirmasi sesaat memakai `showTermulToast`, bukan banner.
class TermulBanner extends StatelessWidget {
  const TermulBanner({
    super.key,
    required this.tone,
    required this.child,
    this.title,
    this.icon,
    this.action,
    this.compact = false,
    this.showBody = true,
  });

  /// Susunan mendatar untuk layar pendek (landscape): tombol di kanan teks, padding lebih kecil.
  final bool compact;

  /// false: hanya judul (dan tombol); dipakai saat keyboard menyisakan tinggi yang sangat sempit.
  final bool showBody;
  final BannerTone tone;
  final Widget child;
  final String? title;
  final TermulIconName? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, line, accent, body, defaultIcon) = switch (tone) {
      BannerTone.info => (
        TermulPalette.surfaceRaised,
        TermulPalette.line,
        TermulPalette.info,
        TermulPalette.inkSoft,
        TermulIconName.shield,
      ),
      BannerTone.warn => (
        TermulPalette.accentBg,
        TermulPalette.accentLine,
        TermulPalette.accent,
        TermulPalette.inkSoft,
        TermulIconName.warning,
      ),
      BannerTone.risk => (
        TermulPalette.badBg,
        TermulPalette.badLine,
        TermulPalette.bad,
        TermulPalette.badInk,
        TermulIconName.warning,
      ),
      BannerTone.ice => (
        TermulPalette.iceBg,
        TermulPalette.iceLine,
        TermulPalette.ice,
        TermulPalette.inkSoft,
        TermulIconName.shield,
      ),
      BannerTone.ok => (
        TermulPalette.okBg,
        TermulPalette.okLine,
        TermulPalette.ok,
        TermulPalette.inkSoft,
        TermulIconName.check,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: tone == BannerTone.risk || tone == BannerTone.warn,
      child: Container(
        padding: !showBody
            ? const EdgeInsets.symmetric(horizontal: TermulSpacing.space4, vertical: TermulSpacing.space1)
            : EdgeInsets.all(compact ? TermulSpacing.space4 : TermulSpacing.space6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
          border: Border.all(color: line),
        ),
        child: Row(
          crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            TermulIcon(icon ?? defaultIcon, size: 20, color: accent),
            const SizedBox(width: TermulSpacing.space5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: showBody ? TermulSpacing.space1 : 0),
                      child: Text(title!, style: TermulText.title.copyWith(color: accent)),
                    ),
                  if (showBody || title == null)
                    DefaultTextStyle.merge(
                      style: TermulText.bodySm.copyWith(color: body),
                      child: child,
                    ),
                  if (action != null && !compact)
                    Padding(
                      padding: const EdgeInsets.only(top: TermulSpacing.space5),
                      child: action,
                    ),
                ],
              ),
            ),
            // Layar pendek: tombol di kanan teks supaya banner tidak setinggi tiga tingkat.
            if (action != null && compact) ...[const SizedBox(width: TermulSpacing.space5), action!],
          ],
        ),
      ),
    );
  }
}
