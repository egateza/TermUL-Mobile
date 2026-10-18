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
import '../sftp/sftp_link.dart';
import '../sftp/sftp_screen.dart' show openSftpSession;
import '../sftp/sftp_session_manager.dart';

/// Daftar sesi yang dibiarkan hidup di latar belakang ("Tetap terhubung"). Mengetuk sesi membukanya lagi untuk
/// dilanjutkan; beberapa sesi ke profil yang sama dibedakan nomor dan jam mulainya. Tab "Sesi" di `NavBar`
/// ([showBack] false); tombol kembali hanya bila dibuka sebagai layar tersendiri.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key, this.showBack = true});

  final bool showBack;

  static (HostStatus, String) statusOf(AppLocalizations l, SessionPhase phase) => switch (phase) {
    SessionPhase.connected => (HostStatus.online, l.terminalStatusConnected),
    SessionPhase.connecting => (HostStatus.busy, l.sessionsStatusConnecting),
    SessionPhase.reconnecting => (HostStatus.busy, l.terminalStatusReconnecting),
    SessionPhase.lost => (HostStatus.offline, l.terminalStatusLost),
    SessionPhase.needsAttention => (HostStatus.idle, l.sessionsStatusAttention),
  };

  static String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final Set<String> _expanded = {};

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

  Future<void> _confirmDisconnectSftp(BuildContext context, WidgetRef ref, SftpSession s) {
    final l = AppLocalizations.of(context);
    return showTermulSheet<void>(
      context,
      title: l.sessionsDisconnectTitle,
      child: Text(
        l.sessionsDisconnectBody(s.profile.name),
        style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
      ),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDisconnect,
      confirmIsDanger: true,
      onConfirm: () => ref.read(sftpSessionManagerProvider.notifier).release(s),
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
      onConfirm: () {
        ref.read(sessionManagerProvider.notifier).disconnectAllKept();
        ref.read(sftpSessionManagerProvider.notifier).disconnectAllKept();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final l = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);
    final sftp = ref.watch(sftpSessionManagerProvider);
    final total = sessions.length + sftp.length;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                widget.showBack ? TermulSpacing.space3 : TermulSpacing.space8,
                // Landscape: header lebih rendah supaya isi mendapat tinggi layar.
                landscape ? TermulSpacing.space1 : TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Row(
                children: [
                  if (widget.showBack) ...[
                    TermulIconButton(
                      icon: TermulIconName.chevronLeft,
                      label: l.actionBack,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: TermulSpacing.space3),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.sessionsTitle,
                        style: (landscape ? TermulText.h2 : TermulText.h1).copyWith(color: TermulPalette.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: total == 0
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
                        for (final group in _groups(sessions, sftp)) ...[
                          if (!group.isMulti)
                            _sessionItem(context, ref, group.items.single)
                          else
                            _MultiSessionGroup(
                              count: group.items.length,
                              expanded: _expanded.contains(group.groupId),
                              onToggle: () => setState(() {
                                if (!_expanded.add(group.groupId!)) _expanded.remove(group.groupId);
                              }),
                              onDisconnect: () => _confirmDisconnectGroup(context, ref, group),
                              children: _expanded.contains(group.groupId)
                                  ? [for (final item in group.items) _sessionItem(context, ref, item)]
                                  : const [],
                            ),
                          const SizedBox(height: TermulSpacing.space3),
                        ],
                        if (total > 1) ...[
                          const SizedBox(height: TermulSpacing.space5),
                          TermulButton(
                            label: l.sessionsDisconnectAll,
                            onPressed: () => _confirmDisconnectAll(context, ref, total),
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

  Widget _sessionItem(BuildContext context, WidgetRef ref, _KeptSession item) => item.terminal != null
      ? _SessionRow(
          controller: item.terminal!,
          onOpen: () => _open(context, item.terminal!),
          onDisconnect: () => _confirmDisconnect(context, item.terminal!),
        )
      : _SftpSessionRow(
          session: item.sftp!,
          onOpen: () => openSftpSession(context, ref, item.sftp!),
          onDisconnect: () => _confirmDisconnectSftp(context, ref, item.sftp!),
        );

  Future<void> _confirmDisconnectGroup(BuildContext context, WidgetRef ref, _SessionGroup group) {
    final l = AppLocalizations.of(context);
    return showTermulSheet<void>(
      context,
      title: l.sessionsDisconnectAllTitle(group.items.length),
      child: Text(l.sessionsDisconnectMultiBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDisconnect,
      confirmIsDanger: true,
      onConfirm: () {
        for (final item in group.items) {
          if (item.terminal case final c?) {
            ref.read(sessionManagerProvider.notifier).release(c);
          } else if (item.sftp case final s?) {
            ref.read(sftpSessionManagerProvider.notifier).release(s);
          }
        }
      },
    );
  }

  List<_SessionGroup> _groups(List<SessionController> terminals, List<SftpSession> sftp) {
    final byGroup = <String, List<_KeptSession>>{};
    for (final c in terminals) {
      byGroup.putIfAbsent(c.groupId, () => []).add(_KeptSession(terminal: c));
    }
    for (final s in sftp) {
      if (s.groupId != null) byGroup.putIfAbsent(s.groupId!, () => []).add(_KeptSession(sftp: s));
    }
    final groups = [
      for (final entry in byGroup.entries) _SessionGroup(groupId: entry.key, items: entry.value),
      for (final c in sftp)
        if (c.groupId == null) _SessionGroup(groupId: null, items: [_KeptSession(sftp: c)]),
    ];
    groups.sort(
      (a, b) => a.items
          .map((e) => e.startedAt)
          .reduce((x, y) => x.isBefore(y) ? x : y)
          .compareTo(b.items.map((e) => e.startedAt).reduce((x, y) => x.isBefore(y) ? x : y)),
    );
    return groups;
  }
}

class _KeptSession {
  _KeptSession({this.terminal, this.sftp}) : assert((terminal == null) != (sftp == null));
  final SessionController? terminal;
  final SftpSession? sftp;
  String get name => terminal?.profile.name ?? sftp!.profile.name;
  DateTime get startedAt => terminal?.startedAt ?? sftp!.startedAt;
}

class _SessionGroup {
  const _SessionGroup({required this.groupId, required this.items});
  final String? groupId;
  final List<_KeptSession> items;
  bool get isMulti => groupId != null && items.length > 1;
}

class _MultiSessionGroup extends StatelessWidget {
  const _MultiSessionGroup({
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.onDisconnect,
    required this.children,
  });
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDisconnect;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TermulCard(
          child: Row(
            children: [
              Expanded(
                child: Pressable(
                  onPressed: onToggle,
                  semanticLabel: l.sessionsMulti(count),
                  radius: TermulRadius.radiusMd,
                  minHeight: 56,
                  builder: (context, pressed) => Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: TermulSpacing.space2,
                          children: [
                            Text(
                              l.sessionsMulti(count),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TermulText.title.copyWith(
                                color: pressed ? TermulPalette.accent : TermulPalette.ink,
                              ),
                            ),
                            Text(
                              expanded ? l.sessionsMultiCollapse : l.sessionsMultiExpand,
                              style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more, color: TermulPalette.inkMuted),
                    ],
                  ),
                ),
              ),
              TermulIconButton(icon: TermulIconName.close, label: l.sessionsDisconnectAll, onPressed: onDisconnect),
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: TermulSpacing.space5, top: TermulSpacing.space2),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) const SizedBox(height: TermulSpacing.space2),
                ],
              ],
            ),
          ),
      ],
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

/// Sesi SFTP mandiri yang hidup di latar belakang: tanda "SFTP" di samping nama, status dengan kata yang sama dengan
/// sesi terminal.
class _SftpSessionRow extends StatelessWidget {
  const _SftpSessionRow({required this.session, required this.onOpen, required this.onDisconnect});

  final SftpSession session;
  final VoidCallback onOpen;
  final VoidCallback onDisconnect;

  static SessionPhase _phase(SftpLink link) {
    if (link.lost) {
      if (link.reconnecting) return SessionPhase.reconnecting;
      if (link.needsAuth) return SessionPhase.needsAttention;
      return SessionPhase.lost;
    }
    return link.service == null ? SessionPhase.connecting : SessionPhase.connected;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session.link,
      builder: (context, _) {
        final p = session.profile;
        final (status, word) = SessionsScreen.statusOf(l, _phase(session.link));
        final title = session.ordinal > 1 ? '${p.name} · ${l.sessionsNumber(session.ordinal)}' : p.name;
        final label = '$title · ${l.sessionsSftpTag}';
        return TermulCard(
          child: Row(
            children: [
              Expanded(
                child: Pressable(
                  onPressed: onOpen,
                  semanticLabel: l.sessionsOpenLabel(label, word),
                  radius: TermulRadius.radiusMd,
                  minHeight: 56,
                  builder: (context, pressed) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TermulSpacing.space2,
                    children: [
                      Row(
                        spacing: TermulSpacing.space3,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TermulText.title.copyWith(
                                color: pressed ? TermulPalette.accent : TermulPalette.ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(TermulRadius.radiusSm),
                              border: Border.all(color: TermulPalette.lineStrong),
                            ),
                            child: Text(
                              l.sessionsSftpTag,
                              style: TermulText.caption.copyWith(
                                fontFamily: TermulFonts.mono,
                                color: TermulPalette.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${p.username}@${p.host}:${p.port} · ${l.sessionsStarted(SessionsScreen._time(session.startedAt))}',
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
                label: l.sessionsDisconnectLabel(label),
                onPressed: onDisconnect,
              ),
            ],
          ),
        );
      },
    );
  }
}
