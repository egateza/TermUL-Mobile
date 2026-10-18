import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import 'pressable.dart';
import 'status_dot.dart';
import 'termul_icon.dart';

/// Baris daftar satu host: titik status, nama, `user@alamat`, dan keterangan pemakaian/koneksi dengan kata.
/// Seluruh baris adalah target sentuh (minimal 64 px). [lastUsedAt] hanya terisi setelah koneksi berhasil.
class HostRow extends StatelessWidget {
  const HostRow({
    super.key,
    required this.name,
    required this.target,
    required this.onPressed,
    this.status,
    this.latencyMs,
    this.onLongPress,
    this.actionsLabel,
    this.favorite = false,
    this.lastUsedAt,
  });

  final String name;
  final String target;
  final HostStatus? status;
  final int? latencyMs;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Nama aksi semantik untuk [onLongPress] (pembaca layar tidak bisa menahan lama).
  final String? actionsLabel;

  /// Host favorit: bintang beraksen di sebelah nama (kata "Favorit" untuk pembaca layar).
  final bool favorite;
  final DateTime? lastUsedAt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (defaultText, color, dot) = switch (status) {
      HostStatus.online => (
        latencyMs == null ? l.statusOnline : l.hostStatusOnlineMs(latencyMs!),
        TermulPalette.ok,
        HostStatus.online,
      ),
      HostStatus.offline => (l.hostStatusUnreachable, TermulPalette.bad, HostStatus.offline),
      HostStatus.busy => (l.statusBusy, TermulPalette.accent, HostStatus.busy),
      HostStatus.idle || null => (l.hostStatusNotChecked, TermulPalette.inkMuted, HostStatus.idle),
    };
    final text = lastUsedAt == null ? defaultText : _lastUsedLabel(lastUsedAt!, DateTime.now());
    return Semantics(
      customSemanticsActions: {
        if (onLongPress != null && actionsLabel != null) CustomSemanticsAction(label: actionsLabel!): onLongPress!,
      },
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Pressable(
          onPressed: onPressed,
          semanticLabel: favorite ? '$name, ${l.hostFavoriteLabel}, $target, $text' : '$name, $target, $text',
          radius: TermulRadius.radiusXl,
          minHeight: TermulSize.rowComfy,
          builder: (context, pressed) => Container(
            constraints: const BoxConstraints(minHeight: TermulSize.rowComfy),
            padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space4),
            decoration: BoxDecoration(
              color: TermulPalette.surface,
              borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
              border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
            ),
            child: Row(
              children: [
                StatusDot(status: dot, showLabel: false),
                const SizedBox(width: TermulSpacing.space6),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TermulText.title.copyWith(color: TermulPalette.ink),
                            ),
                          ),
                          if (favorite) ...[
                            const SizedBox(width: TermulSpacing.space2),
                            const TermulIcon(TermulIconName.star, size: 14, color: TermulPalette.accent, filled: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        target,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted, fontSize: 12.5),
                      ),
                      if (lastUsedAt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (lastUsedAt == null) ...[
                  const SizedBox(width: TermulSpacing.space3),
                  Text(text, style: TermulText.terminalSm.copyWith(color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _lastUsedLabel(DateTime usedAt, DateTime now) {
    final elapsed = now.difference(usedAt);
    final value = elapsed.isNegative ? Duration.zero : elapsed;
    String relative;
    if (value.inSeconds < 60) {
      final seconds = value.inSeconds;
      relative = seconds <= 1 ? 'beberapa detik yang lalu' : '$seconds detik yang lalu';
    } else if (value.inMinutes < 60) {
      relative = '${value.inMinutes} menit yang lalu';
    } else if (value.inHours < 24) {
      relative = '${value.inHours} jam yang lalu';
    } else {
      final local = usedAt.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      relative =
          '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
    }
    return 'Terakhir digunakan $relative';
  }
}
