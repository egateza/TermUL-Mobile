import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/host_profile.dart';
import '../../core/models/snippet.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/switch_row.dart';
import '../../shared/widgets/termul_action_sheet.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_chip.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_text_field.dart';
import 'snippet_category_sheet.dart' show showSnippetCategoryManager, snippetRingGutter;
import 'snippet_danger.dart';

/// Hasil menutup editor: simpan [snippet], atau hapus snippet yang sedang diedit.
sealed class SnippetEditorResult {
  const SnippetEditorResult();
}

final class SnippetSaved extends SnippetEditorResult {
  const SnippetSaved(this.snippet);

  final Snippet snippet;
}

final class SnippetDeleteRequested extends SnippetEditorResult {
  const SnippetDeleteRequested(this.snippet);

  final Snippet snippet;
}

/// Membuka editor untuk [existing] (edit) atau snippet baru bila null. [initialCommand] mengisi perintah snippet baru
/// (dipakai "Simpan sebagai snippet" dari terminal). [hosts] adalah pilihan "Satu host".
Future<SnippetEditorResult?> showSnippetEditor(
  BuildContext context, {
  required List<HostProfile> hosts,
  Snippet? existing,
  String initialCommand = '',
}) {
  return showModalBottomSheet<SnippetEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
      side: BorderSide(color: TermulPalette.line),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    builder: (_) => _EditorSheet(hosts: hosts, existing: existing, initialCommand: initialCommand),
  );
}

class _EditorSheet extends ConsumerStatefulWidget {
  const _EditorSheet({required this.hosts, required this.existing, required this.initialCommand});

  final List<HostProfile> hosts;
  final Snippet? existing;
  final String initialCommand;

  @override
  ConsumerState<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends ConsumerState<_EditorSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _command = TextEditingController(text: widget.existing?.command ?? widget.initialCommand);
  // Snippet baru dimulai di kategori pertama (bila ada); kategori yang sudah dihapus dianggap tanpa kategori.
  late String? _categoryId = widget.existing == null
      ? ref.read(snippetLibraryProvider).categories.firstOrNull?.id
      : widget.existing!.categoryId;
  // Host yang sudah dihapus tidak ada di daftar: dianggap "semua host".
  late String? _hostId = widget.hosts.any((h) => h.id == widget.existing?.hostId) ? widget.existing?.hostId : null;
  late bool _favorite = widget.existing?.favorite ?? false;
  late bool _dangerous = widget.existing?.dangerous ?? false;

  @override
  void dispose() {
    _title.dispose();
    _command.dispose();
    super.dispose();
  }

  /// Kategori terpilih yang masih ada (kategori yang dihapus lewat pengelola selagi editor terbuka dianggap tanpa
  /// kategori).
  String? get _effectiveCategoryId =>
      ref.read(snippetLibraryProvider).hasCategory(_categoryId ?? '') ? _categoryId : null;

  /// Membuka pengelola kategori di atas editor, tanpa menutup editor (isian tidak hilang). Kategori yang baru
  /// ditambahkan di sana langsung dipilih.
  Future<void> _manageCategories() async {
    final before = {for (final c in ref.read(snippetLibraryProvider).categories) c.id};
    await showSnippetCategoryManager(context);
    if (!mounted) return;
    final added = ref.read(snippetLibraryProvider).categories.where((c) => !before.contains(c.id));
    if (added.isNotEmpty) setState(() => _categoryId = added.last.id);
  }

  bool get _canSave => _title.text.trim().isNotEmpty && _command.text.trim().isNotEmpty;

  String? get _hostName {
    for (final h in widget.hosts) {
      if (h.id == _hostId) return h.name;
    }
    return null;
  }

  void _save() {
    final names = Snippet.variablesOf(_command.text);
    final old = widget.existing;
    // Nilai bawaan hanya berlaku untuk variabel yang masih ada di perintah.
    final defaults = {
      for (final e in (old?.defaults ?? const <String, String>{}).entries)
        if (names.contains(e.key)) e.key: e.value,
    };
    final snippet = old == null
        ? Snippet.create(
            title: _title.text,
            command: _command.text,
            categoryId: _effectiveCategoryId,
            hostId: _hostId,
            favorite: _favorite,
            dangerous: _dangerous,
            defaults: defaults,
          )
        : old.copyWith(
            title: _title.text.trim(),
            command: _command.text,
            categoryId: _effectiveCategoryId,
            hostId: _hostId,
            favorite: _favorite,
            dangerous: _dangerous,
            defaults: defaults,
          );
    Navigator.of(context).pop(SnippetSaved(snippet));
  }

