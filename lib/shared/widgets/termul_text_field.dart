import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'termul_icon.dart';
import 'termul_icon_button.dart';

/// Kolom input satu baris, 48 px, tepi `line-strong`, cincin `accent` saat fokus. [label] wajib; dengan
/// [hideLabel] label disembunyikan secara visual tetapi tetap dibaca pembaca layar. Placeholder bukan
/// pengganti label dan tidak boleh memuat informasi penting.
class TermulTextField extends StatefulWidget {
  const TermulTextField({
    super.key,
    required this.label,
    this.controller,
    this.placeholder,
    this.helper,
    this.error,
    this.icon,
    this.mono = false,
    this.hideLabel = false,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.suffix,
    this.clearLabel,
    this.minLines,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? placeholder;
  final String? helper;
  final String? error;
  final TermulIconName? icon;
  final bool mono;
  final bool hideLabel;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final Widget? suffix;

  /// Nama tombol hapus ("Hapus pencarian"). Bila diisi (dan ada [controller]), tombol x 44 px muncul di pojok kanan
  /// selama kolom berisi teks; mengetuknya mengosongkan kolom, memanggil [onChanged] dengan teks kosong, dan
  /// mempertahankan fokus (keyboard tetap terbuka).
  final String? clearLabel;

  /// Isian beberapa baris (perintah snippet): tinggi tumbuh dari [minLines] sampai [maxLines], lalu digulir.
  final int? minLines;
  final int? maxLines;

  @override
  State<TermulTextField> createState() => _TermulTextFieldState();
}

class _TermulTextFieldState extends State<TermulTextField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller?.clear();
    widget.onChanged?.call('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.mono ? TermulText.terminal : TermulText.body).copyWith(color: TermulPalette.ink);
    final hasError = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.hideLabel) ...[
          Text(widget.label, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
          const SizedBox(height: TermulSpacing.space1),
        ],
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: TermulSize.inputH),
              // Dengan tombol hapus di kanan, jarak kanan dikecilkan supaya tombol 44 px menempel ke pojok.
              padding: EdgeInsetsDirectional.only(
                start: TermulSpacing.space6,
                end: widget.clearLabel != null && widget.controller != null ? 2 : TermulSpacing.space6,
              ),
              decoration: BoxDecoration(
                color: TermulPalette.surface,
                borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
                border: Border.all(color: hasError ? TermulPalette.bad : TermulPalette.lineStrong),
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    TermulIcon(widget.icon!, size: 18, color: TermulPalette.inkMuted),
                    const SizedBox(width: TermulSpacing.space4),
                  ],
                  Expanded(
                    child: Semantics(
                      label: widget.label,
                      textField: true,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        enabled: widget.enabled,
                        obscureText: widget.obscure,
                        minLines: widget.obscure ? 1 : widget.minLines,
                        maxLines: widget.obscure ? 1 : widget.maxLines,
                        autofocus: widget.autofocus,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        style: style,
                        cursorColor: TermulPalette.accent,
                        autocorrect: false,
                        enableSuggestions: !widget.mono && !widget.obscure,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: TermulSpacing.space5),
                          hintText: widget.placeholder,
                          hintStyle: style.copyWith(color: TermulPalette.inkFaint),
                        ),
                      ),
                    ),
                  ),
                  ?widget.suffix,
                  if (widget.clearLabel != null && widget.controller != null)
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.controller!,
                      builder: (context, value, _) => value.text.isEmpty || !widget.enabled
                          ? const SizedBox(width: TermulSpacing.space4)
                          : TermulIconButton(
                              key: const ValueKey('field-clear'),
                              icon: TermulIconName.close,
                              label: widget.clearLabel!,
                              onPressed: _clear,
                            ),
                    ),
                ],
              ),
            ),
            if (_focused)
              Positioned(
                left: -4,
                top: -4,
                right: -4,
                bottom: -4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey('field-focus-ring'),
                    decoration: BoxDecoration(
                      border: Border.all(color: TermulPalette.accent, width: 2),
                      borderRadius: BorderRadius.circular(TermulRadius.radiusLg + 4),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (hasError || widget.helper != null) ...[
          const SizedBox(height: TermulSpacing.space1),
          Text(
            widget.error ?? widget.helper!,
            style: TermulText.caption.copyWith(color: hasError ? TermulPalette.bad : TermulPalette.inkMuted),
          ),
        ],
      ],
    );
  }
}
