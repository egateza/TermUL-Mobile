import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/auth_method.dart';
import '../../core/models/host_profile.dart';
import '../../core/models/profile_snapshot.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../hosts/host_list_model.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_text_field.dart';
import '../connect/session_controller.dart';
import '../connect/session_manager.dart';
import '../sftp/sftp_link.dart';
import '../sftp/sftp_session_manager.dart';

enum SessionGroupKind { terminal, sftp }

class SessionGroupChoice {
  const SessionGroupChoice(this.profile, this.kind);
  final HostProfile profile;
  final SessionGroupKind kind;
}

Future<SessionGroupChoice?> pickSessionGroupMember(BuildContext context, WidgetRef ref) async {
  final snapshot = ref.read(hostSnapshotProvider);
  if (snapshot.profiles.isEmpty) return null;
  return showModalBottomSheet<SessionGroupChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TermulPalette.surface,
    barrierColor: TermulPalette.scrim,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
      side: BorderSide(color: TermulPalette.line),
    ),
    builder: (_) => _SessionGroupPicker(snapshot: snapshot),
  );
}

class _SessionGroupPicker extends StatefulWidget {
  const _SessionGroupPicker({required this.snapshot});

  final ProfileSnapshot snapshot;

  @override
  State<_SessionGroupPicker> createState() => _SessionGroupPickerState();
}

class _SessionGroupPickerState extends State<_SessionGroupPicker> {
  final _search = TextEditingController();
  final Set<String> _collapsed = {};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = buildHostGroups(widget.snapshot, query: _query);
    final searching = _query.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TermulSpacing.space5,
          TermulSpacing.space4,
          TermulSpacing.space5,
          TermulSpacing.space5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: TermulPalette.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: TermulSpacing.space3),
            Row(
              children: [
                Expanded(
                  child: Text(l.sessionsAdd, style: TermulText.h2.copyWith(color: TermulPalette.ink)),
                ),
                TermulIconButton(
                  icon: TermulIconName.close,
                  label: l.actionClose,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l.sessionsAddHint, style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted)),
            ),
            const SizedBox(height: TermulSpacing.space4),
            TermulTextField(
              label: l.hostsSearchLabel,
              hideLabel: true,
              icon: TermulIconName.search,
              placeholder: l.hostsSearchPlaceholder,
              clearLabel: l.actionClearSearch,
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: TermulSpacing.space3),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        l.hostsNoMatch,
                        textAlign: TextAlign.center,
                        style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
                      ),
                    )
                  : ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
                      children: [
                        for (final group in groups) ...[
                          _PickerGroupHeader(
                            name: group.path.isEmpty ? l.hostsRootGroup : group.path,
                            count: group.hosts.length,
                            expanded: searching || !_collapsed.contains(group.path),
                            onPressed: () => setState(() {
                              if (!_collapsed.add(group.path)) _collapsed.remove(group.path);
                            }),
                          ),
                          if (searching || !_collapsed.contains(group.path))
                            for (final profile in group.hosts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: TermulSpacing.space2),
                                child: _PickerHost(
                                  profile: profile,
                                  onTerminal: () =>
                                      Navigator.pop(context, SessionGroupChoice(profile, SessionGroupKind.terminal)),
                                  onSftp: profile.authMethod == AuthMethod.agent
                                      ? null
                                      : () =>
                                            Navigator.pop(context, SessionGroupChoice(profile, SessionGroupKind.sftp)),
                                ),
                              ),
                          const SizedBox(height: TermulSpacing.space2),
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

class _PickerGroupHeader extends StatelessWidget {
  const _PickerGroupHeader({required this.name, required this.count, required this.expanded, required this.onPressed});

  final String name;
  final int count;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: onPressed,
    semanticLabel: '${name.toUpperCase()}, $count',
    toggled: expanded,
    builder: (context, pressed) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
      child: SizedBox(
        height: TermulSize.tapMin,
        child: Row(
          children: [
            Transform.rotate(
              angle: expanded ? 0 : -1.5708,
              child: const TermulIcon(TermulIconName.chevronDown, size: 16, color: TermulPalette.inkMuted),
            ),
            const SizedBox(width: TermulSpacing.space4),
            Expanded(
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TermulText.overline.copyWith(color: pressed ? TermulPalette.accent : TermulPalette.inkMuted),
              ),
            ),
            Text('$count', style: TermulText.overline.copyWith(color: TermulPalette.inkMuted)),
          ],
        ),
      ),
    ),
  );
}

class _PickerHost extends StatelessWidget {
  const _PickerHost({required this.profile, required this.onTerminal, required this.onSftp});

