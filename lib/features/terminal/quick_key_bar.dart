import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/quick_key_settings.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/key_button.dart';
import 'quick_key_catalog.dart';
import 'terminal_session.dart';

/// Bilah tombol cepat di atas keyboard. Di potret dua baris: grid tujuh kolom selebar sama yang terlihat tanpa
/// digeser; kolom berikutnya digeser mendatar, kedua baris bersama supaya kolom tetap sejajar. Isi baris dari [layout] (Pengaturan > Tombol cepat). Fn menukar
/// kedua baris dengan F1 sampai F12. [compact] (landscape ringkas, 36 dp) menggabungkan kedua baris menjadi satu.
/// Tombol tidak mengambil fokus sehingga keyboard sistem tetap terbuka.
class QuickKeyBar extends StatefulWidget {
  const QuickKeyBar({
    super.key,
    required this.session,
    this.layout = const QuickKeySettings(),
    this.compact = false,
    this.onPaste,
  });

  final TerminalSession session;
  final QuickKeySettings layout;
  final bool compact;

  /// Dipanggil saat tombol Tempel ditekan. Kosong = Tempel nonaktif (tetap di tempatnya supaya grid tidak bergeser).
  final VoidCallback? onPaste;

  /// Kolom yang terlihat tanpa digeser di potret.
  static const visibleColumns = 7;

  @override
  State<QuickKeyBar> createState() => _QuickKeyBarState();
}

class _QuickKeyBarState extends State<QuickKeyBar> {
  bool _functionRow = false;

  /// Dipakai bersama bilah potret dan ringkas; kembali ke kolom pertama saat Fn atau ABC ditekan, supaya ABC dan F1
  /// langsung terlihat.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setFunctionRow(bool on) {
    setState(() => _functionRow = on);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Lebar tombol untuk baris yang sedang dibangun (grid selebar sama, atau 56 dp di mode ringkas).
  double _keyWidth = 56;

  static const _gap = TermulSpacing.space2;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = widget.session;
    final keyHeight = widget.compact ? 36.0 : TermulSize.tapMin;
    return Semantics(
      container: true,
      label: l.quickKeysLabel,
      child: Container(
        padding: const EdgeInsets.all(TermulSpacing.space3),
        decoration: const BoxDecoration(
          color: TermulPalette.ground,
          border: Border(top: BorderSide(color: TermulPalette.line)),
        ),
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            if (widget.compact) {
              // Semua tombol dibangun (paling banyak 20), supaya tombol di luar layar tetap bisa dicapai.
              return SizedBox(
                height: keyHeight,
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [for (final k in _compactRow(l)) _cell(k)]),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                const cols = QuickKeyBar.visibleColumns;
                final width = math
                    .max(TermulSize.tapMin, (constraints.maxWidth - _gap * (cols - 1)) / cols)
                    .floorToDouble();
                _keyWidth = width;
                return SingleChildScrollView(
                  key: const ValueKey('quick-keys-scroll'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [for (final k in _row(l, 0)) _cell(k)]),
                      const SizedBox(height: _gap),
                      Row(children: [for (final k in _row(l, 1)) _cell(k)]),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Satu sel grid: tombol, atau sel kosong (null) supaya kolom tetap sejajar.
  Widget _cell(Widget? key) => Padding(
    padding: const EdgeInsets.only(right: _gap),
    child: key ?? SizedBox(width: _keyWidth, height: widget.compact ? 36 : TermulSize.tapMin),
  );

  List<Widget?> _compactRow(AppLocalizations l) {
    _keyWidth = 56;
    return [..._row(l, 0), ..._row(l, 1)];
  }

  List<Widget?> _row(AppLocalizations l, int index) {
    if (_functionRow) {
      if (widget.compact) {
        return index == 0 ? [_abc(l), for (var i = 0; i < 12; i++) _fKey(l, i)] : const [];
      }
      // ABC dan F1 sampai F6 di atas; sel kosong di bawah ABC supaya F1 sejajar dengan F7.
      return index == 0
          ? [_abc(l), for (var i = 0; i < 6; i++) _fKey(l, i)]
          : [null, for (var i = 6; i < 12; i++) _fKey(l, i)];
    }
    return [
      for (final id in widget.layout.row(index))
        if (quickKeyById(id) case final def?) _keyFor(l, def),
    ];
  }

  Widget _button(String label, String aria, VoidCallback? onPressed, {bool pressed = false}) => KeyButton(
    label: label,
    ariaLabel: aria,
    onPressed: onPressed,
    pressed: pressed,
    compact: widget.compact,
    width: _keyWidth,
  );

  Widget _abc(AppLocalizations l) => _button('ABC', l.keyFunctionBack, () => _setFunctionRow(false));

  Widget _fKey(AppLocalizations l, int i) =>
      _button('F${i + 1}', l.keyFunction(i + 1), () => widget.session.pressKey(_fKeys[i]));

  Widget _keyFor(AppLocalizations l, QuickKeyDef def) {
    final s = widget.session;
    final label = def.label(l);
    final aria = def.aria(l);
    final letter = def.controlLetter;
    if (letter != null) return _button(label, aria, () => s.pressControl(letter));
    return switch (def.id) {
      'ctrl' => _button(label, aria, s.toggleCtrl, pressed: s.ctrl),
      'alt' => _button(label, aria, s.toggleAlt, pressed: s.alt),
      'fn' => _button(label, aria, () => _setFunctionRow(true)),
      'paste' => _button(label, aria, widget.onPaste),
      'pipe' || 'tilde' || 'slash' || 'dash' => _button(label, aria, () => s.pressText(label)),
      _ => _button(label, aria, () => s.pressKey(_terminalKeys[def.id]!)),
    };
  }

  static const _terminalKeys = {
    'esc': TerminalKey.escape,
    'tab': TerminalKey.tab,
    'bksp': TerminalKey.backspace,
    'enter': TerminalKey.enter,
    'up': TerminalKey.arrowUp,
    'down': TerminalKey.arrowDown,
    'left': TerminalKey.arrowLeft,
    'right': TerminalKey.arrowRight,
    'home': TerminalKey.home,
    'end': TerminalKey.end,
    'pgup': TerminalKey.pageUp,
    'pgdn': TerminalKey.pageDown,
    'ins': TerminalKey.insert,
    'del': TerminalKey.delete,
  };

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
}
