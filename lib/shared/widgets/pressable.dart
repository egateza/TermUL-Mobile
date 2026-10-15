import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';

/// Cincin fokus papan ketik: 2 px `accent`, offset 2 px, di sekeliling [child]. Hanya tampil bila fokus berasal
/// dari papan ketik (mode sorot tradisional), bukan dari sentuhan.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.radius = TermulRadius.radiusLg,
  });

  final Widget child;
  final double radius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        final visible =
            focused &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional;
        if (visible != _show) setState(() => _show = visible);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_show)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('focus-ring'),
                  decoration: BoxDecoration(
                    border: Border.all(color: TermulPalette.accent, width: 2),
                    borderRadius: BorderRadius.circular(widget.radius + 4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dasar semua kontrol yang bisa ditekan: target sentuh, keadaan menekan (isian `accent`), nonaktif
/// (opasitas 0,4), cincin fokus, dan semantik tombol. Tanpa animasi.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    required this.onPressed,
    this.semanticLabel,
    this.radius = TermulRadius.radiusLg,
    this.minWidth = 0,
    this.minHeight = TermulSize.tapMin,
    this.canRequestFocus = true,
    this.toggled,
  });

  /// Dipanggil dengan keadaan menekan; kembalikan isi kontrol (warna menyesuaikan [pressed]).
  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double radius;
  final double minWidth;
  final double minHeight;

  /// `false` untuk tombol terminal supaya keyboard sistem tidak tertutup.
  final bool canRequestFocus;
  final bool? toggled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final body = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onPressed,
          canRequestFocus: widget.canRequestFocus && enabled,
          borderRadius: BorderRadius.circular(widget.radius),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: widget.builder(context, _pressed && enabled),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: FocusRing(radius: widget.radius, child: body),
      ),
    );
  }
}