  final HostProfile profile;
  final VoidCallback onTerminal;
  final VoidCallback? onSftp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TermulSpacing.space5,
        TermulSpacing.space4,
        TermulSpacing.space5,
        TermulSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: TermulPalette.surface,
        borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
        border: Border.all(color: TermulPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TermulText.title.copyWith(color: TermulPalette.ink),
          ),
          const SizedBox(height: TermulSpacing.space1),
          Text(
            profile.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted),
          ),
          const SizedBox(height: TermulSpacing.space3),
          Row(
            children: [
              Expanded(
                child: _PickerKindButton(
                  icon: TermulIconName.terminal,
                  label: l.settingsTerminalSection,
                  onPressed: onTerminal,
                ),
              ),
              if (onSftp != null) ...[
                const SizedBox(width: TermulSpacing.space2),
                Expanded(
                  child: _PickerKindButton(icon: TermulIconName.sftp, label: l.sessionsSftpTag, onPressed: onSftp!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerKindButton extends StatelessWidget {
  const _PickerKindButton({required this.icon, required this.label, required this.onPressed});

  final TermulIconName icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: TermulSize.tapMin,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: TermulIcon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: TermulPalette.ink,
        side: const BorderSide(color: TermulPalette.lineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TermulRadius.radiusLg)),
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space2),
        textStyle: TermulText.label,
      ),
    ),
  );
}

class SessionGroupBar extends ConsumerWidget {
  const SessionGroupBar({
    super.key,
    required this.groupId,
    required this.activeKey,
    required this.onTerminal,
    required this.onSftp,
    required this.onAdd,
  });

  final String groupId;
  final String activeKey;
  final ValueChanged<SessionController> onTerminal;
  final ValueChanged<SftpSession> onSftp;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionManagerProvider);
    ref.watch(sftpSessionManagerProvider);
    final members = <_GroupMember>[
      for (final c in ref.read(sessionManagerProvider.notifier).forGroup(groupId)) _GroupMember.terminal(c),
      for (final s in ref.read(sftpSessionManagerProvider.notifier).forGroup(groupId)) _GroupMember.sftp(s),
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (members.isEmpty) return const SizedBox.shrink();
    final visible = members.length <= 3 ? members : members.take(3).toList();
    final hiddenCount = members.length - visible.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(TermulSpacing.space5, 0, TermulSpacing.space5, TermulSpacing.space3),
      child: Row(
        children: [
          for (final member in visible)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: TermulSpacing.space2),
                child: _SessionChip(member: member, active: member.key == activeKey, onTap: () => _open(member)),
              ),
            ),
          if (members.length >= 3) _OverflowButton(count: hiddenCount, onTap: () => _showAll(context, ref, members)),
          if (members.length < 3) ...[
            const SizedBox(width: TermulSpacing.space2),
            TermulIconButton(
              icon: TermulIconName.plus,
              label: AppLocalizations.of(context).sessionsAdd,
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }

  void _open(_GroupMember member) {
    if (member.terminal != null) onTerminal(member.terminal!);
    if (member.sftp != null) onSftp(member.sftp!);
  }

  Future<void> _showAll(BuildContext context, WidgetRef ref, List<_GroupMember> members) async {
    final result = await showModalBottomSheet<_GroupMemberAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TermulPalette.surface,
      barrierColor: TermulPalette.scrim,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .84),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TermulRadius.radius3xl)),
        side: BorderSide(color: TermulPalette.line),
      ),
      builder: (_) => _AllGroupSessions(
        groupId: groupId,
        activeKey: activeKey,
        onOpen: (m) => Navigator.of(context).pop(_GroupMemberAction.open(m)),
        onAdd: () => Navigator.of(context).pop(const _GroupMemberAction.add()),
        onRemove: (m) => _confirmRemove(context, ref, m),
      ),
    );
    if (result == null || !context.mounted) return;
    if (result.add) {
      onAdd();
      return;
    }
    if (result.member != null) _open(result.member!);
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, _GroupMember member) async {
    final l = AppLocalizations.of(context);
    var confirmed = false;
    await showTermulSheet<void>(
      context,
      title: l.sessionsDisconnectTitle,
      child: Text(
        member.sftp != null ? l.sessionsDisconnectSftpBody : l.sessionsDisconnectBody(member.profile.name),
        style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
      ),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDisconnect,
      confirmIsDanger: true,
      onConfirm: () {
        confirmed = true;
        if (member.terminal case final c?) ref.read(sessionManagerProvider.notifier).release(c);
        if (member.sftp case final s?) ref.read(sftpSessionManagerProvider.notifier).release(s);
      },
    );
    if (confirmed && member.key == activeKey && context.mounted) {
      final navigator = Navigator.of(context);
      navigator.pop(); // daftar sesi
      if (context.mounted) navigator.pop(); // layar terminal atau SFTP yang sesi aktifnya ditutup
    }
  }
}

