import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/host_profile.dart';
import '../../core/sftp/sftp_service.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_action_sheet.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_toast.dart';
import '../connect/connect_flow.dart';
import '../connect/connect_screen.dart' show connectFailureText;
import '../connect/host_key_prompt.dart';
import '../connect/session_controller.dart';
import '../connect/session_manager.dart';
import 'sftp_browser_controller.dart';
import 'sftp_format.dart';
import 'sftp_link.dart';
import 'sftp_transfer_actions.dart';
import 'unique_name.dart';
import 'sftp_transfers.dart';

/// Tab SFTP: memilih sumber sambungan. Sesi terminal yang sedang hidup di latar belakang bisa dipinjam
/// (sambungannya dipakai langsung, tanpa login lagi); host mana pun bisa dibuka dengan koneksi SFTP sendiri.
class SftpScreen extends ConsumerWidget {
  const SftpScreen({super.key});

  void _openOwn(BuildContext context, WidgetRef ref, HostProfile profile) {
    final l = AppLocalizations.of(context);
    final link = SftpLink.own(
      profile: profile,
      flow: ConnectFlow(
        profile: profile,
        vault: ref.read(credentialVaultProvider),
        hosts: ref.read(hostRepositoryProvider),
        connect: ref.read(connectFunctionProvider),
        unlockReason: l.unlockReason(profile.name),
        gate: ref.read(authGateProvider),
      ),
      probe: ref.read(hostProbeProvider),
      screenMonitor: ref.read(screenMonitorProvider),
      autoReconnect: () => ref.read(appSettingsProvider).connection.autoReconnect,
    );
    _push(context, link);
  }

  void _openBorrowed(BuildContext context, SessionController session) {
    final connection = session.connection;
    if (connection == null || connection.isClosed) {
      showTermulToast(context, AppLocalizations.of(context).sftpErrLost, icon: TermulIconName.warning);
      return;
    }
    _push(context, SftpLink.borrowed(session: session));
  }

