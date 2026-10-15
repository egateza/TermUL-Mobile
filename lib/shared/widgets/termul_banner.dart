import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'termul_icon.dart';

enum BannerTone { info, warn, risk, ice, ok }

/// Pesan sebaris berwarna nada untuk menjelaskan keadaan atau risiko. `risk` dan `warn` diumumkan sebagai
/// peringatan. Konfirmasi sesaat memakai `showTermulToast`, bukan banner.
class TermulBanner extends StatelessWidget {
  const TermulBanner({super.key, required this.tone, required this.child, this.title, this.icon, this.action});

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
        padding: const EdgeInsets.all(TermulSpacing.space6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
          border: Border.all(color: line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TermulIcon(icon ?? defaultIcon, size: 20, color: accent),
            const SizedBox(width: TermulSpacing.space5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TermulSpacing.space1),
                      child: Text(title!, style: TermulText.title.copyWith(color: accent)),
                    ),
                  DefaultTextStyle.merge(
                    style: TermulText.bodySm.copyWith(color: body),
                    child: child,
                  ),
                  if (action != null)
                    Padding(
                      padding: const EdgeInsets.only(top: TermulSpacing.space5),
                      child: action,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
