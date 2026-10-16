import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/app_settings.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_stepper.dart';
import '../terminal/terminal_palette.dart';

/// Layar Pengaturan. Sekarang hanya bagian Terminal (ukuran huruf dan tinggi baris, dengan pratinjau); perubahan
/// langsung berlaku di sesi terminal yang sedang terbuka dan disimpan ke `settings.json`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saveFailed = false;

  /// Langkah ukuran huruf (px) dan tinggi baris (kelipatan).
  static const _fontStep = 1.0;
  static const _lineStep = 0.1;

  /// Menerapkan [change] pada nilai terkini (dibaca saat diketuk, bukan saat layar digambar, supaya ketukan
  /// beruntun tidak memakai nilai usang).
  Future<void> _apply(TerminalSettings Function(TerminalSettings current) change) async {
    try {
      final next = change(ref.read(appSettingsProvider).terminal);
      await ref.read(appSettingsProvider.notifier).update(AppSettings(terminal: next));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  /// Membulatkan ke satu desimal supaya penjumlahan 0,1 tidak menyisakan 1,3000000000000003.
  static double _round1(double v) => (v * 10).round() / 10;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = ref.watch(appSettingsProvider).terminal;
    final isDefault = t == const TerminalSettings();

    TerminalSettings Function(TerminalSettings) fontBy(double d) =>
        (c) => TerminalSettings(
          fontSize: (c.fontSize + d).clamp(TerminalSettings.minFontSize, TerminalSettings.maxFontSize),
          lineHeight: c.lineHeight,
        );
    TerminalSettings Function(TerminalSettings) lineBy(double d) =>
        (c) => TerminalSettings(
          fontSize: c.fontSize,
          lineHeight: _round1(c.lineHeight + d).clamp(TerminalSettings.minLineHeight, TerminalSettings.maxLineHeight),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space3,
                TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Row(
                children: [
                  TermulIconButton(
                    icon: TermulIconName.chevronLeft,
                    label: l.actionBack,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: TermulSpacing.space3),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.settingsTitle, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space5,
                  TermulSpacing.space3,
                  TermulSpacing.space5,
                  TermulSpacing.space8,
                ),
                children: [
                  if (_saveFailed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TermulSpacing.space5),
                      child: TermulBanner(
                        tone: BannerTone.warn,
                        title: l.settingsSaveFailedTitle,
                        child: Text(l.settingsSaveFailedBody),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space3,
                      0,
                      TermulSpacing.space3,
                      TermulSpacing.space3,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.settingsTerminalSection.toUpperCase(),
                        style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: TermulPalette.surface,
                      borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
                      border: Border.all(color: TermulPalette.line),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(TermulRadius.radiusXl - 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(TermulSpacing.space6),
                            child: _Preview(settings: t),
                          ),
                          TermulStepper(
                            label: l.settingsFontSize,
                            valueText: l.settingsFontSizeValue(t.fontSize.round()),
                            decrementLabel: l.settingsFontSmaller,
                            incrementLabel: l.settingsFontLarger,
                            onDecrement: t.fontSize <= TerminalSettings.minFontSize
                                ? null
                                : () => _apply(fontBy(-_fontStep)),
                            onIncrement: t.fontSize >= TerminalSettings.maxFontSize
                                ? null
                                : () => _apply(fontBy(_fontStep)),
                          ),
                          TermulStepper(
                            label: l.settingsLineHeight,
                            valueText: l.settingsLineHeightValue(t.lineHeight.toStringAsFixed(1).replaceAll('.', ',')),
                            decrementLabel: l.settingsLineTighter,
                            incrementLabel: l.settingsLineLooser,
                            onDecrement: t.lineHeight <= TerminalSettings.minLineHeight
                                ? null
                                : () => _apply(lineBy(-_lineStep)),
                            onIncrement: t.lineHeight >= TerminalSettings.maxLineHeight
                                ? null
                                : () => _apply(lineBy(_lineStep)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: TermulSpacing.space5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
                    child: Text(
                      l.settingsTerminalHint,
                      style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                    ),
                  ),
                  const SizedBox(height: TermulSpacing.space5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
                    child: TermulButton(
                      label: l.settingsResetDefaults,
                      onPressed: isDefault ? null : () => _apply((_) => const TerminalSettings()),
                    ),
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

/// Pratinjau dua baris dengan gaya terminal yang sama dengan sesi sungguhan.
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final TerminalSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final base = terminalStyleFor(settings).toTextStyle(color: TermulPalette.terminalInk);
    return Semantics(
      label: l.settingsPreviewLabel,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('settings-preview'),
        width: double.infinity,
        padding: const EdgeInsets.all(TermulSpacing.space5),
        decoration: BoxDecoration(
          color: TermulPalette.groundDeep,
          borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
        ),
        child: Text.rich(
          TextSpan(
            style: base,
            children: const [
              TextSpan(
                text: 'deploy@app-01',
                style: TextStyle(color: TermulPalette.terminalPrompt),
              ),
              TextSpan(text: ':~\$ ls -la\ndrwxr-xr-x 4 deploy deploy'),
            ],
          ),
          maxLines: 2,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}