  void _push(BuildContext context, SftpLink link) {
    unawaited(link.start());
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => SftpBrowserScreen(link: link)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final sessions = ref.watch(sessionManagerProvider);
    final hosts = ref.watch(hostSnapshotProvider).profiles;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(TermulSpacing.space3, TermulSpacing.space5, 0, TermulSpacing.space3),
      child: Semantics(
        header: true,
        child: Text(text, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                TermulSpacing.space8,
                landscape ? TermulSpacing.space3 : TermulSpacing.space8,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l.navSftp,
                  style: (landscape ? TermulText.h2 : TermulText.h1).copyWith(color: TermulPalette.ink),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(TermulSpacing.space5, 0, TermulSpacing.space5, TermulSpacing.space8),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
                    child: Text(l.sftpIntro, style: TermulText.bodySm.copyWith(color: TermulPalette.inkSoft)),
                  ),
                  if (sessions.isNotEmpty) ...[
                    heading(l.sftpSessionsHeading),
                    for (final s in sessions)
                      _SourceRow(
                        key: ValueKey('sesi-${s.id}'),
                        title: s.ordinal > 1 ? '${s.profile.name} · ${s.ordinal}' : s.profile.name,
                        subtitle: l.sftpUseSession,
                        icon: TermulIconName.terminal,
                        onPressed: () => _openBorrowed(context, s),
                      ),
                  ],
                  heading(l.sftpHostsHeading),
                  if (hosts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(TermulSpacing.space3),
                      child: Text(l.sftpNoHosts, style: TermulText.body.copyWith(color: TermulPalette.inkMuted)),
                    ),
                  for (final h in hosts)
                    _SourceRow(
                      key: ValueKey('host-${h.id}'),
                      title: h.name,
                      subtitle: '${h.username}@${h.host}:${h.port}',
                      icon: TermulIconName.hosts,
                      onPressed: () => _openOwn(context, ref, h),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({super.key, required this.title, required this.subtitle, required this.icon, this.onPressed});

  final String title;
  final String subtitle;
  final TermulIconName icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
      child: Pressable(
        onPressed: onPressed,
        semanticLabel: '$title, $subtitle',
        radius: TermulRadius.radiusXl,
        minHeight: TermulSize.rowMin,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: TermulSize.rowMin),
          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space4),
          decoration: BoxDecoration(
            color: TermulPalette.surface,
            borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
            border: Border.all(color: pressed ? TermulPalette.accent : TermulPalette.line),
          ),
          child: Row(
            children: [
              TermulIcon(icon, size: 22, color: TermulPalette.inkSoft),
              const SizedBox(width: TermulSpacing.space6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.title.copyWith(color: TermulPalette.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.caption.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.inkMuted),
                    ),
                  ],
                ),
              ),
              const TermulIcon(TermulIconName.chevronRight, size: 20, color: TermulPalette.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Penjelajah folder satu sambungan ([SftpLink]). Menutup layar menutup koneksi SFTP sendiri (sesi yang dipinjam
/// tetap hidup).
class SftpBrowserScreen extends ConsumerStatefulWidget {
  const SftpBrowserScreen({super.key, required this.link});

  final SftpLink link;

  @override
  ConsumerState<SftpBrowserScreen> createState() => _SftpBrowserScreenState();
}

class _SftpBrowserScreenState extends ConsumerState<SftpBrowserScreen> {
  late final SftpTransferActions _actions = SftpTransferActions(
    link: widget.link,
    saver: ref.read(downloadsSaverProvider),
    tempDir: ref.read(tempDirProvider),
  );
  SftpBrowserController? _browser;
  SftpBrowsing? _boundTo;

  @override
  void initState() {
    super.initState();
    widget.link.addListener(_onLink);
    _bind();
  }

  /// Membuat penjelajah bila sambungan sudah siap (atau sudah berganti setelah sambung ulang).
  void _bind() {
    final service = widget.link.service;
    if (service == null || identical(service, _boundTo)) return;
    _boundTo = service;
    // Setelah sambung ulang, kembali ke folder yang sedang dibuka.
    final restore = _browser?.path;
    final history = _browser?.history ?? const <String>[];
    _browser?.dispose();
    _browser = SftpBrowserController(service);
    unawaited(_browser!.start(restore: restore, history: history));
  }

  void _onLink() {
    _bind();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.link.removeListener(_onLink);
    _browser?.dispose();
    widget.link.dispose();
    super.dispose();
  }

  void _leave() => Navigator.of(context).pop();

  String _reason(AppLocalizations l, SftpFailureKind kind) => switch (kind) {
    SftpFailureKind.notFound => l.sftpErrNotFound,
    SftpFailureKind.permissionDenied => l.sftpErrDenied,
    SftpFailureKind.connectionLost => l.sftpErrLost,
    _ => l.sftpErrOther,
  };

  void _toastOutcome(ScaffoldMessengerState messenger, AppLocalizations l, TransferOutcome o, {required bool upload}) {
    switch (o) {
      case TransferDone(:final location, :final savedName, :final overwritten):
        showTermulToastOn(
          messenger,
          upload
              ? l.sftpUploaded(o.name)
              : (overwritten
                    ? l.sftpDownloadedOverwritten(location ?? 'Unduhan', savedName ?? o.name)
                    : l.sftpDownloaded(location ?? 'Unduhan', savedName ?? o.name)),
        );
      case TransferCancelled():
        showTermulToastOn(messenger, l.sftpTransferCancelledToast(o.name), icon: TermulIconName.warning);
      case TransferFailed(:final kind, :final saveFailed):
        showTermulToastOn(
          messenger,
          saveFailed
              ? l.sftpSaveFailed
              : (upload ? l.sftpUploadFailed(_reason(l, kind)) : l.sftpDownloadFailed(_reason(l, kind))),
          icon: TermulIconName.warning,
        );
    }
  }

  Future<void> _download(SftpEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final saver = ref.read(downloadsSaverProvider);
    String? saveAs;
    var overwrite = false;
    if (await saver.exists(entry.name)) {
      if (!mounted) return;
      // Nama bebas berikutnya menurut yang terlihat di Unduhan/TermUL.
      final taken = <String>{entry.name};
      var candidate = uniqueName(entry.name, taken.contains);
      while (await saver.exists(candidate)) {
        taken.add(candidate);
        candidate = uniqueName(entry.name, taken.contains);
      }
      if (!mounted) return;
      final choice = await _askConflict(entry.name, suggested: candidate, upload: false, dir: '');
      if (choice == _Conflict.cancel || !mounted) return;
      if (choice == _Conflict.rename) saveAs = candidate;
      overwrite = choice == _Conflict.overwrite;
    }
    final outcome = await _actions.download(entry, saveAs: saveAs, overwrite: overwrite);
    if (!mounted) return;
    _toastOutcome(messenger, l, outcome, upload: false);
  }

  /// Memilih berkas dari perangkat lalu mengunggahnya ke folder yang sedang dibuka. Nama yang sudah ada di folder
  /// ini ditanyakan dulu (menimpa tidak bisa dibatalkan).
  Future<void> _upload() async {
    final browser = _browser;
    if (browser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final files = await ref.read(uploadPickerProvider).pick();
    if (!mounted || files.isEmpty) return;
    final dir = browser.path;
    for (final f in files) {
      if (!mounted) return;
      String? remoteName;
      if (browser.entries.any((e) => e.name == f.name)) {
        final names = {for (final e in browser.entries) e.name};
        final suggested = uniqueName(f.name, names.contains);
        final choice = await _askConflict(f.name, suggested: suggested, upload: true, dir: dir);
        if (choice == _Conflict.cancel || !mounted) continue;
        if (choice == _Conflict.rename) remoteName = suggested;
      }
      final outcome = await _actions.upload(f, dir, remoteName: remoteName);
      if (!mounted) return;
      _toastOutcome(messenger, l, outcome, upload: true);
      if (outcome is TransferDone) unawaited(browser.refresh());
    }
  }

  /// Tombol kembali (header dan sistem): di dalam folder yang dibuka dari folder lain, kembali ke folder sebelumnya;
  /// di folder awal baru menanyakan keluar. Selagi folder dimuat, ketukan kembali tidak keluar.
  void _back() {
    final browser = _browser;
    if (browser != null && browser.canGoBack) {
      unawaited(browser.back());
      return;
    }
    unawaited(_requestLeave());
  }

  /// Keluar selalu meminta konfirmasi selagi sambungan sudah terbuka. Bila ada transfer berjalan, isinya
  /// menyebut transfer itu dan akibat membatalkannya; pilihan aman (tetap di sini) menjadi tombol utama.
  Future<void> _requestLeave() async {
    final link = widget.link;
    if (link.service == null) {
      _leave();
      return;
    }
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final busy = link.transfers.isBusy;
    await showTermulSheet<void>(
      context,
      title: busy ? l.sftpLeaveBusyTitle : l.sftpLeaveTitle,
      child: busy
          ? _BusyTransfers(tracker: link.transfers)
          : Text(
              link.isOwn ? l.sftpLeaveBodyOwn(link.profile.name) : l.sftpLeaveBodyBorrowed(link.profile.name),
              style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
            ),
      cancelLabel: l.actionCancel,
      confirmLabel: busy ? l.sftpLeaveBusyConfirm : l.sftpLeaveConfirm,
      confirmIsDanger: busy,
      cancelIsPrimary: busy,
      onConfirm: () {
        link.transfers.cancelAll();
        navigator.pop();
      },
    );
  }

  /// Nama sudah dipakai (di server untuk unggah, di Unduhan/TermUL untuk unduh): simpan dengan nama bernomor
  /// (pilihan aman, tombol utama), timpa (berisiko), atau batal.
  Future<_Conflict> _askConflict(
    String name, {
    required String suggested,
    required bool upload,
    required String dir,
  }) async {
    final l = AppLocalizations.of(context);
    var choice = _Conflict.cancel;
    await showTermulActions(
      context,
      title: l.sftpConflictTitle(name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space3,
        children: [
          Text(
            upload ? l.sftpConflictBodyUpload(dir) : l.sftpConflictBodyDownload,
            style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
          ),
          Text(l.sftpConflictOverwriteNote, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
        ],
      ),
      actions: [
        SheetAction(label: l.sftpConflictRename(suggested), primary: true, onSelected: () => choice = _Conflict.rename),
        SheetAction(label: l.sftpConflictOverwrite, danger: true, onSelected: () => choice = _Conflict.overwrite),
        SheetAction(label: l.actionCancel, onSelected: () {}),
      ],
    );
    return choice;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final link = widget.link;
    final flow = link.flow;
    final state = flow?.state;
    if (state is ConnectNeedsHostKey) {
      return HostKeyPrompt(profile: link.profile, challenge: state.challenge, onChoice: flow!.answerHostKey);
    }
    final browser = _browser;
    return PopScope(
      canPop: link.service == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                title: l.navSftp,
                subtitle: link.service == null
                    ? link.profile.name
                    : link.lost
                    ? l.sftpDisconnectedFrom(link.profile.name)
                    : l.sftpConnectedTo(link.profile.name),
                subtitleColor: link.service != null && link.lost ? TermulPalette.bad : TermulPalette.ok,
                onBack: _back,
                onRefresh: browser == null || link.lost ? null : () => unawaited(browser.refresh()),
                onUpload: browser == null || link.lost ? null : () => unawaited(_upload()),
              ),
              Expanded(
                child: link.service == null || browser == null
                    ? _Connecting(link: link, state: state, onLeave: _leave)
                    : ListenableBuilder(
                        listenable: Listenable.merge([browser, link, link.transfers]),
                        builder: (context, _) => _Listing(browser: browser, link: link, onDownload: _download),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isi konfirmasi keluar bila ada transfer: daftar transfer (kemajuan ikut berjalan) dan akibat pembatalannya.
class _BusyTransfers extends StatelessWidget {
  const _BusyTransfers({required this.tracker});

  final SftpTransferTracker tracker;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final list = tracker.active;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TermulSpacing.space4,
          children: [
            Text(l.sftpLeaveBusyBody(list.length), style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
            for (final t in list)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.upload ? l.sftpTransferUpload(t.name) : l.sftpTransferDownload(t.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.bodySm.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.ink),
                    ),
                  ),
                  if (t.percent != null)
                    Text(
                      l.sftpTransferPercent(t.percent!),
                      style: TermulText.bodySm.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.accent),
                    ),
                ],
              ),
            if (list.any((t) => t.upload))
              Text(l.sftpLeaveBusyUploadNote, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
            if (list.any((t) => !t.upload))
              Text(l.sftpLeaveBusyDownloadNote, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.onBack,
    required this.onRefresh,
    required this.onUpload,
  });

  final String title;
  final String subtitle;
  final Color subtitleColor;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TermulSpacing.space3,
        TermulSpacing.space3,
        TermulSpacing.space3,
        TermulSpacing.space1,
      ),
      child: Row(
        children: [
          TermulIconButton(icon: TermulIconName.chevronLeft, label: l.actionBack, onPressed: onBack),
          const SizedBox(width: TermulSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: TermulText.title.copyWith(color: TermulPalette.ink)),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TermulText.caption.copyWith(fontFamily: TermulFonts.mono, color: subtitleColor),
                ),
              ],
            ),
          ),
          TermulIconButton(icon: TermulIconName.upload, label: l.sftpUploadAction, onPressed: onUpload),
          TermulIconButton(icon: TermulIconName.refresh, label: l.sftpRefresh, onPressed: onRefresh),
        ],
      ),
    );
  }
}

