import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';

enum HostStatus { online, offline, busy, idle }

/// Titik status. Warna tidak pernah berdiri sendiri: `ok` dan `bad` nyaris sama terang, jadi selalu ada kata.
/// [showLabel] false hanya bila kata yang sama sudah tampil di dekatnya (mis. di `HostRow`).
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.status,
    this.label,
    this.showLabel = true,
  });

  final HostStatus status;
  final String? label;
  final bool showLabel;

  static Color colorOf(HostStatus s) => switch (s) {
    HostStatus.online => TermulPalette.ok,
    HostStatus.offline => TermulPalette.bad,
    HostStatus.busy => TermulPalette.accent,
    HostStatus.idle => TermulPalette.inkMuted,
  };

  static String wordOf(AppLocalizations l, HostStatus s) => switch (s) {
    HostStatus.online => l.statusOnline,
    HostStatus.offline => l.statusOffline,
    HostStatus.busy => l.statusBusy,
    HostStatus.idle => l.statusIdle,
  };

  @override
  Widget build(BuildContext context) {
    final word = label ?? wordOf(AppLocalizations.of(context), status);
    final color = colorOf(status);
    return Semantics(
      label: word,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (showLabel) ...[
            const SizedBox(width: TermulSpacing.space3),
            Text(word, style: TermulText.terminalSm.copyWith(color: color)),
          ],
        ],
      ),
    );
  }
}
