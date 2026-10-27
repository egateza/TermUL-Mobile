import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/app_settings.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/key_button.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../terminal/quick_key_bar.dart' show QuickKeyBar;
import '../terminal/quick_key_catalog.dart';

/// Membuka "Tombol cepat" dari Pengaturan > Terminal.
Future<void> openQuickKeysSettings(BuildContext context) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    settings: const RouteSettings(name: 'quick-keys'),
    builder: (_) => const QuickKeysScreen(),
  ),
);

/// Mengatur isi dua baris tombol cepat terminal (prototipe 6f `QuickKeys` dan 6g `QuickKeysAdd`): pratinjau,
/// catatan cara bilah digeser, daftar per baris dengan pegangan geser dan tombol hapus, Tambah tombol dari katalog
/// (maksimal [QuickKeySettings.maxPerRow] per baris; tombol yang sudah dipakai tidak bisa dipilih lagi), dan
/// Kembalikan bawaan. Perubahan langsung tersimpan.
class QuickKeysScreen extends ConsumerStatefulWidget {
  const QuickKeysScreen({super.key});

  @override
  ConsumerState<QuickKeysScreen> createState() => _QuickKeysScreenState();
}

class _QuickKeysScreenState extends ConsumerState<QuickKeysScreen> {
  bool _saveFailed = false;

