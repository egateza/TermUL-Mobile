import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/snippet.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_chip.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_text_field.dart';
import '../../shared/widgets/termul_toast.dart';
import 'snippet_category_sheet.dart' show snippetRingGutter;
import 'snippet_danger.dart';
import 'snippet_danger_sheet.dart';
import 'snippet_target.dart';

/// Hasil menutup sheet detail: pengguna memilih membuka editor atau menghapus snippet.
enum SnippetDetailResult { edit, delete }

/// Membuka detail [snippet]: isian variabel, pratinjau perintah, lalu tempel ke sesi, salin, atau edit. [meta] adalah
/// baris "Kategori · Cakupan" di bawah judul.
///
/// - [targets]: sesi terminal yang bisa dituju ("Kirim ke"). Kosong = hanya Salin.
/// - [canManage]: tampilkan Edit dan Hapus (tab Snippet); false di terminal, yang hanya memakai snippet.
/// - [toastBottomOffset]: jarak toast dari bawah supaya tidak menutup bilah tombol cepat di terminal.
Future<SnippetDetailResult?> showSnippetDetail(
  BuildContext context, {
  required Snippet snippet,
  required String meta,
  List<SnippetTarget> targets = const [],
  bool canManage = true,
  double toastBottomOffset = 0,
}) {
  return showModalBottomSheet<SnippetDetailResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
      side: BorderSide(color: TermulPalette.line),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
    builder: (_) => _DetailSheet(
      snippet: snippet,
      meta: meta,
      targets: targets,
      canManage: canManage,
      toastBottomOffset: toastBottomOffset,
    ),
  );
}

class _DetailSheet extends StatefulWidget {
  const _DetailSheet({
    required this.snippet,
    required this.meta,
    required this.targets,
    required this.canManage,
    required this.toastBottomOffset,
  });

  final Snippet snippet;
  final String meta;
  final List<SnippetTarget> targets;
  final bool canManage;
  final double toastBottomOffset;

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late final List<String> _names = widget.snippet.variables;
  late final Map<String, TextEditingController> _controllers = {
    for (final n in _names) n: TextEditingController(text: widget.snippet.defaults[n] ?? ''),
  };
  int _target = 0;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _values => {for (final e in _controllers.entries) e.key: e.value.text};

  bool get _ready => _names.every((n) => _controllers[n]!.text.isNotEmpty);

  String get _preview => Snippet.fill(widget.snippet.command, _values);

  bool get _dangerous => widget.snippet.dangerous || commandLooksDangerous(_preview);

  SnippetTarget? get _selected => widget.targets.isEmpty ? null : widget.targets[_target];

  void _copyTapped() {
    if (!_dangerous) {
      _copy();
      return;
    }
    showSnippetDangerSheet(
      context,
      command: _preview,
      confirmLabel: AppLocalizations.of(context).snippetDangerWarnConfirm,
      onConfirm: _copy,
    );
  }