  void _pickHost(AppLocalizations l) {
    showTermulActions(
      context,
      title: l.snippetScopePickTitle,
      actions: [
        for (final h in widget.hosts)
          SheetAction(label: h.name, primary: h.id == _hostId, onSelected: () => setState(() => _hostId = h.id)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editing = widget.existing != null;
    final categories = ref.watch(snippetLibraryProvider).categories;
    final categoryId = categories.any((c) => c.id == _categoryId) ? _categoryId : null;
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: TermulPalette.lineStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: TermulSpacing.space5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: snippetRingGutter),
              child: Semantics(
                header: true,
                child: Text(
                  editing ? l.snippetEditorEditTitle : l.snippetEditorNewTitle,
                  style: TermulText.h2.copyWith(color: TermulPalette.ink),
                ),
              ),
            ),
            const SizedBox(height: TermulSpacing.space5),
            Flexible(
              child: SingleChildScrollView(
                // Ruang untuk cincin fokus isian (4 px di luar tepinya) supaya tidak terpotong tepi area gulir.
                padding: const EdgeInsets.all(snippetRingGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TermulSpacing.space6,
                  children: [
                    TermulTextField(
                      label: l.snippetFieldTitle,
                      controller: _title,
                      placeholder: l.snippetFieldTitlePlaceholder,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    TermulTextField(
                      label: l.snippetFieldCommand(r'${nama}'),
                      controller: _command,
                      placeholder: r'systemctl status ${layanan}',
                      mono: true,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 4,
                      maxLines: 8,
                      onChanged: (_) => setState(() {}),
                    ),
                    _Section(
                      label: l.snippetFieldCategory,
                      trailing: TermulIconButton(
                        icon: TermulIconName.edit,
                        label: l.snippetsManageCategories,
                        onPressed: _manageCategories,
                      ),
                      child: Wrap(
                        spacing: TermulSpacing.space3,
                        runSpacing: TermulSpacing.space3,
                        children: [
                          FilterChipButton(
                            label: l.snippetCategoryNone,
                            selected: categoryId == null,
                            onPressed: () => setState(() => _categoryId = null),
                          ),
                          for (final c in categories)
                            FilterChipButton(
                              label: c.name,
                              selected: categoryId == c.id,
                              onPressed: () => setState(() => _categoryId = c.id),
                            ),
                        ],
                      ),
                    ),
                    _Section(
                      label: l.snippetFieldScope,
                      child: Wrap(
                        spacing: TermulSpacing.space3,
                        runSpacing: TermulSpacing.space3,
                        children: [
                          FilterChipButton(
                            label: l.snippetScopeAll,
                            selected: _hostId == null,
                            onPressed: () => setState(() => _hostId = null),
                          ),
                          if (widget.hosts.isNotEmpty)
                            DropdownPill(
                              label: _hostName ?? l.snippetScopeOneHost,
                              active: _hostId != null,
                              onPressed: () => _pickHost(l),
                            ),
                        ],
                      ),
                    ),
                    SwitchRow(
                      label: l.snippetFavoriteToggle,
                      value: _favorite,
                      onChanged: (v) => setState(() => _favorite = v),
                    ),
                    SwitchRow(
                      label: l.snippetDangerousToggle,
                      description: commandLooksDangerous(_command.text)
                          ? l.snippetDangerousDescAuto
                          : l.snippetDangerousDesc,
                      dangerTag: l.snippetDangerousTag,
                      value: _dangerous,
                      onChanged: (v) => setState(() => _dangerous = v),
                    ),
                    if (editing)
                      TermulButton(
                        label: l.actionDelete,
                        variant: TermulButtonVariant.danger,
                        onPressed: () => Navigator.of(context).pop(SnippetDeleteRequested(widget.existing!)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TermulSpacing.space7),
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
                      onPressed: _canSave ? _save : null,
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

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;

  /// Tombol di ujung kanan baris label (mis. kelola kategori).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TermulSpacing.space3,
      children: [
        if (trailing == null)
          Text(label, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted))
        else
          Row(
            children: [
              Expanded(
                child: Text(label, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
              ),
              trailing!,
            ],
          ),
        child,
      ],
    );
  }
}