/// Sambungan belum siap: menyambung, gagal, atau kanal SFTP tidak bisa dibuka.
class _Connecting extends StatelessWidget {
  const _Connecting({required this.link, required this.state, required this.onLeave});

  final SftpLink link;
  final ConnectState? state;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = state;
    Widget body;
    if (link.openError != null) {
      body = _Problem(
        title: l.sftpUnavailableTitle,
        body: l.sftpUnavailableBody,
        action: TermulButton(label: l.actionBack, onPressed: onLeave),
      );
    } else if (s is ConnectFailed) {
      final (title, text) = connectFailureText(l, s.failure);
      body = _Problem(
        title: title,
        body: text,
        action: Column(
          spacing: TermulSpacing.space3,
          children: [
            TermulButton(
              label: l.actionRetry,
              variant: TermulButtonVariant.primary,
              onPressed: () => unawaited(link.retry()),
            ),
            TermulButton(label: l.actionBack, variant: TermulButtonVariant.ghost, onPressed: onLeave),
          ],
        ),
      );
    } else if (s is ConnectAuthDenied) {
      body = _Problem(
        title: s.cancelled ? l.authDeniedTitle : l.authUnavailableTitle,
        body: s.cancelled ? l.authDeniedBody : l.authUnavailableBody,
        action: Column(
          spacing: TermulSpacing.space3,
          children: [
            TermulButton(
              label: l.actionRetry,
              variant: TermulButtonVariant.primary,
              onPressed: () => unawaited(link.retry()),
            ),
            TermulButton(label: l.actionBack, variant: TermulButtonVariant.ghost, onPressed: onLeave),
          ],
        ),
      );
    } else if (s is ConnectNeedsSecret) {
      body = _Problem(
        title: l.failAuthTitle,
        body: l.failAuthBody,
        action: TermulButton(label: l.actionBack, onPressed: onLeave),
      );
    } else {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TermulSpacing.space6,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            Text(l.connectConnecting(link.profile.name), style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
            TermulButton(label: l.actionAbort, variant: TermulButtonVariant.ghost, expand: false, onPressed: onLeave),
          ],
        ),
      );
    }
    return Padding(padding: const EdgeInsets.all(TermulSpacing.space8), child: body);
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.title, required this.body, required this.action});

  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TermulSpacing.space8,
          children: [
            TermulBanner(tone: BannerTone.risk, title: title, child: Text(body)),
            action,
          ],
        ),
      ),
    );
  }
}

