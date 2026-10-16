import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/key_button.dart';
import 'terminal_session.dart';

/// Baris tombol khusus di atas keyboard: Esc, Tab, Ctrl dan Alt (sekali pakai), ^C, ^D, panah, Home, End, PgUp,
/// PgDn, simbol, dan Fn yang menukar baris dengan F1 sampai F12. Satu baris yang bisa digeser; [compact]
/// (36 dp) hanya untuk landscape ringkas. Tombol tidak mengambil fokus sehingga keyboard sistem tetap terbuka.
class QuickKeyBar extends StatefulWidget {
  const QuickKeyBar({super.key, required this.session, this.compact = false, this.onPaste});

  final TerminalSession session;
  final bool compact;

  /// Dipanggil saat tombol Tempel ditekan (membaca papan klip dan meminta konfirmasi bila perlu).
  final VoidCallback? onPaste;

  @override
  State<QuickKeyBar> createState() => _QuickKeyBarState();
}

class _QuickKeyBarState extends State<QuickKeyBar> {
  bool _functionRow = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = widget.session;
    final height = widget.compact ? 36.0 : TermulSize.tapMin;
    return Semantics(
      container: true,
      label: l.quickKeysLabel,
      child: Container(
        height: height + TermulSpacing.space3 * 2,
        decoration: const BoxDecoration(
          color: TermulPalette.ground,
          border: Border(top: BorderSide(color: TermulPalette.line)),
        ),
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3, vertical: TermulSpacing.space3),
            children: _functionRow ? _functionKeys(l) : _mainKeys(l, s),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(width: TermulSpacing.space2);

  Widget _key(String label, String aria, VoidCallback onPressed, {bool pressed = false, double width = 56}) => Padding(
    padding: const EdgeInsets.only(right: TermulSpacing.space2),
    child: KeyButton(
      label: label,
      ariaLabel: aria,
      onPressed: onPressed,
      pressed: pressed,
      compact: widget.compact,
      width: width,
    ),
  );

  List<Widget> _mainKeys(AppLocalizations l, TerminalSession s) => [
    _key('Esc', l.keyEsc, () => s.pressKey(TerminalKey.escape)),
    _key('Tab', l.keyTab, () => s.pressKey(TerminalKey.tab)),
    _key('Ctrl', l.keyCtrl, s.toggleCtrl, pressed: s.ctrl),
    _key('Alt', l.keyAlt, s.toggleAlt, pressed: s.alt),
    _key('Fn', l.keyFunctionToggle, () => setState(() => _functionRow = true)),
    if (widget.onPaste != null) _key(l.keyPaste, l.keyPasteAria, widget.onPaste!, width: 72),
    _key('^C', l.keyCtrlC, () => s.pressControl('c')),
    _key('^D', l.keyCtrlD, () => s.pressControl('d')),
    _key('←', l.keyArrowLeft, () => s.pressKey(TerminalKey.arrowLeft)),
    _key('↓', l.keyArrowDown, () => s.pressKey(TerminalKey.arrowDown)),
    _key('↑', l.keyArrowUp, () => s.pressKey(TerminalKey.arrowUp)),
    _key('→', l.keyArrowRight, () => s.pressKey(TerminalKey.arrowRight)),
    _key('Home', l.keyHome, () => s.pressKey(TerminalKey.home)),
    _key('End', l.keyEnd, () => s.pressKey(TerminalKey.end)),
    _key('PgUp', l.keyPageUp, () => s.pressKey(TerminalKey.pageUp)),
    _key('PgDn', l.keyPageDown, () => s.pressKey(TerminalKey.pageDown)),
    _key('|', l.keyPipe, () => s.pressText('|')),
    _key('~', l.keyTilde, () => s.pressText('~')),
    _key('/', l.keySlash, () => s.pressText('/')),
    _key('-', l.keyDash, () => s.pressText('-')),
  ];

  static const _fKeys = [
    TerminalKey.f1,
    TerminalKey.f2,
    TerminalKey.f3,
    TerminalKey.f4,
    TerminalKey.f5,
    TerminalKey.f6,
    TerminalKey.f7,
    TerminalKey.f8,
    TerminalKey.f9,
    TerminalKey.f10,
    TerminalKey.f11,
    TerminalKey.f12,
  ];

  List<Widget> _functionKeys(AppLocalizations l) {
    final s = widget.session;
    return [
      _key('ABC', l.keyFunctionBack, () => setState(() => _functionRow = false)),
      for (var i = 0; i < _fKeys.length; i++) _key('F${i + 1}', l.keyFunction(i + 1), () => s.pressKey(_fKeys[i])),
      _gap(),
    ];
  }
}
