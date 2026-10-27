import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_icon.dart';

/// Pilihan di menu tekan-tahan terminal. Saklar "Layar tetap menyala" tidak menutup menu, jadi tidak ada di sini.
enum TerminalMenuAction { select, copyAll, paste, snippets, saveTranscript, shareTranscript, clear }

/// Menu tekan-tahan terminal (prototipe `TerminalHoldMenu`): sheet "Terminal" dengan empat ubin (Pilih teks, Salin
/// semua, Tempel, Snippet), pratinjau papan klip, lalu Simpan transkrip, Bagikan transkrip, saklar Layar tetap
/// menyala, dan Bersihkan layar. Hasilnya pilihan yang diketuk, atau null bila ditutup.
///
/// [clipText] null atau kosong: Tempel nonaktif dan pratinjau tidak tampil. [canPaste] false (sambungan putus) juga
/// menonaktifkan Tempel. [canSnippets] false menyembunyikan ubin Snippet. [canClear] false (program layar penuh
/// seperti `vim` sedang berjalan) menonaktifkan Bersihkan layar.
Future<TerminalMenuAction?> showTerminalHoldMenu(
  BuildContext context, {
  required String target,
  required int lineCount,
  required bool keepScreenOn,
  required ValueChanged<bool> onKeepScreenOn,
  String? clipText,
  bool canPaste = true,
  bool canSnippets = true,
  bool canClear = true,
}) {
  return showModalBottomSheet<TerminalMenuAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
      side: BorderSide(color: TermulPalette.line),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
    builder: (sheetContext) => _HoldMenu(
      target: target,
      lineCount: lineCount,
      keepScreenOn: keepScreenOn,
      onKeepScreenOn: onKeepScreenOn,
      clipText: clipText == null || clipText.isEmpty ? null : clipText,
      canPaste: canPaste,
      canSnippets: canSnippets,
      canClear: canClear,
    ),
  );
}

class _HoldMenu extends StatefulWidget {
  const _HoldMenu({
    required this.target,
    required this.lineCount,
    required this.keepScreenOn,
    required this.onKeepScreenOn,
    required this.clipText,
    required this.canPaste,
    required this.canSnippets,
    required this.canClear,
  });

  final String target;
  final int lineCount;
  final bool keepScreenOn;
  final ValueChanged<bool> onKeepScreenOn;
  final String? clipText;
  final bool canPaste;
  final bool canSnippets;
  final bool canClear;

  @override
  State<_HoldMenu> createState() => _HoldMenuState();
}

class _HoldMenuState extends State<_HoldMenu> {
  late bool _keepOn = widget.keepScreenOn;

