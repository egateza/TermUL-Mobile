import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/auth_method.dart';
import '../../core/models/host_profile.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/host_row.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_action_sheet.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_chip.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_text_field.dart';
import '../../shared/widgets/termul_toast.dart';
import 'host_form_screen.dart';
import 'host_list_model.dart';

/// Layar utama: daftar host berkelompok dengan pencarian dan filter. [onConnect] dipanggil untuk host yang
/// siap disambung; host bermetode agen SSH (dari desktop) lebih dulu diarahkan ke form untuk dilengkapi.
class HostListScreen extends ConsumerStatefulWidget {
  const HostListScreen({super.key, required this.onConnect});

  final void Function(BuildContext context, HostProfile profile) onConnect;

  @override
  ConsumerState<HostListScreen> createState() => _HostListScreenState();
}

class _HostListScreenState extends ConsumerState<HostListScreen> {
  final _search = TextEditingController();
  bool _hideHostsBanner = false;
  bool _hideKnownBanner = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm([HostProfile? existing]) {
    Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => HostFormScreen(existing: existing)));
  }

  void _open(HostProfile p) {
    final l = AppLocalizations.of(context);
    if (p.authMethod == AuthMethod.agent) {
      showTermulSheet<void>(
        context,
        title: l.agentNeedsCompletionTitle,
        child: Text(l.agentNeedsCompletionBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
        cancelLabel: l.actionCancel,
        confirmLabel: l.actionComplete,
        onConfirm: () => _openForm(p),
      );
      return;
    }
    widget.onConnect(context, p);
  }

  void _showActions(HostProfile p) {
    final l = AppLocalizations.of(context);
    final fav = ref.read(hostSnapshotProvider).isFavorite(p.id);
    showTermulActions(
      context,
      title: l.hostActionsTitle(p.name),
      actions: [
        SheetAction(label: l.actionConnect, icon: TermulIconName.terminal, onSelected: () => _open(p)),
        SheetAction(label: l.actionEdit, icon: TermulIconName.edit, onSelected: () => _openForm(p)),
        SheetAction(
          label: fav ? l.actionUnfavorite : l.actionFavorite,
          icon: TermulIconName.star,
          onSelected: () => ref.read(hostRepositoryProvider).setFavorite(p.id, favorite: !fav),
        ),
        SheetAction(
          label: l.actionDelete,
          icon: TermulIconName.trash,
          danger: true,
          onSelected: () => _confirmDelete(p),
        ),
      ],
    );
  }

  void _confirmDelete(HostProfile p) {
    final l = AppLocalizations.of(context);
    showTermulSheet<void>(
      context,
      title: l.deleteHostTitle(p.name),
      child: Text(l.deleteHostBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDelete,
      confirmIsDanger: true,
      onConfirm: () => _delete(p),
    );
  }

  Future<void> _delete(HostProfile p) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(hostServiceProvider).deleteHost(p.id);
      if (!mounted) return;
      setState(() => _error = null);
      messenger.hideCurrentSnackBar();
      showTermulToast(context, l.hostDeleted(p.name));
    } on Object {
      if (mounted) setState(() => _error = l.deleteHostFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final snapshot = ref.watch(hostSnapshotProvider);
    final listState = ref.watch(hostListProvider);
    final report = ref.watch(bootReportProvider);
    final groups = buildHostGroups(snapshot, query: listState.query, filter: listState.filter);
    final searching = listState.query.trim().isNotEmpty;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    final banners = <Widget>[
      if (report.hosts.hadCorruptFile && !_hideHostsBanner)
        TermulBanner(
          tone: BannerTone.warn,
          title: l.corruptHostsTitle,
          action: TermulButton(
            label: l.actionClose,
            size: TermulButtonSize.sm,
            expand: false,
            onPressed: () => setState(() => _hideHostsBanner = true),
          ),
          child: Text(l.corruptHostsBody(_fileName(report.hosts.quarantinedPath!))),
        ),
      if (report.knownHosts.hadCorruptFile && !_hideKnownBanner)
        TermulBanner(
          tone: BannerTone.risk,
          title: l.corruptKnownTitle,
          action: TermulButton(
            label: l.actionClose,
            size: TermulButtonSize.sm,
            expand: false,
            onPressed: () => setState(() => _hideKnownBanner = true),
          ),
          child: Text(l.corruptKnownBody(_fileName(report.knownHosts.quarantinedPath!))),
        ),
      if (_error != null)
        TermulBanner(
          tone: BannerTone.risk,
          action: TermulButton(
            label: l.actionClose,
            size: TermulButtonSize.sm,
            expand: false,
            onPressed: () => setState(() => _error = null),
          ),
          child: Text(_error!),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (landscape)
              // Landscape: judul, pencarian, filter, dan tombol tambah dalam satu baris supaya daftar mendapat tinggi.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space8,
                  TermulSpacing.space3,
                  TermulSpacing.space8,
                  TermulSpacing.space3,
                ),
                child: Row(
                  spacing: TermulSpacing.space4,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(l.hostsTitle, style: TermulText.h2.copyWith(color: TermulPalette.ink)),
                    ),
                    Expanded(
                      child: TermulTextField(
                        label: l.hostsSearchLabel,
                        hideLabel: true,
                        icon: TermulIconName.search,
                        placeholder: l.hostsSearchPlaceholder,
                        controller: _search,
                        onChanged: ref.read(hostListProvider.notifier).setQuery,
                      ),
                    ),
                    FilterChipButton(
                      label: l.filterAll,
                      selected: listState.filter == HostFilter.all,
                      onPressed: () => ref.read(hostListProvider.notifier).setFilter(HostFilter.all),
                    ),
                    FilterChipButton(
                      label: l.filterFavorites,
                      selected: listState.filter == HostFilter.favorites,
                      onPressed: () => ref.read(hostListProvider.notifier).setFilter(HostFilter.favorites),
                    ),
                    TermulIconButton(
                      icon: TermulIconName.plus,
                      label: l.hostsAddHost,
                      tone: IconButtonTone.accent,
                      onPressed: _openForm,
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space8,
                  TermulSpacing.space8,
                  TermulSpacing.space8,
                  TermulSpacing.space1,
                ),
                child: Semantics(
                  label: 'termul',
                  excludeSemantics: true,
                  child: Text.rich(
                    TextSpan(
                      style: TermulText.wordmark.copyWith(color: TermulPalette.ink),
                      children: const [
                        TextSpan(text: 'termul'),
                        TextSpan(
                          text: '_',
                          style: TextStyle(color: TermulPalette.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space8,
                  TermulSpacing.space3,
                  TermulSpacing.space8,
                  TermulSpacing.space5,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(l.hostsTitle, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
                      ),
                    ),
                    TermulIconButton(
                      icon: TermulIconName.plus,
                      label: l.hostsAddHost,
                      tone: IconButtonTone.accent,
                      onPressed: _openForm,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space8, TermulSpacing.space5),
                child: TermulTextField(
                  label: l.hostsSearchLabel,
                  hideLabel: true,
                  icon: TermulIconName.search,
                  placeholder: l.hostsSearchPlaceholder,
                  controller: _search,
                  onChanged: ref.read(hostListProvider.notifier).setQuery,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(TermulSpacing.space8, 0, TermulSpacing.space8, TermulSpacing.space3),
                child: Row(
                  spacing: TermulSpacing.space3,
                  children: [
                    FilterChipButton(
                      label: l.filterAll,
                      selected: listState.filter == HostFilter.all,
                      onPressed: () => ref.read(hostListProvider.notifier).setFilter(HostFilter.all),
                    ),
                    FilterChipButton(
                      label: l.filterFavorites,
                      selected: listState.filter == HostFilter.favorites,
                      onPressed: () => ref.read(hostListProvider.notifier).setFilter(HostFilter.favorites),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: snapshot.profiles.isEmpty
                  ? _Empty(banners: banners, onAdd: _openForm)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        TermulSpacing.space5,
                        0,
                        TermulSpacing.space5,
                        TermulSpacing.space8,
                      ),
                      children: [
                        for (final b in banners)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              TermulSpacing.space3,
                              0,
                              TermulSpacing.space3,
                              TermulSpacing.space3,
                            ),
                            child: b,
                          ),
                        if (groups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: TermulSpacing.space7),
                            child: Text(
                              l.hostsNoMatch,
                              textAlign: TextAlign.center,
                              style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
                            ),
                          ),
                        for (final g in groups)
                          _Group(
                            group: g,
                            expanded: searching || !listState.collapsed.contains(g.path),
                            onToggle: () => ref.read(hostListProvider.notifier).toggleGroup(g.path),
                            onOpen: _open,
                            onActions: _showActions,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onActions,
  });

  final HostGroupView group;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(HostProfile) onOpen;
  final void Function(HostProfile) onActions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = group.path.isEmpty ? l.hostsRootGroup : group.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onPressed: onToggle,
          semanticLabel: l.hostsGroupToggle(name, group.hosts.length),
          toggled: expanded,
          builder: (context, pressed) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
            child: SizedBox(
              height: TermulSize.tapMin,
              child: Row(
                children: [
                  Transform.rotate(
                    angle: expanded ? 0 : -1.5708,
                    child: TermulIcon(TermulIconName.chevronDown, size: 16, color: TermulPalette.inkMuted),
                  ),
                  const SizedBox(width: TermulSpacing.space4),
                  Expanded(
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
                    ),
                  ),
                  Text('${group.hosts.length}', style: TermulText.overline.copyWith(color: TermulPalette.inkMuted)),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          for (final p in group.hosts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: HostRow(
                name: p.name,
                target: p.address,
                onPressed: () => onOpen(p),
                onLongPress: () => onActions(p),
                actionsLabel: l.hostActionsTitle(p.name),
              ),
            ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.banners, required this.onAdd});

  final List<Widget> banners;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(TermulSpacing.space8),
      children: [
        for (final b in banners)
          Padding(
            padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
            child: b,
          ),
        const SizedBox(height: TermulSpacing.space10),
        Center(child: TermulIcon(TermulIconName.hosts, size: 40, color: TermulPalette.lineStrong)),
        const SizedBox(height: TermulSpacing.space7),
        Text(
          l.hostsEmptyTitle,
          textAlign: TextAlign.center,
          style: TermulText.h2.copyWith(color: TermulPalette.ink),
        ),
        const SizedBox(height: TermulSpacing.space3),
        Text(
          l.hostsEmptyBody,
          textAlign: TextAlign.center,
          style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
        ),
        const SizedBox(height: TermulSpacing.space9),
        TermulButton(
          label: l.hostsAddHost,
          variant: TermulButtonVariant.primary,
          size: TermulButtonSize.lg,
          onPressed: onAdd,
        ),
      ],
    );
  }
}
