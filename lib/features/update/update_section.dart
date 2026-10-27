import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart' show appSettingsProvider;
import '../../core/theme/termul_theme.dart';
import '../../core/update/release.dart';
import '../../core/update/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/switch_row.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../sftp/sftp_format.dart' show formatSize;
import 'release_notes.dart';
import 'update_controller.dart';

/// Bagian "Pembaruan" di paling bawah Pengaturan: status rilis GitHub, catatan rilis, unduh dengan kemajuan, pasang,
/// penjelasan izin "Pasang aplikasi tidak dikenal", saklar "Periksa update otomatis", lalu keterangan versi dan build
/// terpasang sebagai baris terakhir.
class UpdateSection extends ConsumerStatefulWidget {
  const UpdateSection({super.key});

  @override
  ConsumerState<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<UpdateSection> with WidgetsBindingObserver {
  /// "Pasang" diketuk tetapi izin pasang aplikasi belum diberikan.
  bool _needsPermission = false;

  /// Saklar "Periksa update otomatis" gagal disimpan; nilainya tetap berlaku sampai aplikasi ditutup.
  bool _saveFailed = false;

  Future<void> _setAutoCheck(bool on) async {
    try {
      final current = ref.read(appSettingsProvider);
      await ref.read(appSettingsProvider.notifier).update(current.copyWith(update: current.update.copyWith(autoCheck: on)));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari halaman izin: banner hilang bila izin sudah diberikan; pemasangan tetap menunggu ketukan Pasang.
    if (state == AppLifecycleState.resumed && _needsPermission) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    try {
      final allowed = await ref.read(updatePlatformProvider).canInstall();
      if (mounted && allowed) setState(() => _needsPermission = false);
    } on Object {
      // Biarkan banner tampil.
    }
  }

  Future<void> _install() async {
    final ok = await ref.read(updateControllerProvider.notifier).install();
    if (mounted) setState(() => _needsPermission = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(updateControllerProvider);
    final version = ref.watch(installedVersionProvider).value;
    final controller = ref.read(updateControllerProvider.notifier);
    final autoCheck = ref.watch(appSettingsProvider.select((s) => s.update.autoCheck));

    final (status, statusColor) = _status(l, state);
    final reason = state is UpdateFailed ? _reason(l, state.failure) : null;
    final release = switch (state) {
      UpdateAvailable(:final release) => release,
      UpdateDownloading(:final release) => release,
      UpdateReady(:final release) => release,
      UpdateFailed(:final release?) => release,
      _ => null,
    };
    // Tombol kecil di samping status: hanya saat belum ada rilis baru yang sedang ditangani.
    final trailing = switch (state) {
      UpdateIdle() || UpdateUpToDate() => TermulButton(
        label: l.updateCheck,
        size: TermulButtonSize.sm,
        expand: false,
        onPressed: controller.check,
      ),
      UpdateChecking() => TermulButton(
        label: l.updateCheck,
        size: TermulButtonSize.sm,
        expand: false,
        onPressed: null,
      ),
      UpdateFailed(release: null) => TermulButton(
        label: l.updateRetry,
        size: TermulButtonSize.sm,
        expand: false,
        onPressed: controller.check,
      ),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(TermulSpacing.space3, 0, TermulSpacing.space3, TermulSpacing.space3),
          child: Semantics(
            header: true,
            child: Text(
              l.settingsUpdateSection.toUpperCase(),
              style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
            ),
          ),
        ),
        DecoratedBox(
          key: const ValueKey('update-card'),
          decoration: BoxDecoration(
            color: TermulPalette.surface,
            borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
            border: Border.all(color: TermulPalette.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(TermulSpacing.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TermulSpacing.space5,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        container: true,
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(l.updateRowLabel, style: TermulText.body.copyWith(color: TermulPalette.ink)),
                            Text(status, style: TermulText.caption.copyWith(color: statusColor)),
                          ],
                        ),
                      ),
                    ),
                    if (trailing != null) ...[const SizedBox(width: TermulSpacing.space5), trailing],
                  ],
                ),
                if (reason != null)
                  Text(reason, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                if (release != null) ..._releaseBody(l, state, release, controller),
              ],
            ),
          ),
        ),
        const SizedBox(height: TermulSpacing.space3),
        SwitchRow(
          label: l.updateAutoCheckLabel,
          description: l.updateAutoCheckDesc,
          value: autoCheck,
          onChanged: _setAutoCheck,
        ),
        if (_saveFailed) ...[
          const SizedBox(height: TermulSpacing.space3),
          TermulBanner(
            tone: BannerTone.warn,
            title: l.settingsSaveFailedTitle,
            child: Text(l.settingsSaveFailedBody),
          ),
        ],
        const SizedBox(height: TermulSpacing.space6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space4),
          child: Text(
            version == null ? 'TermUL Mobile' : l.updateVersionFooter(version.name, version.build),
            key: const ValueKey('version-footer'),
            style: TermulText.caption.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.inkFaint),
          ),
        ),
      ],
    );
  }

  List<Widget> _releaseBody(AppLocalizations l, UpdateState state, ReleaseInfo release, UpdateController controller) {
    return [
      Text(
        l.updateSize(formatSize(release.apk.size)),
        style: TermulText.caption.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.inkMuted),
      ),
      if (release.notes.isNotEmpty)
        Semantics(
          label: l.updateNotesLabel,
          child: Container(
            key: const ValueKey('update-notes'),
            padding: const EdgeInsets.all(TermulSpacing.space5),
            decoration: BoxDecoration(
              color: TermulPalette.groundDeep,
              borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
            ),
            child: ReleaseNotes(release.notes, maxLines: 8),
          ),
        ),
      ...switch (state) {
        UpdateDownloading() => [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TermulSpacing.space2,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.verifying
                          ? l.updateVerifying
                          : l.updateProgress(formatSize(state.received), formatSize(state.total)),
                      style: TermulText.bodySm.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.inkMuted),
                    ),
                  ),
                  if (state.percent != null)
                    Text(
                      l.sftpTransferPercent(state.percent!),
                      style: TermulText.bodySm.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.accent),
                    ),
                ],
              ),
              Semantics(
                value: state.percent == null ? null : l.sftpTransferPercent(state.percent!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: state.percent == null ? null : state.percent! / 100,
                    minHeight: 4,
                    backgroundColor: TermulPalette.lineStrong,
                    color: TermulPalette.accent,
                  ),
                ),
              ),
              if (state.background && !state.verifying)
                Text(l.updateBackgroundNote, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
            ],
          ),
          if (!state.verifying) TermulButton(label: l.updateCancel, onPressed: controller.cancelDownload),
        ],
        UpdateReady() || UpdateFailed(readyPath: String()) => [
          if (_needsPermission)
            TermulBanner(
              tone: BannerTone.warn,
              title: l.updatePermissionTitle,
              action: TermulButton(
                label: l.updatePermissionOpen,
                size: TermulButtonSize.sm,
                expand: false,
                onPressed: () => ref.read(updatePlatformProvider).openInstallSettings(),
              ),
              child: Text(l.updatePermissionBody),
            ),
          TermulButton(
            label: state is UpdateFailed ? l.updateRetry : l.updateInstall,
            variant: TermulButtonVariant.primary,
            onPressed: _install,
          ),
          Text(l.updateInstallNote, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
        ],
        _ => [
          TermulButton(
            label: state is UpdateFailed ? l.updateRetry : l.updateDownload,
            variant: TermulButtonVariant.primary,
            onPressed: controller.download,
          ),
        ],
      },
    ];
  }

  static (String, Color) _status(AppLocalizations l, UpdateState state) => switch (state) {
    UpdateIdle() => (l.updateStatusIdle, TermulPalette.inkMuted),
    UpdateChecking() => (l.updateStatusChecking, TermulPalette.inkMuted),
    UpdateUpToDate(latest: null) => (l.updateStatusNoRelease, TermulPalette.inkMuted),
    UpdateUpToDate() => (l.updateStatusUpToDate, TermulPalette.ok),
    UpdateAvailable(:final release) => (l.updateStatusAvailable(release.version), TermulPalette.accent),
    UpdateDownloading(:final release) => (l.updateStatusDownloading(release.version), TermulPalette.accent),
    UpdateReady(:final release) => (l.updateStatusReady(release.version), TermulPalette.accent),
    UpdateFailed(release: null) => (l.updateStatusCheckFailed, TermulPalette.bad),
    UpdateFailed(failure: UpdateFailure.install) => (l.updateStatusInstallFailed, TermulPalette.bad),
    UpdateFailed(:final release?) => (l.updateStatusDownloadFailed(release.version), TermulPalette.bad),
  };

  static String _reason(AppLocalizations l, UpdateFailure failure) => switch (failure) {
    UpdateFailure.network => l.updateFailureNetwork,
    UpdateFailure.server => l.updateFailureServer,
    UpdateFailure.badRelease => l.updateFailureBadRelease,
    UpdateFailure.signature => l.updateFailureSignature,
    UpdateFailure.checksum => l.updateFailureChecksum,
    UpdateFailure.signer => l.updateFailureSigner,
    UpdateFailure.storage => l.updateFailureStorage,
    UpdateFailure.install => l.updateFailureInstall,
  };
}