  Future<void> _save(QuickKeySettings next) async {
    try {
      final current = ref.read(appSettingsProvider);
      await ref.read(appSettingsProvider.notifier).update(current.copyWith(quickKeys: next));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  void _move(int row, int from, int to) {
    final keys = ref.read(appSettingsProvider).quickKeys;
    final ids = [...keys.row(row)];
    final id = ids.removeAt(from);
    ids.insert(to, id);
    _save(keys.withRow(row, ids));
  }

  void _remove(int row, String id) {
    final keys = ref.read(appSettingsProvider).quickKeys;
    _save(keys.withRow(row, keys.row(row).where((e) => e != id).toList()));
  }

  Future<void> _add(int row) async {
    final id = await _showCatalog(context, row: row, used: ref.read(appSettingsProvider).quickKeys);
    if (id == null || !mounted) return;
    final keys = ref.read(appSettingsProvider).quickKeys;
    if (keys.uses(id) || keys.row(row).length >= QuickKeySettings.maxPerRow) return;
    _save(keys.withRow(row, [...keys.row(row), id]));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final keys = ref.watch(appSettingsProvider).quickKeys;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space3,
                TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Row(
                spacing: TermulSpacing.space3,
                children: [
                  TermulIconButton(
                    icon: TermulIconName.chevronLeft,
                    label: l.actionBack,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.quickKeysTitle, style: TermulText.h2.copyWith(color: TermulPalette.ink)),
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
                  if (_saveFailed) ...[
                    TermulBanner(
                      tone: BannerTone.warn,
                      title: l.settingsSaveFailedTitle,
                      child: Text(l.settingsSaveFailedBody),
                    ),
                    const SizedBox(height: TermulSpacing.space5),
                  ],
                  _Preview(keys: keys),
                  const SizedBox(height: TermulSpacing.space5),
                  _FixedNote(text: l.quickKeysFixedNote),
                  for (var row = 0; row < 2; row++) ...[
                    const SizedBox(height: TermulSpacing.space5),
                    _RowSection(
                      row: row,
                      ids: keys.row(row),
                      onMove: (from, to) => _move(row, from, to),
                      onRemove: (id) => _remove(row, id),
                      onAdd: () => _add(row),
                    ),
                  ],
                  const SizedBox(height: TermulSpacing.space5),
                  TermulButton(
                    label: l.settingsResetDefaults,
                    onPressed: keys.isDefault ? null : () => _save(const QuickKeySettings()),
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

/// Bilah tombol cepat versi kecil: tujuh kolom pertama tiap baris.
class _Preview extends StatelessWidget {
  const _Preview({required this.keys});

  final QuickKeySettings keys;

  static const _cell = 36.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget chip(Widget child, {Color color = TermulPalette.ink}) => Container(
      height: _cell,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TermulPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(TermulRadius.radiusMd - 1),
        border: Border.all(color: TermulPalette.line),
      ),
      child: DefaultTextStyle.merge(
        style: TermulText.key.copyWith(color: color, fontSize: 12),
        child: child,
      ),
    );
    Widget row(int index) => Row(
      spacing: TermulSpacing.space2,
      children: [
        for (var i = 0; i < QuickKeyBar.visibleColumns; i++)
          Expanded(
            child: i < keys.row(index).length
                ? chip(Text(quickKeyById(keys.row(index)[i])?.label(l) ?? '', maxLines: 1))
                : const SizedBox(height: _cell),
          ),
      ],
    );
    return Semantics(
      label: l.quickKeysPreviewLabel,
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(TermulSpacing.space3),
        decoration: BoxDecoration(
          color: TermulPalette.ground,
          borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
          border: Border.all(color: TermulPalette.line),
        ),
        child: Column(spacing: TermulSpacing.space2, children: [row(0), row(1)]),
      ),
    );
  }
}

class _FixedNote extends StatelessWidget {
  const _FixedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space5),
    decoration: BoxDecoration(
      color: TermulPalette.surface,
      borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
      border: Border.all(color: TermulPalette.line),
    ),
    child: Text(text, style: TermulText.bodySm.copyWith(color: TermulPalette.inkSoft)),
  );
}

class _RowSection extends StatelessWidget {
  const _RowSection({
    required this.row,
    required this.ids,
    required this.onMove,
    required this.onRemove,
    required this.onAdd,
  });

  final int row;
  final List<String> ids;
  final void Function(int from, int to) onMove;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final full = ids.length >= QuickKeySettings.maxPerRow;
    final defs = [for (final id in ids) ?quickKeyById(id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(TermulSpacing.space3, 0, TermulSpacing.space3, TermulSpacing.space2),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.quickKeysRow(row + 1).toUpperCase(),
                    style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
                  ),
                ),
              ),
              Text(
                l.quickKeysCount(ids.length, QuickKeySettings.maxPerRow),
                style: TermulText.overline.copyWith(color: full ? TermulPalette.accent : TermulPalette.inkMuted),
              ),
            ],
          ),
        ),
        Container(
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
                if (defs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(TermulSpacing.space6),
                    child: Text(l.quickKeysEmptyRow, style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted)),
                  )
                else
                  ReorderableListView.builder(
                    key: ValueKey('quick-keys-row-$row'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: defs.length,
                    proxyDecorator: (child, index, animation) =>
                        Material(type: MaterialType.transparency, child: child),
                    onReorderItem: onMove,
                    itemBuilder: (context, i) => _KeyRow(
                      key: ValueKey('quick-key-$row-${defs[i].id}'),
                      index: i,
                      def: defs[i],
                      onRemove: () => onRemove(defs[i].id),
                    ),
                  ),
                Pressable(
                  onPressed: full ? null : onAdd,
                  semanticLabel: full ? l.quickKeysFull : l.quickKeysAdd,
                  minHeight: TermulSize.rowComfy - 12,
                  builder: (context, down) => Container(
                    height: TermulSize.rowComfy - 12,
                    alignment: Alignment.center,
                    color: down ? TermulPalette.surfaceRaised : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: TermulSpacing.space3,
                      children: [
                        if (!full) const TermulIcon(TermulIconName.plus, size: 18, color: TermulPalette.accent),
                        Text(
                          full ? l.quickKeysFull : l.quickKeysAdd,
                          style: TermulText.body.copyWith(
                            color: full ? TermulPalette.inkFaint : TermulPalette.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({super.key, required this.index, required this.def, required this.onRemove});

  final int index;
  final QuickKeyDef def;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = def.label(l);
    final aria = def.aria(l);
    return Container(
      constraints: const BoxConstraints(minHeight: TermulSize.rowComfy - 12),
      decoration: const BoxDecoration(
        color: TermulPalette.surface,
        border: Border(bottom: BorderSide(color: TermulPalette.line)),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: l.quickKeysDragLabel(aria),
              child: const SizedBox(
                width: TermulSize.tapMin,
                height: TermulSize.tapMin,
                child: Center(child: TermulIcon(TermulIconName.grip, size: 20, color: TermulPalette.inkMuted)),
              ),
            ),
          ),
          Container(
            width: 64,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TermulPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(TermulRadius.radiusMd - 2),
              border: Border.all(color: TermulPalette.line),
            ),
            child: Text(
              label,
              style: TermulText.key.copyWith(color: TermulPalette.ink, fontSize: label.length > 4 ? 12 : 13),
            ),
          ),
          const SizedBox(width: TermulSpacing.space5),
          Expanded(
            child: Text(
              aria,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
            ),
          ),
          TermulIconButton(icon: TermulIconName.close, label: l.quickKeysRemove(aria), onPressed: onRemove),
          const SizedBox(width: TermulSpacing.space1),
        ],
      ),
    );
  }
}

