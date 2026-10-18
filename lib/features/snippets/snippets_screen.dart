import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../app_providers.dart';
import '../../core/models/snippet.dart';
import '../../core/models/snippet_library.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_chip.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_action_sheet.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_text_field.dart';
import '../../shared/widgets/termul_toast.dart';
import 'snippet_detail_sheet.dart';
import 'snippet_editor_sheet.dart';
import 'snippet_card.dart';
import 'snippet_category_sheet.dart';
import 'snippet_list_model.dart';

/// Tab Snippet: daftar perintah tersimpan, dengan pencarian, filter, detail (isi variabel lalu salin), dan editor.
class SnippetsScreen extends ConsumerStatefulWidget {
  const SnippetsScreen({super.key});

  @override
  ConsumerState<SnippetsScreen> createState() => _SnippetsScreenState();
}

class _SnippetsScreenState extends ConsumerState<SnippetsScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _favoritesOnly = false;
  String? _categoryId;
  String? _error;
  bool _hideCorruptBanner = false;

  /// Mode mengurutkan: semua snippet tampil dengan pegangan geser; pencarian dan filter disembunyikan.
  bool _sorting = false;

  /// Urutan yang baru digeser dan sedang disimpan (id snippet). Selama itu daftar memakainya supaya baris yang
  /// dilepas langsung diam di tempat barunya, tidak kembali ke posisi lama sampai penulisan berkas selesai.
  List<String>? _pendingOrder;

  List<Snippet> _displayed(SnippetLibrary library) {
    final pending = _pendingOrder;
    if (pending == null) return library.snippets;
    final byId = {for (final s in library.snippets) s.id: s};
    final result = [
      for (final id in pending)
        if (byId[id] != null) byId[id]!,
      for (final s in library.snippets)
        if (!pending.contains(s.id)) s,
    ];
    if (listEquals([for (final s in result) s.id], [for (final s in library.snippets) s.id])) {
      _pendingOrder = null; // sudah tersimpan: tampilan dan penyimpanan sama lagi
    }
    return result;
  }

  Future<void> _move(List<Snippet> shown, int oldIndex, int newIndex) async {
    final l = AppLocalizations.of(context);
    final order = [...shown];
    final moved = order.removeAt(oldIndex);
    order.insert(newIndex, moved);
    setState(() {
      _pendingOrder = [for (final s in order) s.id];
      _error = null;
    });
    try {
      await ref.read(snippetRepositoryProvider).moveSnippet(moved.id, newIndex);
    } on Object {
      if (mounted) {
        setState(() {
          _pendingOrder = null;
          _error = l.snippetMoveFailed;
        });
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _scopeLabel(AppLocalizations l, Snippet s) {
    final id = s.hostId;
    if (id == null) return l.snippetScopeAll;
    return ref.read(hostSnapshotProvider).find(id)?.name ?? l.snippetScopeAll;
  }

  Future<void> _create() => _edit(null);

  Future<void> _edit(Snippet? existing) async {
    final hosts = ref.read(hostSnapshotProvider).profiles;
    final result = await showSnippetEditor(context, hosts: hosts, existing: existing);
    if (!mounted || result == null) return;
    switch (result) {
      case SnippetSaved(:final snippet):
        await _persist(snippet);
      case SnippetDeleteRequested(:final snippet):
        _confirmDelete(snippet);
    }
  }

  Future<void> _persist(Snippet snippet) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(snippetRepositoryProvider).save(snippet);
      if (!mounted) return;
      setState(() => _error = null);
      showTermulToastOn(messenger, l.snippetSaved);
    } on Object {
      if (mounted) setState(() => _error = l.snippetSaveFailed);
    }
  }

  void _confirmDelete(Snippet snippet) {
    final l = AppLocalizations.of(context);
    showTermulSheet<void>(
      context,
      title: l.snippetDeleteTitle(snippet.title),
      child: Text(l.snippetDeleteBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDelete,
      confirmIsDanger: true,
      onConfirm: () => _delete(snippet),
    );
  }

  Future<void> _delete(Snippet snippet) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(snippetRepositoryProvider).delete(snippet.id);
      if (!mounted) return;
      setState(() => _error = null);
      showTermulToastOn(messenger, l.snippetDeleted);
    } on Object {
      if (mounted) setState(() => _error = l.snippetDeleteFailed);
    }
  }

  Future<void> _export() async {
    try {
      final library = ref.read(snippetLibraryProvider);
      final text = const JsonEncoder.withIndent('  ').convert(library.toJson());
      final dir = await ref.read(tempDirProvider)();
      final shareDir = Directory('${dir.path}${Platform.pathSeparator}share');
      if (shareDir.existsSync()) shareDir.deleteSync(recursive: true);
      shareDir.createSync(recursive: true);
      const name = 'termul-snippets.json';
      final file = File('${shareDir.path}${Platform.pathSeparator}$name');
      await file.writeAsString(text, encoding: utf8, flush: true);
      await ref
          .read(fileSharerProvider)
          .shareFile(path: file.path, name: name, mimeType: 'application/json', title: 'Ekspor snippet');
    } on Object {
      if (mounted) setState(() => _error = 'Snippet tidak bisa diekspor. Coba lagi.');
    }
  }

  Future<void> _import() async {
    try {
      final file = await openFile();
      if (file == null) return;
      if (await file.length() > 2 * 1024 * 1024) throw const FormatException('Berkas terlalu besar.');
      final incoming = SnippetLibrary.fromJson(
        jsonDecode(utf8.decode(await file.readAsBytes())) as Map<String, Object?>,
      );
      final repo = ref.read(snippetRepositoryProvider);
      final current = repo.library;
      final ids = <String, String>{};
      for (final category in incoming.categories) {
        final existing = current.categories
            .where((c) => c.name.toLowerCase() == category.name.toLowerCase())
            .firstOrNull;
        if (existing != null) {
          ids[category.id] = existing.id;
        } else {
          final created = SnippetCategory.create(category.name);
          await repo.saveCategory(created);
          ids[category.id] = created.id;
        }
      }
      for (final snippet in incoming.snippets) {
        await repo.save(
          Snippet.create(
            title: snippet.title,
            command: snippet.command,
            categoryId: ids[snippet.categoryId],
            favorite: snippet.favorite,
            dangerous: snippet.dangerous,
            defaults: snippet.defaults,
          ),
        );
      }
      if (mounted) showTermulToast(context, 'Impor ${incoming.snippets.length} snippet selesai');
    } on Object {
      if (mounted) setState(() => _error = 'Berkas snippet tidak valid atau gagal dibaca.');
    }
  }

  Future<void> _manage(List<Snippet> all) => showTermulActions(
    context,
    title: 'Kelola snippet',
    actions: [
      if (all.length > 1)
        SheetAction(
          label: _sorting ? 'Selesai mengurutkan' : 'Urutkan snippet',
          icon: _sorting ? TermulIconName.check : TermulIconName.sort,
          onSelected: () => setState(() => _sorting = !_sorting),
        ),
      SheetAction(label: 'Impor snippet', icon: TermulIconName.upload, onSelected: _import),
      SheetAction(label: 'Ekspor snippet', icon: TermulIconName.download, onSelected: _export),
      SheetAction(
        label: 'Kelola kategori',
        icon: TermulIconName.edit,
        onSelected: () => showSnippetCategoryManager(context),
      ),
    ],
  );

  Future<void> _open(Snippet snippet) async {
    final l = AppLocalizations.of(context);
    final category = ref.read(snippetLibraryProvider).categoryOf(snippet.categoryId);
    final meta = [?category?.name, _scopeLabel(l, snippet)].join(' · ');
    final result = await showSnippetDetail(context, snippet: snippet, meta: meta);
    if (!mounted || result == null) return;
    switch (result) {
      case SnippetDetailResult.edit:
        await _edit(snippet);
      case SnippetDetailResult.delete:
        _confirmDelete(snippet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final library = ref.watch(snippetLibraryProvider);
    final all = _displayed(library);
    // Mengurutkan butuh sedikitnya dua snippet; bila tinggal satu (mis. dihapus), mode berakhir sendiri.
    final sorting = _sorting && all.length > 1;
    final report = ref.watch(bootReportProvider);
    // Kategori yang dipilih sebagai filter lalu dihapus: filter kembali ke Semua.
    final categoryId = library.hasCategory(_categoryId ?? '') ? _categoryId : null;
    final shown = filterSnippets(all, query: _query, favoritesOnly: _favoritesOnly, categoryId: categoryId);
    final banners = <Widget>[
      if (report.snippets.hadCorruptFile && !_hideCorruptBanner)
        TermulBanner(
          tone: BannerTone.warn,
          title: l.snippetsCorruptTitle,
          action: TermulButton(
            label: l.actionClose,
            size: TermulButtonSize.sm,
            expand: false,
            onPressed: () => setState(() => _hideCorruptBanner = true),
          ),
          child: Text(l.snippetsCorruptBody(report.snippets.quarantinedPath!.split(RegExp(r'[\\/]')).last)),
        ),
      if (_error != null)
        TermulBanner(
          tone: BannerTone.risk,
          action: TermulButton(
            label: l.actionClose,
            size: TermulButtonSize.sm,
            expand: false,
            onPressed: () => setState(() => _error = null),
          ),
          child: Text(_error!),
        ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space8,
                TermulSpacing.space8,
                TermulSpacing.space8,
                TermulSpacing.space5,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.navSnippets, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
                    ),
                  ),
                  TermulIconButton(icon: TermulIconName.more, label: 'Kelola snippet', onPressed: () => _manage(all)),
                  const SizedBox(width: TermulSpacing.space3),
                  TermulIconButton(
                    icon: TermulIconName.plus,
                    label: l.snippetsAdd,
                    tone: IconButtonTone.accent,
                    onPressed: _create,
                  ),
                ],
              ),
            ),
            if (all.isNotEmpty && !sorting) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space8, TermulSpacing.space5),
                child: TermulTextField(
                  label: l.snippetsSearchLabel,
                  hideLabel: true,
                  icon: TermulIconName.search,
                  placeholder: l.snippetsSearchPlaceholder,
                  clearLabel: l.actionClearSearch,
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space8, TermulSpacing.space3),
                child: Row(
                  spacing: TermulSpacing.space3,
                  children: [
                    FilterChipButton(
                      label: l.filterAll,
                      selected: !_favoritesOnly && categoryId == null,
                      onPressed: () => setState(() {
                        _favoritesOnly = false;
                        _categoryId = null;
                      }),
                    ),
                    FilterChipButton(
                      label: l.filterFavorites,
                      selected: _favoritesOnly,
                      onPressed: () => setState(() {
                        _favoritesOnly = true;
                        _categoryId = null;
                      }),
                    ),
                    for (final c in library.categories)
                      FilterChipButton(
                        label: c.name,
                        selected: categoryId == c.id,
                        onPressed: () => setState(() {
                          _favoritesOnly = false;
                          _categoryId = c.id;
                        }),
                      ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: all.isEmpty
                  ? _Empty(banners: banners, onAdd: _create)
                  : sorting
                  ? _SortList(
                      snippets: all,
                      banners: banners,
                      onMove: (oldIndex, newIndex) => _move(all, oldIndex, newIndex),
                      onDelete: _confirmDelete,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        TermulSpacing.space5,
                        0,
                        TermulSpacing.space5,
                        TermulSpacing.space8,
                      ),
                      children: [
                        for (final b in banners)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              TermulSpacing.space3,
                              0,
                              TermulSpacing.space3,
                              TermulSpacing.space3,
                            ),
                            child: b,
                          ),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: TermulSpacing.space7),
                            child: Text(
                              l.snippetsNoMatch,
                              textAlign: TextAlign.center,
                              style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
                            ),
                          ),
                        for (final s in shown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
                            child: SnippetCard(
                              snippet: s,
                              category: library.categoryOf(s.categoryId)?.name,
                              scope: _scopeLabel(l, s),
                              onPressed: () => _open(s),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.banners, required this.onAdd});

  final List<Widget> banners;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space8),
      children: [
        for (final b in banners)
          Padding(
            padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
            child: b,
          ),
        const SizedBox(height: TermulSpacing.space8),
        Semantics(
          header: true,
          child: Text(
            l.snippetsEmptyTitle,
            textAlign: TextAlign.center,
            style: TermulText.h2.copyWith(color: TermulPalette.ink),
          ),
        ),
        const SizedBox(height: TermulSpacing.space3),
        Text(
          l.snippetsEmptyBody,
          textAlign: TextAlign.center,
          style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
        ),
        const SizedBox(height: TermulSpacing.space8),
        TermulButton(
          label: l.snippetsAdd,
          icon: TermulIconName.plus,
          size: TermulButtonSize.lg,
          variant: TermulButtonVariant.primary,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

/// Daftar mode mengurutkan: semua snippet, tiap baris dengan pegangan geser di kiri (menyentuh dan menggeser langsung
/// memindahkan baris). Tanpa bayangan saat diseret; tepi 1 px saja sesuai aturan desain.
class _SortList extends StatelessWidget {
  const _SortList({required this.snippets, required this.banners, required this.onMove, required this.onDelete});

  final List<Snippet> snippets;
  final List<Widget> banners;

  /// Dipanggil dengan indeks tujuan yang sudah disesuaikan untuk baris yang dicabut.
  final void Function(int oldIndex, int newIndex) onMove;

  /// Meminta konfirmasi lalu menghapus snippet.
  final void Function(Snippet snippet) onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in banners)
          Padding(
            padding: const EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space8, TermulSpacing.space3),
            child: b,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space8, TermulSpacing.space5),
          child: Text(l.snippetsSortHint, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(TermulSpacing.space5, 0, TermulSpacing.space5, TermulSpacing.space8),
            itemCount: snippets.length,
            proxyDecorator: (child, index, animation) => Material(type: MaterialType.transparency, child: child),
            onReorderItem: onMove,
            itemBuilder: (context, i) => Padding(
              key: ValueKey(snippets[i].id),
              padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
              child: _SortRow(index: i, snippet: snippets[i], onDelete: () => onDelete(snippets[i])),
            ),
          ),
        ),
      ],
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.index, required this.snippet, required this.onDelete});

  final int index;
  final Snippet snippet;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: TermulSize.rowComfy),
      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space2),
      decoration: BoxDecoration(
        color: TermulPalette.surface,
        borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
        border: Border.all(color: TermulPalette.line),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: l.snippetsSortDragLabel(snippet.title),
              child: const SizedBox(
                width: TermulSize.tapMin,
                height: TermulSize.tapMin,
                child: Center(child: TermulIcon(TermulIconName.grip, size: 20, color: TermulPalette.inkMuted)),
              ),
            ),
          ),
          const SizedBox(width: TermulSpacing.space2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TermulSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snippet.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermulText.body.copyWith(color: TermulPalette.ink, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    snippet.firstLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermulText.terminal.copyWith(color: TermulPalette.inkMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          if (snippet.favorite)
            const Padding(
              padding: EdgeInsets.only(right: TermulSpacing.space2),
              child: TermulIcon(TermulIconName.star, size: 16, color: TermulPalette.accent, filled: true),
            ),
          TermulIconButton(icon: TermulIconName.trash, label: l.snippetDeleteLabel(snippet.title), onPressed: onDelete),
        ],
      ),
    );
  }
}
