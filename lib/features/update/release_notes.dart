import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';

/// Catatan rilis dengan Markdown sebagian, sama dengan yang dirender TermUL desktop: heading `#`/`##`/`###`, bullet
/// `-`/`*`, `**tebal**`, dan `` `kode` ``. Tautan `[teks](url)` ditampilkan sebagai teksnya saja (aplikasi belum membuka
/// tautan luar). Baris lain tampil apa adanya.
class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes(this.notes, {super.key, this.maxLines});

  final String notes;

  /// Batas baris keseluruhan (bagian Pembaruan); null untuk sheet "Yang baru".
  final int? maxLines;

  static final _heading = RegExp(r'^(#{1,3})\s+(.*)$');
  static final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
  static final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\([^)]*\)');

  @override
  Widget build(BuildContext context) {
    final body = TermulText.bodySm.copyWith(color: TermulPalette.inkSoft, height: 1.45);
    final lines = notes.replaceAll('\r\n', '\n').split('\n');
    final shown = maxLines == null ? lines : lines.take(maxLines!).toList();
    final children = <Widget>[];
    for (final raw in shown) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        children.add(const SizedBox(height: TermulSpacing.space2));
        continue;
      }
      final h = _heading.firstMatch(line);
      if (h != null) {
        children.add(
          Semantics(
            header: true,
            child: Text.rich(_spans(h.group(2)!, body), style: body.copyWith(color: TermulPalette.ink, fontWeight: FontWeight.w600)),
          ),
        );
        continue;
      }
      final b = _bullet.firstMatch(line);
      if (b != null) {
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Text('•  ', style: body)),
              Expanded(child: Text.rich(_spans(b.group(1)!, body), style: body)),
            ],
          ),
        );
        continue;
      }
      children.add(Text.rich(_spans(line, body), style: body));
    }
    if (maxLines != null && lines.length > maxLines!) children.add(Text('…', style: body));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: TermulSpacing.space1, children: children);
  }

  static TextSpan _spans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w600, color: TermulPalette.ink)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: base.copyWith(fontFamily: TermulFonts.mono, fontSize: 12.5)));
      } else {
        spans.add(TextSpan(text: m.group(3)));
      }
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(children: spans);
  }
}

/// Sheet "Yang baru di `versi`" (desktop: Bantuan > Yang baru), tampil sekali setelah update dipakai.
Future<void> showWhatsNew(BuildContext context, {required String version, required String notes}) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius2xl)),
      side: BorderSide(color: TermulPalette.lineStrong),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(TermulSpacing.space7, TermulSpacing.space3, TermulSpacing.space3, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.whatsNewTitle(version),
                      style: TermulText.title.copyWith(color: TermulPalette.ink, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                TermulIconButton(
                  icon: TermulIconName.close,
                  label: l.actionClose,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey('whats-new'),
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space7,
                TermulSpacing.space1,
                TermulSpacing.space7,
                TermulSpacing.space8,
              ),
              child: ReleaseNotes(notes),
            ),
          ),
        ],
      ),
    ),
  );
}