class _Listing extends StatelessWidget {
  const _Listing({required this.browser, required this.link, required this.onDownload});

  final void Function(SftpEntry) onDownload;

  final SftpBrowserController browser;
  final SftpLink link;

  static String _failureText(AppLocalizations l, SftpFailure f) => switch (f.kind) {
    SftpFailureKind.notFound => l.sftpErrNotFound,
    SftpFailureKind.permissionDenied => l.sftpErrDenied,
    SftpFailureKind.connectionLost => l.sftpErrLost,
    _ => l.sftpErrOther,
  };

  /// Banner sambungan putus: sama dengan terminal (menunggu server terjangkau dengan hitungan mundur, menyambung
  /// ulang, perlu verifikasi), ditambah keadaan putus biasa.
  Widget _linkBanner(AppLocalizations l) {
    TermulButton button(String label, {bool primary = true}) => TermulButton(
      label: label,
      variant: primary ? TermulButtonVariant.primary : TermulButtonVariant.secondary,
      expand: false,
      onPressed: () => unawaited(link.retry()),
    );
    if (!link.isOwn) {
      return TermulBanner(tone: BannerTone.warn, title: l.sftpLostTitle, child: Text(l.sftpLostBorrowedBody));
    }
    if (link.needsAuth) {
      return TermulBanner(
        tone: BannerTone.warn,
        title: l.reconnectAuthTitle,
        action: button(l.reconnectShowPrompt),
        child: Text(l.reconnectAuthBody),
      );
    }
    final retry = link.secondsUntilRetry;
    if (retry != null) {
      return TermulBanner(
        tone: BannerTone.warn,
        title: l.reconnectWaitingTitle,
        action: button(l.reconnectNow),
        child: Text(l.reconnectWaitingBody(retry)),
      );
    }
    if (link.reconnecting) {
      return TermulBanner(tone: BannerTone.warn, title: l.reconnectingTitle, child: Text(l.sftpReconnectingBody));
    }
    return TermulBanner(
      tone: BannerTone.warn,
      title: l.sftpLostTitle,
      action: button(l.sftpReconnect),
      child: Text(l.sftpLostOwnBody),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final failure = browser.failure;
    final lost = link.lost || failure?.kind == SftpFailureKind.connectionLost;
    final now = DateTime.now();
    final entries = browser.entries;
    final rows = <Widget>[
      if (!browser.atRoot)
        _EntryRow(
          key: const ValueKey('naik'),
          name: l.sftpUpTitle,
          meta: l.sftpUpMeta,
          icon: TermulIconName.chevronLeft,
          iconColor: TermulPalette.inkSoft,
          onPressed: () => unawaited(browser.up()),
        ),
      for (final e in entries)
        _EntryRow(
          key: ValueKey(e.path),
          name: e.name,
          meta: e.isDirectory
              ? l.sftpFolderMeta
              : [
                  if (e.size != null) formatSize(e.size!),
                  if (e.modified != null) formatModified(l, e.modified!, now),
                ].join(' · '),
          icon: e.isDirectory ? TermulIconName.folder : TermulIconName.file,
          iconColor: e.isDirectory ? TermulPalette.info : TermulPalette.inkSoft,
          selected: identical(browser.selected, e),
          onPressed: () => e.isDirectory ? unawaited(browser.open(e.path)) : browser.select(e),
        ),
    ];
    return Column(
      children: [
        _Breadcrumbs(browser: browser),
        if (lost)
          Padding(
            padding: const EdgeInsets.fromLTRB(TermulSpacing.space5, 0, TermulSpacing.space5, TermulSpacing.space3),
            child: _linkBanner(l),
          )
        else if (failure != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(TermulSpacing.space5, 0, TermulSpacing.space5, TermulSpacing.space3),
            child: TermulBanner(
              tone: BannerTone.risk,
              action: TermulButton(label: l.actionRetry, expand: false, onPressed: () => unawaited(browser.refresh())),
              child: Text(_failureText(l, failure)),
            ),
          ),
        Expanded(
          child: browser.loading && entries.isEmpty
              ? Center(
                  child: Text(l.sftpLoading, style: TermulText.body.copyWith(color: TermulPalette.inkMuted)),
                )
              : rows.isEmpty
              ? Center(
                  child: Text(l.sftpEmptyFolder, style: TermulText.body.copyWith(color: TermulPalette.inkMuted)),
                )
              : RefreshIndicator(
                  onRefresh: browser.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space5,
                      0,
                      TermulSpacing.space5,
                      TermulSpacing.space5,
                    ),
                    children: rows,
                  ),
                ),
        ),
        if (link.transfers.isBusy) _TransferPanel(tracker: link.transfers),
        if (browser.selected case final sel?)
          _SelectionBar(
            entry: sel,
            // Pilihan dilepas begitu aksi ditekan: unduhan berjalan di panel transfer dan tombol tidak bisa ditekan
            // berulang untuk berkas yang sama.
            onDone: browser.clearSelection,
            onDownload: link.lost ? null : () => onDownload(sel),
          ),
      ],
    );
  }
}

