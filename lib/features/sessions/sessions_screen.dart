import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/status_dot.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_card.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../connect/connect_screen.dart';
import '../connect/session_controller.dart';
import '../connect/session_manager.dart';

/// Daftar sesi yang dibiarkan hidup di latar belakang ("Tetap terhubung"). Mengetuk sesi membukanya lagi untuk
/// dilanjutkan; beberapa sesi ke profil yang sama dibedakan nomor dan jam mulainya. Sementara `NavBar` belum ada,
/// layar ini dibuka dari ikon di header daftar host.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  static (HostStatus, String) statusOf(AppLocalizations l, SessionPhase phase) => switch (phase) {
    SessionPhase.connected => (HostStatus.online, l.terminalStatusConnected),
    SessionPhase.connecting => (HostStatus.busy, l.sessionsStatusConnecting),
    SessionPhase.reconnecting => (HostStatus.busy, l.terminalStatusReconnecting),
    SessionPhase.lost => (HostStatus.offline, l.terminalStatusLost),
    SessionPhase.needsAttention => (HostStatus.idle, l.sessionsStatusAttention),
  };

  static String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

  void _open(BuildContext context, SessionController c) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ConnectScreen(profile: c.profile, controller: c),
      ),
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, SessionController c) {
    final l = AppLocalizations.of(context);
    return showTermulSheet<void>(
      context,
      title: l.sessionsDisconnectTitle,
      child: Text(
        l.sessionsDisconnectBody(c.profile.name),
        style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
      ),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDisconnect,
      confirmIsDanger: true,
      onConfirm: c.disconnectFromNotification,
    );
  }

  Future<void> _confirmDisconnectAll(BuildContext context, WidgetRef ref, int count) {
    final l = AppLocalizations.of(context);
    return showTermulSheet<void>(
      context,
      title: l.sessionsDisconnectAllTitle(count),
      child: Text(l.sessionsDisconnectAllBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDisconnect,
      confirmIsDanger: true,
      onConfirm: ref.read(sessionManagerProvider.notifier).disconnectAllKept,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space3,
                TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Row(
                children: [
                  TermulIconButton(
                    icon: TermulIconName.chevronLeft,
                    label: l.actionBack,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: TermulSpacing.space3),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.sessionsTitle, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(TermulSpacing.space8),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: TermulSpacing.space3,
                          children: [
                            Text(
                              l.sessionsEmptyTitle,
                              textAlign: TextAlign.center,
                              style: TermulText.title.copyWith(color: TermulPalette.ink),
                            ),
                            Text(
                              l.sessionsEmptyBody,
                              textAlign: TextAlign.center,
                              style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        TermulSpacing.space5,
                        TermulSpacing.space3,
                        TermulSpacing.space5,
                        TermulSpacing.space8,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            TermulSpacing.space3,
                            0,
                            TermulSpacing.space3,
                            TermulSpacing.space5,
                          ),
                          child: Text(
                            l.sessionsHint,
                            style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                          ),
                        ),
                        for (final c in sessions) ...[
                          _SessionRow(
                            controller: c,
                            onOpen: () => _open(context, c),
                            onDisconnect: () => _confirmDisconnect(context, c),
                          ),
                          const SizedBox(height: TermulSpacing.space3),
                        ],
                        if (sessions.length > 1) ...[
                          const SizedBox(height: TermulSpacing.space5),
                          TermulButton(
                            label: l.sessionsDisconnectAll,
                            onPressed: () => _confirmDisconnectAll(context, ref, sessions.length),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.controller, required this.onOpen, required this.onDisconnect});

  final SessionController controller;
  final VoidCallback onOpen;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final p = controller.profile;
        final (status, word) = SessionsScreen.statusOf(l, controller.phase);
        final title = controller.ordinal > 1 ? '${p.name} · ${l.sessionsNumber(controller.ordinal)}' : p.name;
        // Area membuka dan tombol Putuskan bersaudara (bukan bersarang) supaya keduanya terbaca dan bisa dipilih
        // pembaca layar secara terpisah.
        return TermulCard(
          child: Row(
            children: [
              Expanded(
                child: Pressable(
                  onPressed: onOpen,
                  semanticLabel: l.sessionsOpenLabel(title, word),
                  radius: TermulRadius.radiusMd,
                  minHeight: 56,
                  builder: (context, pressed) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TermulSpacing.space2,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TermulText.title.copyWith(color: pressed ? TermulPalette.accent : TermulPalette.ink),
                      ),
                      Text(
                        '${p.username}@${p.host}:${p.port} · ${l.sessionsStarted(SessionsScreen._time(controller.startedAt))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted),
                      ),
                      StatusDot(status: status, label: word),
                    ],
                  ),
                ),
              ),
              TermulIconButton(
                icon: TermulIconName.close,
                label: l.sessionsDisconnectLabel(title),
                onPressed: onDisconnect,
              ),
            ],
          ),
        );
      },
    );
  }
}