/// Sheet katalog (prototipe 6g): tombol per kelompok, yang sudah dipakai diredupkan dan tidak bisa dipilih.
/// Mengembalikan id tombol yang dipilih, atau null bila dibatalkan.
Future<String?> _showCatalog(BuildContext context, {required int row, required QuickKeySettings used}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
      side: BorderSide(color: TermulPalette.line),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
    builder: (sheetContext) {
      final l = AppLocalizations.of(sheetContext);
      final groups = {
        QuickKeyGroup.action: l.quickKeysGroupAction,
        QuickKeyGroup.navigation: l.quickKeysGroupNav,
        QuickKeyGroup.control: l.quickKeysGroupCtrl,
        QuickKeyGroup.symbol: l.quickKeysGroupSymbol,
      };
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TermulSpacing.space9,
            TermulSpacing.space5,
            TermulSpacing.space9,
            TermulSpacing.space9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: TermulPalette.lineStrong, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: TermulSpacing.space6),
              Semantics(
                header: true,
                child: Text(l.quickKeysAddTitle(row + 1), style: TermulText.h2.copyWith(color: TermulPalette.ink)),
              ),
              const SizedBox(height: TermulSpacing.space3),
              Text(l.quickKeysAddHint, style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted)),
              const SizedBox(height: TermulSpacing.space5),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final g in groups.entries) ...[
                        Text(g.value.toUpperCase(), style: TermulText.overline.copyWith(color: TermulPalette.inkMuted)),
                        const SizedBox(height: TermulSpacing.space2),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const cols = 5;
                            final width = (constraints.maxWidth - TermulSpacing.space2 * (cols - 1)) / cols;
                            return Wrap(
                              spacing: TermulSpacing.space2,
                              runSpacing: TermulSpacing.space2,
                              children: [
                                for (final def in quickKeyCatalog.where((k) => k.group == g.key))
                                  Opacity(
                                    opacity: used.uses(def.id) ? 0.4 : 1,
                                    child: KeyButton(
                                      key: ValueKey('quick-key-pick-${def.id}'),
                                      label: def.label(l),
                                      ariaLabel: used.uses(def.id) ? l.quickKeysUsed(def.aria(l)) : def.aria(l),
                                      width: width,
                                      onPressed: used.uses(def.id)
                                          ? null
                                          : () => Navigator.of(sheetContext).pop(def.id),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: TermulSpacing.space6),
                      ],
                    ],
                  ),
                ),
              ),
              TermulButton(label: l.actionCancel, onPressed: () => Navigator.of(sheetContext).pop()),
            ],
          ),
        ),
      );
    },
  );
}