class _Breadcrumbs extends StatefulWidget {
  const _Breadcrumbs({required this.browser});

  final SftpBrowserController browser;

  @override
  State<_Breadcrumbs> createState() => _BreadcrumbsState();
}

class _BreadcrumbsState extends State<_Breadcrumbs> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crumbs = widget.browser.crumbs;
    // Jalur panjang: biarkan bagian akhir (folder aktif) terlihat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
    return SizedBox(
      height: TermulSize.tapMin,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space5),
        itemCount: crumbs.length,
        itemBuilder: (context, i) {
          final (label, path) = crumbs[i];
          final last = i == crumbs.length - 1;
          return Row(
            children: [
              if (i > 1) Text('/', style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted)),
              Pressable(
                onPressed: last ? null : () => unawaited(widget.browser.open(path)),
                semanticLabel: path,
                minHeight: TermulSize.tapMin,
                minWidth: 32,
                builder: (context, pressed) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
                  child: Center(
                    child: Text(
                      label,
                      style: TermulText.bodySm.copyWith(
                        fontFamily: TermulFonts.mono,
                        color: last ? TermulPalette.ink : (pressed ? TermulPalette.accent : TermulPalette.inkSoft),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.name,
    required this.meta,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.selected = false,
  });

  final String name;
  final String meta;
  final TermulIconName icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
      child: Pressable(
        onPressed: onPressed,
        semanticLabel: meta.isEmpty ? name : '$name, $meta',
        toggled: selected ? true : null,
        radius: TermulRadius.radiusXl,
        minHeight: 60,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6, vertical: TermulSpacing.space3),
          decoration: BoxDecoration(
            color: selected ? TermulPalette.surfaceRaised : TermulPalette.surface,
            borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
            border: Border.all(color: selected || pressed ? TermulPalette.accent : TermulPalette.line),
          ),
          child: Row(
            children: [
              TermulIcon(icon, size: 22, color: iconColor),
              const SizedBox(width: TermulSpacing.space6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.bodySm.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.ink),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(meta, style: TermulText.caption.copyWith(color: TermulPalette.inkSoft)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.entry, required this.onDone, this.onDownload});

  final SftpEntry entry;

  /// Dipanggil begitu sebuah aksi ditekan (melepas pilihan).
  final VoidCallback onDone;

  /// null bila sambungan putus (unduh tidak bisa dimulai).
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TermulSpacing.space5,
        TermulSpacing.space5,
        TermulSpacing.space5,
        TermulSpacing.space5,
      ),
      decoration: const BoxDecoration(
        color: TermulPalette.surface,
        border: Border(top: BorderSide(color: TermulPalette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TermulSpacing.space4,
        children: [
          Text(
            l.sftpSelected(entry.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TermulText.caption.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.inkSoft),
          ),
          Row(
            spacing: TermulSpacing.space3,
            children: [
              if (onDownload != null)
                Expanded(
                  flex: 2,
                  child: TermulButton(
                    label: l.sftpDownloadAction,
                    icon: TermulIconName.download,
                    variant: TermulButtonVariant.primary,
                    onPressed: () {
                      onDone();
                      onDownload!();
                    },
                  ),
                ),
              Expanded(
                flex: 2,
                child: TermulButton(
                  label: l.sftpCopyPath,
                  icon: TermulIconName.copy,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    onDone();
                    await Clipboard.setData(ClipboardData(text: entry.path));
                    showTermulToastOn(messenger, l.sftpPathCopied);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Transfer yang sedang berjalan: nama, persen, bilah kemajuan, dan tombol batal per transfer.
class _TransferPanel extends StatelessWidget {
  const _TransferPanel({required this.tracker});

  final SftpTransferTracker tracker;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TermulSpacing.space5,
        TermulSpacing.space3,
        TermulSpacing.space3,
        TermulSpacing.space3,
      ),
      decoration: const BoxDecoration(
        color: TermulPalette.surface,
        border: Border(top: BorderSide(color: TermulPalette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in tracker.active)
            Row(
              key: ValueKey('transfer-${t.id}'),
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: TermulSpacing.space2,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.upload ? l.sftpTransferUpload(t.name) : l.sftpTransferDownload(t.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TermulText.bodySm.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.ink),
                            ),
                          ),
                          if (t.percent != null)
                            Text(
                              l.sftpTransferPercent(t.percent!),
                              style: TermulText.bodySm.copyWith(
                                fontFamily: TermulFonts.mono,
                                color: TermulPalette.accent,
                              ),
                            ),
                        ],
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: t.percent == null ? null : t.percent! / 100,
                          minHeight: 4,
                          backgroundColor: TermulPalette.lineStrong,
                          color: TermulPalette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                TermulIconButton(
                  icon: TermulIconName.close,
                  label: l.sftpTransferCancel,
                  onPressed: t.cancel.isCancelled ? null : t.cancel.cancel,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _Conflict { rename, overwrite, cancel }
