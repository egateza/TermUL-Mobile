import 'package:flutter/material.dart';

import '../../core/models/host_profile.dart';
import '../../core/models/known_host.dart';
import '../../core/ssh/ssh_connector.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';

/// Layar verifikasi host key (prototipe `HostKey.dc.html`). Dua varian: host baru dan host key berubah.
/// Pada varian berubah, pilihan aman ("Batalkan koneksi") jadi tombol utama dan penggantian key baru aktif
/// setelah pengguna menyatakan sudah memastikan perubahan itu sah.
class HostKeyPrompt extends StatefulWidget {
  const HostKeyPrompt({super.key, required this.profile, required this.challenge, required this.onChoice});

  final HostProfile profile;
  final HostKeyChallenge challenge;
  final ValueChanged<HostKeyChoice> onChoice;

  @override
  State<HostKeyPrompt> createState() => _HostKeyPromptState();
}

class _HostKeyPromptState extends State<HostKeyPrompt> {
  bool _acknowledged = false;

  bool get _changed => widget.challenge.verdict == HostKeyVerdict.changed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.challenge;
    final p = widget.profile;
    final tone = _changed ? TermulPalette.bad : TermulPalette.accent;
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
                    onPressed: () => widget.onChoice(HostKeyChoice.reject),
                  ),
                  const SizedBox(width: TermulSpacing.space3),
                  Expanded(
                    child: Text(
                      '${p.name} · ${p.username}@${c.host}:${c.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space8,
                  TermulSpacing.space5,
                  TermulSpacing.space8,
                  TermulSpacing.space9,
                ),
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _changed ? TermulPalette.badBg : TermulPalette.accentBg,
                      borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
                      border: Border.all(color: _changed ? TermulPalette.badLine : TermulPalette.accentLine),
                    ),
                    child: TermulIcon(_changed ? TermulIconName.warning : TermulIconName.shield, size: 28, color: tone),
                  ),
                  const SizedBox(height: TermulSpacing.space7),
                  Semantics(
                    header: true,
                    child: Text(
                      _changed ? l.hostKeyChangedTitle : l.hostKeyNewTitle,
                      style: TermulText.h1.copyWith(color: _changed ? TermulPalette.bad : TermulPalette.ink),
                    ),
                  ),
                  const SizedBox(height: TermulSpacing.space3),
                  Text(
                    _changed ? l.hostKeyChangedBody(p.name) : l.hostKeyNewBody(p.name),
                    style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
                  ),
                  const SizedBox(height: TermulSpacing.space8),
                  _Field(label: l.hostKeyAlgorithm, value: c.type),
                  const SizedBox(height: TermulSpacing.space5),
                  if (_changed) ...[
                    _Field(
                      label: l.hostKeyStored,
                      value: c.storedFingerprints.join('\n'),
                      bad: false,
                      selectable: true,
                    ),
                    const SizedBox(height: TermulSpacing.space5),
                    _Field(label: l.hostKeyReceived, value: c.fingerprint, bad: true, selectable: true),
                  ] else ...[
                    _Field(label: l.hostKeyFingerprint, value: c.fingerprint, selectable: true),
                    const SizedBox(height: TermulSpacing.space7),
                    Text(l.hostKeyNewNote, style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted)),
                  ],
                  if (_changed) ...[
                    const SizedBox(height: TermulSpacing.space7),
                    _AckRow(
                      label: l.hostKeyAck,
                      checked: _acknowledged,
                      onChanged: (v) => setState(() => _acknowledged = v),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space8,
                TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space8,
              ),
              decoration: const BoxDecoration(
                color: TermulPalette.ground,
                border: Border(top: BorderSide(color: TermulPalette.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _changed ? _changedActions(l) : _newActions(l),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _newActions(AppLocalizations l) => [
    TermulButton(
      label: l.hostKeyTrustAndConnect,
      variant: TermulButtonVariant.primary,
      size: TermulButtonSize.lg,
      onPressed: () => widget.onChoice(HostKeyChoice.trustAndSave),
    ),
    const SizedBox(height: TermulSpacing.space3),
    TermulButton(label: l.hostKeyConnectOnce, onPressed: () => widget.onChoice(HostKeyChoice.connectOnce)),
    const SizedBox(height: TermulSpacing.space3),
    TermulButton(
      label: l.actionAbort,
      variant: TermulButtonVariant.ghost,
      onPressed: () => widget.onChoice(HostKeyChoice.reject),
    ),
  ];

  List<Widget> _changedActions(AppLocalizations l) => [
    TermulButton(
      label: l.hostKeyCancelConnection,
      variant: TermulButtonVariant.primary,
      size: TermulButtonSize.lg,
      onPressed: () => widget.onChoice(HostKeyChoice.reject),
    ),
    const SizedBox(height: TermulSpacing.space3),
    TermulButton(
      label: l.hostKeyReplaceAndConnect,
      variant: TermulButtonVariant.danger,
      onPressed: _acknowledged ? () => widget.onChoice(HostKeyChoice.replaceAndTrust) : null,
    ),
  ];
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.bad, this.selectable = false});

  final String label;
  final String value;

  /// null = netral; true = nada bahaya (sidik jari yang baru diterima); false = tersimpan, tetap netral.
  final bool? bad;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final danger = bad == true;
    final style = TermulText.terminalSm.copyWith(color: danger ? TermulPalette.badInk : TermulPalette.ink);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(TermulSpacing.space6),
        decoration: BoxDecoration(
          color: danger ? TermulPalette.badBg : TermulPalette.surface,
          borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
          border: Border.all(color: danger ? TermulPalette.badLine : TermulPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TermulText.caption.copyWith(color: danger ? TermulPalette.bad : TermulPalette.inkMuted)),
            const SizedBox(height: TermulSpacing.space2),
            selectable ? SelectableText(value, style: style) : Text(value, style: style),
          ],
        ),
      ),
    );
  }
}

/// Baris persetujuan: seluruh baris adalah target sentuh (minimal 56 px) dengan kotak centang kiri.
class _AckRow extends StatelessWidget {
  const _AckRow({required this.label, required this.checked, required this.onChanged});

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: () => onChanged(!checked),
      semanticLabel: label,
      toggled: checked,
      minHeight: TermulSize.rowMin,
      builder: (context, pressed) => _RowBox(
        pressed: pressed,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checked ? TermulPalette.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(TermulRadius.radiusSm),
                border: Border.all(color: checked ? TermulPalette.accent : TermulPalette.lineStrong, width: 2),
              ),
              child: checked ? const TermulIcon(TermulIconName.check, size: 18, color: TermulPalette.onAccent) : null,
            ),
            const SizedBox(width: TermulSpacing.space5),
            Expanded(
              child: Text(label, style: TermulText.body.copyWith(color: TermulPalette.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak berisi tepi 1 px untuk baris yang bisa ditekan (tanpa membuat [TermulCard] bersarang di [Pressable]).
class _RowBox extends StatelessWidget {
  const _RowBox({required this.child, this.pressed = false});

  final Widget child;
  final bool pressed;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: TermulSize.rowMin),
    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space4),
    decoration: BoxDecoration(
      color: TermulPalette.surface,
      borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
      border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
    ),
    child: child,
  );
}
