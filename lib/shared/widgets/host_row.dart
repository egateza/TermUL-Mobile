import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import 'pressable.dart';
import 'status_dot.dart';

/// Baris daftar satu host: titik status, nama, `user@alamat`, dan status dengan kata. Seluruh baris adalah
/// target sentuh (minimal 64 px). Status adalah cache; `null` berarti belum pernah diperiksa.
class HostRow extends StatelessWidget {
  const HostRow({
    super.key,
    required this.name,
    required this.target,
    required this.onPressed,
    this.status,
    this.latencyMs,
    this.onLongPress,
  });

  final String name;
  final String target;
  final HostStatus? status;
  final int? latencyMs;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (text, color, dot) = switch (status) {
      HostStatus.online => (
        latencyMs == null ? l.statusOnline : l.hostStatusOnlineMs(latencyMs!),
        TermulPalette.ok,
        HostStatus.online,
      ),
      HostStatus.offline => (l.hostStatusUnreachable, TermulPalette.bad, HostStatus.offline),
      HostStatus.busy => (l.statusBusy, TermulPalette.accent, HostStatus.busy),
      HostStatus.idle || null => (l.hostStatusNotChecked, TermulPalette.inkMuted, HostStatus.idle),
    };
    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
        onPressed: onPressed,
        semanticLabel: '$name, $target, $text',
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
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.title.copyWith(color: TermulPalette.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TermulSpacing.space3),
              Text(text, style: TermulText.terminalSm.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