class _GroupMember {
  const _GroupMember.terminal(SessionController value) : terminal = value, sftp = null;
  const _GroupMember.sftp(SftpSession value) : terminal = null, sftp = value;
  final SessionController? terminal;
  final SftpSession? sftp;
  HostProfile get profile => terminal?.profile ?? sftp!.profile;
  DateTime get startedAt => terminal?.startedAt ?? sftp!.startedAt;
  String get key => terminal != null ? 't-${terminal!.id}' : 's-${sftp!.id}';
  bool get isSftp => sftp != null;
  String get status => terminal != null ? _terminalStatus(terminal!.phase) : _sftpStatus(sftp!.link);
  Color get statusColor =>
      status == 'connected' ? TermulPalette.ok : (status == 'lost' ? TermulPalette.bad : TermulPalette.inkMuted);
  static String _terminalStatus(SessionPhase phase) => switch (phase) {
    SessionPhase.connected => 'connected',
    SessionPhase.connecting || SessionPhase.reconnecting => 'connecting',
    SessionPhase.needsAttention => 'attention',
    SessionPhase.lost => 'lost',
  };
  static String _sftpStatus(SftpLink link) =>
      link.needsAuth ? 'attention' : (link.lost ? 'lost' : (link.service == null ? 'connecting' : 'connected'));
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.member, required this.active, required this.onTap});
  final _GroupMember member;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: member.profile.name,
    triggerMode: TooltipTriggerMode.longPress,
    child: Pressable(
      onPressed: onTap,
      semanticLabel: member.profile.name,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
        decoration: BoxDecoration(
          color: TermulPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
          border: Border.all(color: active || pressed ? TermulPalette.accent : TermulPalette.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: member.statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: TermulSpacing.space2),
            Flexible(
              child: Text(
                member.profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TermulText.caption.copyWith(color: TermulPalette.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverflowButton extends StatelessWidget {
  const _OverflowButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: onTap,
    semanticLabel: 'Semua sesi, $count lainnya',
    builder: (context, pressed) => Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
      decoration: BoxDecoration(
        color: TermulPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
        border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const TermulIcon(TermulIconName.chevronsRight, size: 18),
          const SizedBox(width: 4),
          if (count > 0) Text('+$count', style: TermulText.caption.copyWith(color: TermulPalette.ink)),
        ],
      ),
    ),
  );
}

class _AllGroupSessions extends ConsumerWidget {
  const _AllGroupSessions({
    required this.groupId,
    required this.activeKey,
    required this.onOpen,
    required this.onAdd,
    required this.onRemove,
  });
  final String groupId;
  final String activeKey;
  final ValueChanged<_GroupMember> onOpen;
  final VoidCallback onAdd;
  final ValueChanged<_GroupMember> onRemove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionManagerProvider);
    ref.watch(sftpSessionManagerProvider);
    final members = <_GroupMember>[
      for (final c in ref.read(sessionManagerProvider.notifier).forGroup(groupId)) _GroupMember.terminal(c),
      for (final s in ref.read(sftpSessionManagerProvider.notifier).forGroup(groupId)) _GroupMember.sftp(s),
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TermulSpacing.space5,
          TermulSpacing.space4,
          TermulSpacing.space5,
          TermulSpacing.space5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Semua sesi (${members.length})',
                    style: TermulText.h2.copyWith(color: TermulPalette.ink),
                  ),
                ),
                TermulIconButton(
                  icon: TermulIconName.close,
                  label: l.actionClose,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: TermulSpacing.space3),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, _) => const SizedBox(height: TermulSpacing.space2),
                itemBuilder: (context, i) {
                  final member = members[i];
                  final active = member.key == activeKey;
                  final statusText = switch (member.status) {
                    'connected' => l.statusOnline,
                    'connecting' => l.sessionsStatusConnecting,
                    'attention' => l.sessionsStatusAttention,
                    _ => l.statusOffline,
                  };
                  return Container(
                    decoration: BoxDecoration(
                      color: TermulPalette.surfaceRaised,
                      borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
                      border: Border.all(color: active ? TermulPalette.accent : TermulPalette.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Tooltip(
                            message: member.profile.name,
                            triggerMode: TooltipTriggerMode.longPress,
                            child: Pressable(
                              onPressed: () => onOpen(member),
                              semanticLabel: member.profile.name,
                              builder: (_, _) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: TermulSpacing.space3,
                                  vertical: TermulSpacing.space3,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(color: member.statusColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: TermulSpacing.space3),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${member.profile.name}${member.isSftp ? ' \u00b7 SFTP' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TermulText.body.copyWith(color: TermulPalette.ink),
                                          ),
                                          Text(
                                            statusText,
                                            style: TermulText.caption.copyWith(color: member.statusColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (active)
                                      Text('Aktif', style: TermulText.caption.copyWith(color: TermulPalette.accent)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        TermulIconButton(
                          icon: TermulIconName.close,
                          label: l.sessionsDisconnectLabel(member.profile.name),
                          onPressed: () => onRemove(member),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: TermulSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const TermulIcon(TermulIconName.plus, size: 18),
                label: Text(l.sessionsAdd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMemberAction {
  const _GroupMemberAction.add() : add = true, member = null;
  const _GroupMemberAction.open(this.member) : add = false;
  final bool add;
  final _GroupMember? member;
}
