import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/flame.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';

/// Sheet "Cara kerja streak" (prototipe 8, tombol bantuan): aturan hari, padam, beku, hangus, tautan ke Pengaturan,
/// dan tiga contoh absen dengan api kecil dan deret titik hari.
Future<void> showStreakHelp(BuildContext context, {required VoidCallback onOpenSettings}) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius2xl)),
      side: BorderSide(color: TermulPalette.lineStrong),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
    builder: (sheetContext) {
      final body = TermulText.bodySm.copyWith(color: TermulPalette.inkSoft, fontSize: 13.5, height: 1.5);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(TermulSpacing.space7, TermulSpacing.space3, TermulSpacing.space3, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.streakHelpTitle,
                        style: TermulText.title.copyWith(
                          color: TermulPalette.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  TermulIconButton(
                    icon: TermulIconName.close,
                    label: l.actionClose,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space7,
                  TermulSpacing.space1,
                  TermulSpacing.space7,
                  TermulSpacing.space8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TermulSpacing.space5,
                  children: [
                    Text(l.streakHelp1, style: body),
                    Text(l.streakHelp2, style: body),
                    Text(l.streakHelp3, style: body),
                    Pressable(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onOpenSettings();
                      },
                      semanticLabel: l.streakHelpSettings,
                      builder: (context, pressed) => Container(
                        constraints: const BoxConstraints(minHeight: TermulSize.tapMin),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l.streakHelpSettings,
                          style: TermulText.body.copyWith(
                            color: TermulPalette.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(top: TermulSpacing.space5),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: TermulPalette.line)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: TermulSpacing.space5,
                        children: [
                          Text(
                            l.streakHelpExamples,
                            style: body.copyWith(color: TermulPalette.ink, fontWeight: FontWeight.w600),
                          ),
                          _Example(
                            mode: FlameMode.gray,
                            need: 5,
                            title: l.streakExampleGrayTitle,
                            text: l.streakExampleGrayText,
                            on: 5,
                            off: 1,
                            tone: TermulPalette.chipGray,
                          ),
                          _Example(
                            mode: FlameMode.frozen,
                            need: 7,
                            title: l.streakExampleFrozenTitle,
                            text: l.streakExampleFrozenText,
                            on: 4,
                            off: 5,
                            tone: TermulPalette.chipIce,
                          ),
                          _Example(
                            mode: FlameMode.reset,
                            need: 5,
                            title: l.streakExampleExpiredTitle,
                            text: l.streakExampleExpiredText,
                            on: 3,
                            off: 11,
                            tone: TermulPalette.chipGray,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Example extends StatelessWidget {
  const _Example({
    required this.mode,
    required this.need,
    required this.title,
    required this.text,
    required this.on,
    required this.off,
    required this.tone,
  });

  final FlameMode mode;
  final int need;
  final String title;
  final String text;
  final int on;
  final int off;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: TermulSpacing.space5,
      children: [
        SizedBox(
          width: 36,
          child: Center(
            child: Flame(count: 47, mode: mode, size: 22, need: need),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TermulSpacing.space1,
            children: [
              Text(
                title,
                style: TermulText.bodySm.copyWith(color: TermulPalette.ink, fontWeight: FontWeight.w500),
              ),
              ExcludeSemantics(
                child: Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (var i = 0; i < on; i++) _dot(TermulPalette.accent, filled: true),
                    for (var i = 0; i < off; i++) _dot(tone, filled: false),
                  ],
                ),
              ),
              Text(text, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _dot(Color color, {required bool filled}) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : Colors.transparent,
      border: Border.all(color: color, width: filled ? 0 : 1.5),
    ),
  );
}
