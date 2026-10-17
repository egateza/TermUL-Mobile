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
import 'sftp_browser_controller.dart';
import 'sftp_format.dart';
import 'sftp_link.dart';
import 'sftp_session_manager.dart';
import 'sftp_transfer_actions.dart';
import 'unique_name.dart';
import 'sftp_transfers.dart';

void _pushLink(BuildContext context, SftpLink link, {bool confirmLeave = true}) {
  unawaited(link.start());
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SftpBrowserScreen(link: link, confirmLeave: confirmLeave),
    ),
  );
}

/// Membuka penjelajah SFTP lewat sambungan [session] (sesi terminal), tanpa login ulang dan tanpa sesi baru. Sambungan
/// sesi tidak ditutup saat penjelajah ditutup; hanya kanal SFTP-nya. Dengan [confirmLeave] false (dibuka dari
/// terminal), keluar kembali ke terminal tanpa konfirmasi kecuali ada transfer berjalan.
void openSftpFromSession(BuildContext context, SessionController session, {bool confirmLeave = true}) {
  final connection = session.connection;
  if (connection == null || connection.isClosed) {
    showTermulToast(context, AppLocalizations.of(context).sftpErrLost, icon: TermulIconName.warning);
    return;
  }
  _pushLink(context, SftpLink.borrowed(session: session), confirmLeave: confirmLeave);
}

/// Membuka sesi SFTP mandiri ke [profile] (menu tekan lama host: "Sambung SFTP"): koneksi SFTP sendiri dengan vault,
/// biometrik, dan verifikasi host key yang sama dengan terminal. Sesinya dikelola [SftpSessionManager] dan bisa
/// dibiarkan hidup di latar belakang.
void openSftpOwn(BuildContext context, WidgetRef ref, HostProfile profile) {
  final l = AppLocalizations.of(context);
  final session = ref
      .read(sftpSessionManagerProvider.notifier)
      .create(profile, unlockReason: l.unlockReason(profile.name));
  _pushSession(context, session);
}

/// Membuka lagi sesi SFTP yang hidup di latar belakang (dari tab Sesi).
void openSftpSession(BuildContext context, WidgetRef ref, SftpSession session) {
  ref.read(sftpSessionManagerProvider.notifier).take(session);
  _pushSession(context, session);
}

void _pushSession(BuildContext context, SftpSession session) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SftpBrowserScreen(link: session.link, session: session),
    ),
  );
}

/// Penjelajah folder satu sambungan ([SftpLink]). Menutup layar menutup koneksi SFTP sendiri (sesi yang dipinjam
/// tetap hidup).
class SftpBrowserScreen extends ConsumerStatefulWidget {
  const SftpBrowserScreen({super.key, required this.link, this.confirmLeave = true, this.session});

  final SftpLink link;

  /// Sesi SFTP mandiri yang dikelola [SftpSessionManager]: sheet keluar menawarkan "Tetap terhubung", dan sesi
  /// ditutup atau dibiarkan hidup saat layar ditutup. Kosong = sambungan pinjaman atau tes: ditutup bersama layar.
  final SftpSession? session;

  /// false: keluar tanpa sheet konfirmasi bila tidak ada transfer berjalan (SFTP dibuka dari terminal yang sama).
  final bool confirmLeave;

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
  SftpSessionManager? _sessions;
  bool _keep = false;

  @override
  void initState() {
    super.initState();
    _sessions = widget.session == null ? null : ref.read(sftpSessionManagerProvider.notifier);
    widget.link.addListener(_onLink);
    _bind();
  }