  void _pick(TerminalMenuAction a) => Navigator.of(context).pop(a);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final clip = widget.canPaste ? widget.clipText : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TermulSpacing.space7,
          TermulSpacing.space5,
          TermulSpacing.space7,
          TermulSpacing.space8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TermulSpacing.space4,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: TermulPalette.lineStrong, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: TermulSpacing.space1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(l.terminalMenuTitle, style: TermulText.title.copyWith(color: TermulPalette.ink)),
                        ),
                        Text(
                          l.terminalMenuTarget(widget.target, widget.lineCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    semanticLabel: l.actionClose,
                    minWidth: TermulSize.tapMin,
                    onPressed: () => Navigator.of(context).pop(),
                    builder: (context, pressed) => SizedBox(
                      width: TermulSize.tapMin,
                      height: TermulSize.tapMin,
                      child: Center(
                        child: TermulIcon(
                          TermulIconName.close,
                          color: pressed ? TermulPalette.accent : TermulPalette.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                spacing: TermulSpacing.space2,
                children: [
                  Expanded(
                    child: _Tile(
                      label: l.terminalMenuSelect,
                      icon: TermulIconName.textSelect,
                      onPressed: () => _pick(TerminalMenuAction.select),
                    ),
                  ),
                  Expanded(
                    child: _Tile(
                      label: l.terminalMenuCopyAll,
                      icon: TermulIconName.copyText,
                      onPressed: () => _pick(TerminalMenuAction.copyAll),
                    ),
                  ),
                  Expanded(
                    child: _Tile(
                      label: l.terminalMenuPaste,
                      semanticLabel: clip == null ? l.terminalMenuPasteEmpty : null,
                      icon: TermulIconName.paste,
                      onPressed: clip == null ? null : () => _pick(TerminalMenuAction.paste),
                    ),
                  ),
                  if (widget.canSnippets)
                    Expanded(
                      child: _Tile(
                        label: l.terminalMenuSnippets,
                        icon: TermulIconName.snippets,
                        iconColor: TermulPalette.accent,
                        onPressed: () => _pick(TerminalMenuAction.snippets),
                      ),
                    ),
                ],
              ),
              if (clip != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space1),
                  child: Row(
                    spacing: TermulSpacing.space3,
                    children: [
                      Text(l.terminalMenuClipboard, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                      Expanded(
                        child: Text(
                          clip.replaceAll(RegExp(r'\s+'), ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TermulText.terminalSm.copyWith(color: TermulPalette.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
                  border: Border.all(color: TermulPalette.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Row(
                      icon: TermulIconName.download,
                      label: l.terminalMenuSave,
                      description: l.terminalMenuSaveBody,
                      onPressed: () => _pick(TerminalMenuAction.saveTranscript),
                    ),
                    _Row(
                      icon: TermulIconName.share,
                      label: l.terminalMenuShare,
                      description: l.terminalMenuShareBody,
                      divider: true,
                      onPressed: () => _pick(TerminalMenuAction.shareTranscript),
                    ),
                    _Row(
                      icon: TermulIconName.sun,
                      label: l.terminalMenuKeepOn,
                      description: _keepOn ? l.terminalMenuKeepOnOn : l.terminalMenuKeepOnOff,
                      divider: true,
                      toggled: _keepOn,
                      onPressed: () {
                        setState(() => _keepOn = !_keepOn);
                        widget.onKeepScreenOn(_keepOn);
                      },
                    ),
                    _Row(
                      icon: TermulIconName.eraser,
                      label: l.terminalMenuClear,
                      description: widget.canClear ? l.terminalMenuClearBody : l.terminalMenuClearUnavailable,
                      divider: true,
                      onPressed: widget.canClear ? () => _pick(TerminalMenuAction.clear) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ubin 64 dp bergaya tombol bilah seleksi: ikon di atas label. Nonaktif: opasitas 0,4.
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.icon, required this.onPressed, this.iconColor, this.semanticLabel});

  final String label;
  final TermulIconName icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Pressable(
        semanticLabel: semanticLabel ?? label,
        onPressed: onPressed,
        minHeight: TermulSize.rowComfy,
        builder: (context, pressed) => Container(
          // Lebar penuh: keempat ubin sama lebar, tidak mengikuti panjang label.
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: TermulSize.rowComfy),
          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space1, vertical: TermulSpacing.space3),
          decoration: BoxDecoration(
            color: pressed ? TermulPalette.accentBg : TermulPalette.surfaceRaised,
            borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
            border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: TermulSpacing.space1,
            children: [
              TermulIcon(icon, color: iconColor ?? TermulPalette.ink),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TermulText.caption.copyWith(color: TermulPalette.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris daftar 56 dp (64 dp untuk saklar) dengan ikon, label, dan keterangan; [toggled] non-null menampilkan
/// sakelar 48x28 seperti `SwitchRow`.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    this.divider = false,
    this.toggled,
  });

  final TermulIconName icon;
  final String label;
  final String description;
  final VoidCallback? onPressed;
  final bool divider;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final min = toggled == null ? TermulSize.rowMin : TermulSize.rowComfy;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Pressable(
        semanticLabel: '$label. $description',
        toggled: toggled,
        radius: 0,
        minHeight: min,
        onPressed: onPressed,
        builder: (context, pressed) => Container(
          constraints: BoxConstraints(minHeight: min),
          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space3),
          decoration: BoxDecoration(
            color: pressed ? TermulPalette.accentBg : Colors.transparent,
            border: divider ? const Border(top: BorderSide(color: TermulPalette.line)) : null,
          ),
          child: Row(
            spacing: TermulSpacing.space5,
            children: [
              TermulIcon(icon, color: TermulPalette.inkMuted),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(label, style: TermulText.body.copyWith(color: TermulPalette.ink)),
                    Text(description, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                  ],
                ),
              ),
              if (toggled != null) _Track(on: toggled!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? TermulPalette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(TermulRadius.radiusPill),
        border: Border.all(color: on ? TermulPalette.accent : TermulPalette.lineStrong, width: 1.5),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: on ? TermulPalette.onAccent : TermulPalette.inkMuted, shape: BoxShape.circle),
      ),
    );
  }
}
