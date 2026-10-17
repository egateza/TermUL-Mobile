import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/snippet.dart';
import '../../core/models/snippet_library.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_text_field.dart';
import '../../shared/widgets/termul_toast.dart';

/// Ruang di sekeliling isi yang digulir supaya cincin fokus isian (di luar tepinya 4 px) tidak terpotong.
const double snippetRingGutter = TermulSpacing.space1;

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
  side: BorderSide(color: TermulPalette.line),
);

Widget _handle() => Center(
  child: Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(color: TermulPalette.lineStrong, borderRadius: BorderRadius.circular(2)),
  ),
);

/// Membuka pengelola kategori: daftar kategori dengan jumlah snippet, tombol ubah nama dan hapus per baris, dan
/// tombol Kategori baru. Perubahan langsung tersimpan.
Future<void> showSnippetCategoryManager(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: _sheetShape,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
    builder: (_) => const _ManagerSheet(),
  );
}

class _ManagerSheet extends ConsumerStatefulWidget {
  const _ManagerSheet();

  @override
  ConsumerState<_ManagerSheet> createState() => _ManagerSheetState();
}

class _ManagerSheetState extends ConsumerState<_ManagerSheet> {
  String? _error;

  Future<void> _edit(SnippetCategory? category) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final library = ref.read(snippetLibraryProvider);
    final name = await showCategoryNameSheet(
      context,
      initial: category?.name,
      isTaken: (n) => library.nameTaken(n, exceptId: category?.id),
    );
    if (name == null || !mounted) return;
    final next = category == null ? SnippetCategory.create(name) : category.copyWith(name: name);
    try {
      await ref.read(snippetRepositoryProvider).saveCategory(next);
      if (!mounted) return;
      setState(() => _error = null);
      showTermulToastOn(messenger, l.categorySaved);
    } on Object {
      if (mounted) setState(() => _error = l.categorySaveFailed);
    }
  }

  /// Urutan yang baru digeser dan sedang disimpan (id kategori). Selama itu daftar memakainya supaya baris yang
  /// dilepas langsung diam di tempat barunya; tanpa ini baris kembali ke posisi lama sampai penulisan berkas selesai
  /// lalu melompat (terasa seperti glitch). Dilepas bila sudah sama dengan yang tersimpan, atau bila gagal.
  List<String>? _pendingOrder;

  /// Kategori menurut urutan yang harus tampil: yang tersimpan, atau [_pendingOrder] bila ada.
  List<SnippetCategory> _displayed(SnippetLibrary library) {
    final pending = _pendingOrder;
    if (pending == null) return library.categories;
    final byId = {for (final c in library.categories) c.id: c};
    final result = [
      for (final id in pending)
        if (byId[id] != null) byId[id]!,
      for (final c in library.categories)
        if (!pending.contains(c.id)) c,
    ];
    if (listEquals([for (final c in result) c.id], [for (final c in library.categories) c.id])) {
      _pendingOrder = null; // sudah tersimpan: tampilan dan penyimpanan sama lagi
    }
    return result;
  }

  Future<void> _move(List<SnippetCategory> shown, int oldIndex, int newIndex) async {
    final l = AppLocalizations.of(context);
    final order = [...shown];
    final moved = order.removeAt(oldIndex);
    order.insert(newIndex, moved);
    setState(() {
      _pendingOrder = [for (final c in order) c.id];
      _error = null;
    });
    try {
      await ref.read(snippetRepositoryProvider).moveCategory(moved.id, newIndex);
    } on Object {
      // Gagal menyimpan: kembali ke urutan yang tersimpan dan beri tahu.
      if (mounted) {
        setState(() {
          _pendingOrder = null;
          _error = l.categoryMoveFailed;
        });
      }
    }
  }

  void _confirmDelete(SnippetCategory category, int count) {
    final l = AppLocalizations.of(context);
    showTermulSheet<void>(
      context,
      title: l.categoryDeleteTitle(category.name),
      child: Text(
        count > 0 ? l.categoryDeleteBodyUsed(count) : l.categoryDeleteBodyEmpty,
        style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
      ),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDelete,
      confirmIsDanger: true,
      onConfirm: () => _delete(category),
    );
  }

  Future<void> _delete(SnippetCategory category) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(snippetRepositoryProvider).deleteCategory(category.id);
      if (!mounted) return;
      setState(() => _error = null);
      showTermulToastOn(messenger, l.categoryDeleted);
    } on Object {
      if (mounted) setState(() => _error = l.categoryDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final library = ref.watch(snippetLibraryProvider);
    final shown = _displayed(library);
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
            _handle(),
            const SizedBox(height: TermulSpacing.space5),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.categoryManagerTitle, style: TermulText.h2.copyWith(color: TermulPalette.ink)),
                  ),
                ),
                TermulIconButton(
                  icon: TermulIconName.close,
                  label: l.actionClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: TermulSpacing.space3),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
                child: TermulBanner(
                  tone: BannerTone.risk,
                  action: TermulButton(
                    label: l.actionClose,
                    size: TermulButtonSize.sm,
                    expand: false,
                    onPressed: () => setState(() => _error = null),
                  ),
                  child: Text(_error!),
                ),
              ),
            if (library.categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TermulSpacing.space7),
                child: Text(
                  l.categoryManagerEmpty,
                  textAlign: TextAlign.center,
                  style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
                ),
              ),
            if (library.categories.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
                child: Text(l.categoryManagerHint, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
              ),
            Flexible(
              // Baris digeser lewat pegangan di kiri (tanpa pegangan bawaan di kanan). Tanpa bayangan saat diseret:
              // tepi 1 px saja, sesuai aturan desain.
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: shown.length,
                proxyDecorator: (child, index, animation) => Material(type: MaterialType.transparency, child: child),
                // onReorderItem sudah menyesuaikan indeks tujuan untuk item yang dicabut (sama dengan model).
                onReorderItem: (oldIndex, newIndex) => _move(shown, oldIndex, newIndex),
                itemBuilder: (context, i) {
                  final c = shown[i];
                  return Padding(
                    key: ValueKey(c.id),
                    padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
                    child: _CategoryRow(
                      index: i,
                      category: c,
                      count: library.countIn(c.id),
                      onEdit: () => _edit(c),
                      onDelete: () => _confirmDelete(c, library.countIn(c.id)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: TermulSpacing.space7),
            TermulButton(
              label: l.categoryAdd,
              icon: TermulIconName.plus,
              size: TermulButtonSize.lg,
              variant: TermulButtonVariant.primary,
              onPressed: () => _edit(null),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.index,
    required this.category,
    required this.count,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final SnippetCategory category;
  final int count;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: TermulSize.rowComfy),
      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space2),
      decoration: BoxDecoration(
        color: TermulPalette.surface,
        borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
        border: Border.all(color: TermulPalette.line),
      ),
      child: Row(
        children: [
          // Pegangan geser: menyentuh dan menggeser langsung memindahkan baris (target sentuh 44 px).
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: l.categoryDragLabel(category.name),
              child: const SizedBox(
                width: TermulSize.tapMin,
                height: TermulSize.tapMin,
                child: Center(child: TermulIcon(TermulIconName.grip, size: 20, color: TermulPalette.inkMuted)),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TermulSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: TermulText.body.copyWith(color: TermulPalette.ink)),
                  Text(l.categoryCount(count), style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                ],
              ),
            ),
          ),
          TermulIconButton(icon: TermulIconName.edit, label: l.categoryEditLabel(category.name), onPressed: onEdit),
          TermulIconButton(
            icon: TermulIconName.trash,
            label: l.categoryDeleteLabel(category.name),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Meminta nama kategori. [initial] terisi saat mengubah nama. [isTaken] memberi tahu nama sudah dipakai kategori
/// lain. Mengembalikan nama yang sudah dipangkas, atau null bila dibatalkan.
Future<String?> showCategoryNameSheet(
  BuildContext context, {
  String? initial,
  required bool Function(String name) isTaken,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: _sheetShape,
    builder: (_) => _NameSheet(initial: initial, isTaken: isTaken),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial, required this.isTaken});

  final String? initial;
  final bool Function(String name) isTaken;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  String? _error(AppLocalizations l) {
    if (_name.length > SnippetCategory.maxNameLength) return l.categoryNameTooLong(SnippetCategory.maxNameLength);
    if (_name.isNotEmpty && widget.isTaken(_name)) return l.categoryNameTaken;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final error = _error(l);
    final canSave = _name.isNotEmpty && error == null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TermulSpacing.space9 - snippetRingGutter,
          TermulSpacing.space5,
          TermulSpacing.space9 - snippetRingGutter,
          TermulSpacing.space9 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            const SizedBox(height: TermulSpacing.space5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: snippetRingGutter),
              child: Semantics(
                header: true,
                child: Text(
                  widget.initial == null ? l.categoryNewTitle : l.categoryRenameTitle,
                  style: TermulText.h2.copyWith(color: TermulPalette.ink),
                ),
              ),
            ),
            const SizedBox(height: TermulSpacing.space5),
            Padding(
              padding: const EdgeInsets.all(snippetRingGutter),
              child: TermulTextField(
                label: l.categoryNameLabel,
                controller: _controller,
                autofocus: true,
                error: error,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (canSave) Navigator.of(context).pop(_name);
                },
              ),
            ),
            const SizedBox(height: TermulSpacing.space5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: snippetRingGutter),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TermulButton(
                      label: l.actionCancel,
                      size: TermulButtonSize.lg,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: TermulSpacing.space3),
                  Expanded(
                    flex: 3,
                    child: TermulButton(
                      label: l.actionSave,
                      size: TermulButtonSize.lg,
                      variant: TermulButtonVariant.primary,
                      onPressed: canSave ? () => Navigator.of(context).pop(_name) : null,
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