  /// Membuat penjelajah bila sambungan sudah siap (atau sudah berganti setelah sambung ulang).
  void _bind() {
    final service = widget.link.service;
    if (service == null || identical(service, _boundTo)) return;
    _boundTo = service;
    // Setelah sambung ulang, kembali ke folder yang sedang dibuka.
    final restore = _browser?.path ?? widget.link.resumePath;
    final history = _browser?.history ?? widget.link.resumeHistory;
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
    final session = widget.session;
    if (session == null) {
      widget.link.dispose();
    } else if (_keep) {
      _sessions!.keep(session);
    } else {
      _sessions!.release(session);
    }
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
      case TransferDone(:final fileCount, :final failedCount, :final skipped, :final isFolder, :final location)
          when isFolder:
        if (failedCount > 0) {
          showTermulToastOn(
            messenger,
            l.sftpDownloadedManyPartial(fileCount, failedCount),
            icon: TermulIconName.warning,
          );
        } else if (fileCount == 0) {
          showTermulToastOn(messenger, l.sftpFolderNoFiles(o.name), icon: TermulIconName.warning);
        } else {
          final where = location ?? 'Unduhan/TermUL/${o.name}';
          showTermulToastOn(
            messenger,
            skipped > 0
                ? l.sftpDownloadedManySkipped(fileCount, where, skipped)
                : l.sftpDownloadedMany(fileCount, where),
          );
        }
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

  /// Mengunduh [entries] satu per satu (berurutan). Nama yang sudah ada di Unduhan/TermUL ditanyakan sekali untuk
  /// seluruh kelompok. Satu transfer dibatalkan berarti sisanya tidak dimulai. Satu entri memakai toast per berkas,
  /// beberapa entri satu toast ringkasan.
  Future<void> _download(List<SftpEntry> entries) async {
    if (entries.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final saver = ref.read(downloadsSaverProvider);
    final saveAs = <String, String>{};
    var overwrite = false;
    final conflicts = <SftpEntry>[];
    Future<bool> inUse(SftpEntry e, String name) => e.isDirectory ? saver.folderExists(name) : saver.exists(name);
    for (final e in entries) {
      if (await inUse(e, e.name)) conflicts.add(e);
    }
    if (!mounted) return;
    if (conflicts.isNotEmpty) {
      // Nama bebas berikutnya menurut yang terlihat di Unduhan/TermUL; tidak boleh bentrok dengan nama lain di kelompok.
      final taken = {for (final e in entries) e.name};
      for (final e in conflicts) {
        final pick = e.isDirectory ? uniqueFolderName : uniqueName;
        var candidate = pick(e.name, taken.contains);
        while (await inUse(e, candidate)) {
          taken.add(candidate);
          candidate = pick(e.name, taken.contains);
        }
        taken.add(candidate);
        saveAs[e.path] = candidate;
      }
      if (!mounted) return;
      final choice = conflicts.length == 1 && entries.length == 1
          ? await _askConflict(conflicts.first.name, suggested: saveAs[conflicts.first.path]!, upload: false, dir: '')
          : await _askConflictMany(conflicts.length);
      if (choice == _Conflict.cancel || !mounted) return;
      overwrite = choice == _Conflict.overwrite;
      if (overwrite) saveAs.clear();
    }
    final outcomes = <TransferOutcome>[];
    // Tanpa pemeriksaan `mounted` dari sini: transfer terus berjalan (dan toast hasilnya tampil) walau layar SFTP ditutup
    // dengan "Tetap terhubung".
    for (final e in entries) {
      final replace = overwrite && conflicts.contains(e);
      final outcome = e.isDirectory
          ? await _actions.downloadFolder(e, saveAs: saveAs[e.path], overwrite: replace)
          : await _actions.download(e, saveAs: saveAs[e.path], overwrite: replace);
      outcomes.add(outcome);
      if (outcome is TransferCancelled) break;
    }
    if (outcomes.length == 1) {
      _toastOutcome(messenger, l, outcomes.single, upload: false);
      return;
    }
    final dones = outcomes.whereType<TransferDone>().toList();
    final files = dones.fold<int>(0, (sum, d) => sum + d.fileCount);
    final failed = outcomes.whereType<TransferFailed>().length + dones.fold<int>(0, (sum, d) => sum + d.failedCount);
    final skipped = dones.fold<int>(0, (sum, d) => sum + d.skipped);
    final cancelled = outcomes.whereType<TransferCancelled>().firstOrNull;
    if (cancelled != null) {
      showTermulToastOn(messenger, l.sftpTransferCancelledToast(cancelled.name), icon: TermulIconName.warning);
    } else if (failed > 0) {
      showTermulToastOn(messenger, l.sftpDownloadedManyPartial(files, failed), icon: TermulIconName.warning);
    } else if (files == 0) {
      showTermulToastOn(messenger, l.sftpFolderNoFiles(dones.first.name), icon: TermulIconName.warning);
    } else {
      final location = dones.first.isFolder ? 'Unduhan/TermUL' : (dones.first.location ?? 'Unduhan/TermUL');
      showTermulToastOn(
        messenger,
        skipped > 0 ? l.sftpDownloadedManySkipped(files, location, skipped) : l.sftpDownloadedMany(files, location),
      );
    }
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

  /// Muat ulang dari tombol header atau tarik ke bawah: toast hanya bila berhasil (galat tampil di banner).
  Future<void> _refresh() async {
    final browser = _browser;
    if (browser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    await browser.refresh();
    if (!mounted || browser.failure != null) return;
    showTermulToastOn(messenger, l.sftpRefreshed);
  }

  /// Tombol kembali (header dan sistem): selagi ada pilihan, hanya melepas pilihan; di dalam folder yang dibuka dari folder lain, kembali ke folder sebelumnya;
  /// di folder awal baru menanyakan keluar. Selagi folder dimuat, ketukan kembali tidak keluar.
  void _back() {
    final browser = _browser;
    if (browser != null && browser.hasSelection) {
      browser.clearSelection();
      return;
    }
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
    if (link.service == null || (!widget.confirmLeave && !link.transfers.isBusy)) {
      _leave();
      return;
    }
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final busy = link.transfers.isBusy;
    if (widget.session != null) {
      await _askLeaveOwn(busy);
      return;
    }
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

  /// "Tetap terhubung": layar ditutup, sesi SFTP dibiarkan hidup (folder yang dibuka diingat untuk dibuka lagi).
  void _keepInBackground() {
    widget.link.resumePath = _browser?.path;
    widget.link.resumeHistory = _browser?.history ?? const [];
    _keep = true;
    Navigator.of(context).pop();
  }

  /// Sheet keluar untuk sesi SFTP mandiri: Tetap terhubung (utama; transfer tetap berjalan), Putuskan, atau Batal.
  Future<void> _askLeaveOwn(bool busy) async {
    final l = AppLocalizations.of(context);
    final link = widget.link;
    final navigator = Navigator.of(context);
    final keepAlive = ref.read(appSettingsProvider).connection.keepAlive;
    await showTermulActions(
      context,
      title: busy ? l.sftpLeaveBusyTitle : l.sftpLeaveTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space3,
        children: [
          if (busy) _BusyTransfers(tracker: link.transfers),
          Text(
            busy ? l.sftpLeaveBusyKeepNote : l.sftpLeaveChoiceBody(link.profile.name),
            style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
          ),
          if (!keepAlive) TermulBanner(tone: BannerTone.warn, child: Text(l.terminalLeaveKeepAliveOff)),
        ],
      ),
      actions: [
        SheetAction(label: l.sftpLeaveKeep, primary: true, onSelected: _keepInBackground),
        SheetAction(
          label: busy ? l.sftpLeaveBusyConfirm : l.sftpLeaveDisconnect,
          danger: busy,
          onSelected: () {
            link.transfers.cancelAll();
            navigator.pop();
          },
        ),
        SheetAction(label: l.actionCancel, onSelected: () {}),
      ],
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

  /// Beberapa nama sudah ada di Unduhan/TermUL: satu pilihan berlaku untuk semuanya.
  Future<_Conflict> _askConflictMany(int count) async {
    final l = AppLocalizations.of(context);
    var choice = _Conflict.cancel;
    await showTermulActions(
      context,
      title: l.sftpConflictManyTitle(count),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space3,
        children: [
          Text(l.sftpConflictBodyDownload, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
          Text(l.sftpConflictOverwriteNote, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
        ],
      ),
      actions: [
        SheetAction(label: l.sftpConflictRenameAll, primary: true, onSelected: () => choice = _Conflict.rename),
        SheetAction(label: l.sftpConflictOverwriteAll, danger: true, onSelected: () => choice = _Conflict.overwrite),
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
                onRefresh: browser == null || link.lost ? null : () => unawaited(_refresh()),
                onUpload: browser == null || link.lost ? null : () => unawaited(_upload()),
              ),
              Expanded(
                child: link.service == null || browser == null
                    ? _Connecting(link: link, state: state, onLeave: _leave)
                    : ListenableBuilder(
                        listenable: Listenable.merge([browser, link, link.transfers]),
                        builder: (context, _) =>
                            _Listing(browser: browser, link: link, onDownload: _download, onRefresh: _refresh),
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
  const _Listing({required this.browser, required this.link, required this.onDownload, required this.onRefresh});

  final Future<void> Function() onRefresh;

  final void Function(List<SftpEntry>) onDownload;

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
          meta: [
            if (e.isDirectory)
              l.sftpFolderMeta
            else ...[
              if (e.size != null) formatSize(e.size!),
              if (e.modified != null) formatModified(l, e.modified!, now),
            ],
            if (e.isLink) l.sftpLinkTag,
          ].join(' · '),
          isLink: e.isLink,
          icon: e.isDirectory ? TermulIconName.folder : TermulIconName.file,
          iconColor: e.isDirectory ? TermulPalette.info : TermulPalette.inkSoft,
          selected: browser.isSelected(e),
          onLongPress: () => browser.toggle(e),
          onPressed: () => browser.hasSelection || !e.isDirectory ? browser.toggle(e) : unawaited(browser.open(e.path)),
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
                  onRefresh: onRefresh,
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
        if (browser.hasSelection)
          _SelectionBar(
            browser: browser,
            // Pilihan dilepas begitu aksi ditekan: unduhan berjalan di panel transfer dan tombol tidak bisa ditekan
            // berulang untuk berkas yang sama.
            onDownload: link.lost
                ? null
                : () {
                    final picked = browser.selection;
                    browser.clearSelection();
                    onDownload(picked);
                  },
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
    this.onLongPress,
    this.selected = false,
    this.isLink = false,
  });

  final String name;
  final String meta;
  final TermulIconName icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  /// Tautan simbolik: lencana tautan kecil di pojok kanan bawah ikon.
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
      child: Pressable(
        onPressed: onPressed,
        onLongPress: onLongPress,
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
              SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TermulIcon(icon, size: 22, color: iconColor),
                    if (isLink)
                      Positioned(
                        key: const ValueKey('lencana-tautan'),
                        right: -6,
                        bottom: -6,
                        child: Container(
                          width: 14,
                          height: 14,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? TermulPalette.surfaceRaised : TermulPalette.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: TermulPalette.lineStrong),
                          ),
                          child: const TermulIcon(TermulIconName.link, size: 9, color: TermulPalette.ink),
                        ),
                      ),
                  ],
                ),
              ),
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
              if (selected) const TermulIcon(TermulIconName.check, size: 20, color: TermulPalette.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.browser, this.onDownload});

  final SftpBrowserController browser;

  /// null bila sambungan putus (unduh tidak bisa dimulai).
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selection = browser.selection;
    final count = browser.selectionCount;
    final bytes = browser.selectionBytes;
    final hasFiles = selection.any((e) => !e.isDirectory);
    final caption = TermulText.caption.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.inkSoft);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TermulSpacing.space5,
        TermulSpacing.space3,
        TermulSpacing.space5,
        TermulSpacing.space5,
      ),
      decoration: const BoxDecoration(
        color: TermulPalette.surface,
        border: Border(top: BorderSide(color: TermulPalette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space3,
        children: [
          Row(
            spacing: TermulSpacing.space3,
            children: [
              TermulIconButton(
                icon: TermulIconName.close,
                label: l.sftpSelectionCancel,
                onPressed: browser.clearSelection,
              ),
              Expanded(
                child: Text(
                  count == 1 ? l.sftpSelected(selection.first.name) : l.sftpSelectedCount(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: caption,
                ),
              ),
              if (hasFiles) Text(formatSize(bytes), style: caption.copyWith(color: TermulPalette.ink)),
              if (!browser.allSelected)
                TermulButton(
                  label: l.sftpSelectAll,
                  variant: TermulButtonVariant.ghost,
                  expand: false,
                  onPressed: browser.selectAll,
                ),
            ],
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
                    onPressed: onDownload,
                  ),
                ),
              Expanded(
                flex: 2,
                child: TermulButton(
                  label: l.sftpCopyPath,
                  icon: TermulIconName.copy,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    browser.clearSelection();
                    await Clipboard.setData(ClipboardData(text: selection.map((e) => e.path).join('\n')));
                    showTermulToastOn(messenger, count == 1 ? l.sftpPathCopied : l.sftpPathsCopied(count));
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
