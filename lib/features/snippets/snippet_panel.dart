import 'package:flutter/material.dart';

import '../../core/models/snippet.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import 'snippet_danger.dart';

/// Panel snippet di bawah bilah tombol cepat terminal (tinggi tetap 240, menggantikan keyboard sistem selagi terbuka).
/// Satu baris per snippet yang berlaku untuk host ini: judul, baris pertama perintah, dan kata "berbahaya" bila perlu.
/// Ketuk menempel cepat lewat alur tempel terminal ([onPick]); tekan lama membuka detail ([onDetail]) untuk "Tempel &
/// jalankan" atau Salin. [onManage] membuka tab Snippet ("Kelola semua").
class SnippetPanel extends StatelessWidget {
  const SnippetPanel({
    super.key,
    required this.snippets,
    required this.onPick,
    required this.onDetail,
    required this.onManage,
  });

  final List<Snippet> snippets;
  final ValueChanged<Snippet> onPick;
  final ValueChanged<Snippet> onDetail;
  final VoidCallback onManage;

  static const height = 240.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(
        TermulSpacing.space6,
        TermulSpacing.space2,
        TermulSpacing.space6,
        TermulSpacing.space5,
      ),
      decoration: const BoxDecoration(
        color: TermulPalette.surface,
        border: Border(top: BorderSide(color: TermulPalette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.navSnippets,
                    style: TermulText.body.copyWith(color: TermulPalette.ink, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Pressable(
                onPressed: onManage,
                radius: TermulRadius.radiusMd,
                builder: (context, pressed) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space2),
                  child: Center(
                    widthFactor: 1,
                    child: Text(l.snippetPanelManage, style: TermulText.label.copyWith(color: TermulPalette.accent)),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: snippets.isEmpty
                ? Center(
                    child: Text(
                      l.snippetPickerEmpty,
                      textAlign: TextAlign.center,
                      style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: snippets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: TermulSpacing.space3),
                    itemBuilder: (context, i) => _Row(snippet: snippets[i], onPick: onPick, onDetail: onDetail),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.snippet, required this.onPick, required this.onDetail});

  final Snippet snippet;
  final ValueChanged<Snippet> onPick;
  final ValueChanged<Snippet> onDetail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dangerous = snippetIsDangerous(snippet);
    return Pressable(
      onPressed: () => onPick(snippet),
      onLongPress: () => onDetail(snippet),
      radius: TermulRadius.radiusLg,
      minHeight: 52,
      semanticLabel: snippet.title,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space3),
        decoration: BoxDecoration(
          color: pressed ? TermulPalette.surfaceRaised : TermulPalette.surface,
          borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
          border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
        ),
        child: Row(
          spacing: TermulSpacing.space4,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snippet.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermulText.body.copyWith(color: TermulPalette.ink, fontSize: 14),
                  ),
                  Text(
                    snippet.firstLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermulText.terminal.copyWith(color: TermulPalette.inkMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (dangerous) Text(l.snippetDangerousTag, style: TermulText.caption.copyWith(color: TermulPalette.bad)),
          ],
        ),
      ),
    );
  }
}
