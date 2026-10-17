import 'package:flutter/material.dart';

import '../../core/models/snippet.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_chip.dart';
import '../../shared/widgets/termul_icon.dart';
import 'snippet_danger.dart';

/// Kartu snippet di daftar: judul, bintang, baris pertama perintah, dan tag (kategori, cakupan, variabel, berbahaya).
class SnippetCard extends StatelessWidget {
  const SnippetCard({
    super.key,
    required this.snippet,
    required this.category,
    required this.scope,
    required this.onPressed,
  });

  final Snippet snippet;
  final String? category;
  final String scope;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final vars = snippet.variables.length;
    final risky = snippetIsDangerous(snippet);
    return Pressable(
      onPressed: onPressed,
      radius: TermulRadius.radiusXl,
      minHeight: TermulSize.rowComfy,
      semanticLabel: snippet.title,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space5),
        decoration: BoxDecoration(
          color: TermulPalette.surface,
          borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
          border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TermulSpacing.space3,
          children: [
            Row(
              spacing: TermulSpacing.space3,
              children: [
                Expanded(
                  child: Text(
                    snippet.title,
                    style: TermulText.body.copyWith(color: TermulPalette.ink, fontWeight: FontWeight.w500),
                  ),
                ),
                if (snippet.favorite)
                  TermulIcon(
                    TermulIconName.star,
                    size: 16,
                    color: TermulPalette.accent,
                    label: l.snippetFavoriteLabel,
                    filled: true,
                  ),
              ],
            ),
            Text(
              snippet.firstLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TermulText.terminal.copyWith(color: TermulPalette.inkMuted, fontSize: 12.5),
            ),
            Wrap(
              spacing: TermulSpacing.space3,
              runSpacing: TermulSpacing.space2,
              children: [
                if (category != null) TermulTag(category!),
                TermulTag(scope),
                if (vars > 0) TermulTag(l.snippetVarCount(vars), tone: TagTone.accent),
                if (risky) TermulTag(l.snippetDangerousTag, tone: TagTone.bad),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
