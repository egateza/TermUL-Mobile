import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import 'pressable.dart';
import 'termul_icon.dart';

/// Satu tab di [TermulNavBar].
class NavItem {
  const NavItem({required this.id, required this.label, required this.icon, this.badge = 0, this.semanticLabel});

  final String id;

  /// Satu kata.
  final String label;
  final TermulIconName icon;

  /// Lencana jumlah di atas ikon; 0 = tanpa lencana.
  final int badge;

  /// Nama untuk pembaca layar bila perlu lebih panjang dari [label] (mis. memuat jumlah lencana).
  final String? semanticLabel;
}

/// Bar navigasi bawah (`components/NavBar` di design system): tab dengan ikon dan label, tab aktif berwarna
/// `accent`, tinggi item minimal 56, tepi atas 1 px `line`, tanpa bayangan. Menangani sendiri area aman di bawah.
class TermulNavBar extends StatelessWidget {
  const TermulNavBar({super.key, required this.items, required this.active, required this.onSelect, this.label});

  final List<NavItem> items;
  final String active;
  final ValueChanged<String> onSelect;

  /// Nama landmark untuk pembaca layar.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: TermulPalette.ground,
          border: Border(top: BorderSide(color: TermulPalette.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: _NavTab(item: item, selected: item.id == active, onPressed: () => onSelect(item.id)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.item, required this.selected, required this.onPressed});

  final NavItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TermulPalette.accent : TermulPalette.inkMuted;
    return Pressable(
      minHeight: 56,
      toggled: selected,
      semanticLabel: item.semanticLabel ?? item.label,
      onPressed: onPressed,
      builder: (context, pressed) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              TermulIcon(item.icon, size: 22, color: color),
              if (item.badge > 0)
                Positioned(
                  top: -6,
                  right: -12,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: TermulPalette.accent, borderRadius: BorderRadius.circular(9)),
                    child: Text(
                      '${item.badge}',
                      // Lencana prototipe `Main`: JetBrains Mono 11 px, tebal 500.
                      style: const TextStyle(
                        fontFamily: TermulFonts.mono,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        fontVariations: [FontVariation('wght', 500)],
                        color: TermulPalette.onAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Text(item.label, style: TermulText.navLabel.copyWith(color: color), maxLines: 1),
        ],
      ),
    );
  }
}