  void _pasteTapped() {
    if (!_dangerous) {
      _send(run: false);
      return;
    }
    showSnippetDangerSheet(
      context,
      command: _preview,
      confirmLabel: AppLocalizations.of(context).snippetDangerWarnPaste,
      onConfirm: () => _send(run: false),
    );
  }

  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _preview;
    final navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    navigator.pop();
    showTermulToastOn(messenger, l.snippetCopied(text.length), bottomOffset: widget.toastBottomOffset);
  }

  /// Mengirim perintah ke sesi terpilih. [run] menambahkan Enter; hanya dipanggil untuk perintah yang tidak berbahaya.
  void _send({required bool run}) {
    final target = _selected;
    if (target == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    target.send(_preview, run: run);
    navigator.pop();
    showTermulToastOn(
      messenger,
      run ? l.snippetRan(target.label) : l.snippetPasted(target.label),
      bottomOffset: widget.toastBottomOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final risky = _dangerous;
    final ready = _ready;
    final target = _selected;
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(widget.snippet.title, style: TermulText.h2.copyWith(color: TermulPalette.ink)),
                        ),
                        Text(widget.meta, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                      ],
                    ),
                  ),
                  if (widget.canManage)
                    TermulIconButton(
                      icon: TermulIconName.trash,
                      label: l.actionDelete,
                      onPressed: () => Navigator.of(context).pop(SnippetDetailResult.delete),
                    ),
                  TermulIconButton(
                    icon: TermulIconName.close,
                    label: l.actionClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TermulSpacing.space5),
            Flexible(
              child: SingleChildScrollView(
                // Ruang untuk cincin fokus isian (4 px di luar tepinya) supaya tidak terpotong tepi area gulir.
                padding: const EdgeInsets.all(snippetRingGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TermulSpacing.space5,
                  children: [
                    for (final n in _names)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: TermulSpacing.space2),
                            child: Text(
                              n,
                              style: TermulText.terminal.copyWith(color: TermulPalette.accent, fontSize: 12.5),
                            ),
                          ),
                          TermulTextField(
                            label: n,
                            hideLabel: true,
                            controller: _controllers[n],
                            placeholder: l.snippetDetailVariable,
                            mono: true,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    Container(
                      padding: const EdgeInsets.all(TermulSpacing.space5),
                      decoration: BoxDecoration(
                        color: TermulPalette.ground,
                        borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
                        border: Border.all(color: TermulPalette.line),
                      ),
                      child: SelectableText(
                        _preview,
                        style: TermulText.terminal.copyWith(color: TermulPalette.inkSoft, fontSize: 13, height: 1.5),
                      ),
                    ),
                    if (risky) TermulBanner(tone: BannerTone.risk, child: Text(l.snippetDetailRisky)),
                    if (!ready)
                      Text(l.snippetDetailNotReady, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                    if (widget.targets.isEmpty && widget.canManage)
                      Text(l.snippetNoTargets, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                    if (widget.targets.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: TermulSpacing.space3,
                        children: [
                          Text(l.snippetTargetLabel, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                          Wrap(
                            spacing: TermulSpacing.space3,
                            runSpacing: TermulSpacing.space3,
                            children: [
                              for (var i = 0; i < widget.targets.length; i++)
                                FilterChipButton(
                                  label: widget.targets[i].label,
                                  selected: _target == i,
                                  onPressed: () => setState(() => _target = i),
                                ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TermulSpacing.space7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: snippetRingGutter),
              child: target == null ? _copyOnlyButtons(l, ready) : _targetButtons(l, ready, risky, target),
            ),
          ],
        ),
      ),
    );
  }

  /// Tanpa sesi tujuan: Edit (bila boleh) dan Salin sebagai tombol utama.
  Widget _copyOnlyButtons(AppLocalizations l, bool ready) => Row(
    children: [
      if (widget.canManage) ...[
        Expanded(
          flex: 2,
          child: TermulButton(
            label: l.snippetDetailEdit,
            size: TermulButtonSize.lg,
            onPressed: () => Navigator.of(context).pop(SnippetDetailResult.edit),
          ),
        ),
        const SizedBox(width: TermulSpacing.space3),
      ],
      Expanded(
        flex: 3,
        child: TermulButton(
          label: l.snippetDetailCopy,
          icon: TermulIconName.copy,
          size: TermulButtonSize.lg,
          variant: TermulButtonVariant.primary,
          onPressed: ready ? _copyTapped : null,
        ),
      ),
    ],
  );

  /// Dengan sesi tujuan: Tempel ke {sesi} sebagai tombol utama; Tempel & jalankan (nonaktif untuk perintah
  /// berbahaya), Salin, dan Edit sebagai tombol biasa.
  Widget _targetButtons(AppLocalizations l, bool ready, bool risky, SnippetTarget target) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TermulSpacing.space3,
    children: [
      TermulButton(
        label: l.snippetPasteTo(target.label),
        size: TermulButtonSize.lg,
        variant: TermulButtonVariant.primary,
        onPressed: ready ? _pasteTapped : null,
      ),
      Row(
        spacing: TermulSpacing.space3,
        children: [
          Expanded(
            flex: 2,
            child: TermulButton(label: l.snippetPasteRun, onPressed: ready && !risky ? () => _send(run: true) : null),
          ),
          Expanded(
            child: TermulButton(label: l.snippetDetailCopy, onPressed: ready ? _copyTapped : null),
          ),
        ],
      ),
      if (widget.canManage)
        TermulButton(label: l.snippetDetailEdit, onPressed: () => Navigator.of(context).pop(SnippetDetailResult.edit)),
    ],
  );
}
