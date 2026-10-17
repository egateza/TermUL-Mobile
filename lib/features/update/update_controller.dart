import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/update_platform.dart';
import '../../core/update/release.dart';
import '../../core/update/update_service.dart';

/// Repo rilis aplikasi di GitHub.
const updateRepo = 'egateza/TermUL-Mobile';

/// Jembatan Android untuk pembaruan; bawaan versi tetap (tes), bootstrap memasang yang nyata.
final updatePlatformProvider = Provider<UpdatePlatform>((ref) => FakeUpdatePlatform());

/// Sumber rilis; bawaan tanpa jaringan dan tanpa rilis (tes), bootstrap memasang GitHub.
final updateServiceProvider = Provider<UpdateService>((ref) => const NoReleaseUpdateService());

/// Versi yang terpasang (dibaca sekali dari Android).
final installedVersionProvider = FutureProvider<AppVersion>((ref) => ref.watch(updatePlatformProvider).installedVersion());

/// Keadaan pembaruan. Satu untuk seluruh aplikasi: pengecekan saat dibuka, layar Pengaturan, dan lencana tab.
sealed class UpdateState {
  const UpdateState();

  /// Ada versi baru yang belum dipasang (lencana di tab Pengaturan).
  bool get hasUpdate => false;
}

/// Belum diperiksa sejak aplikasi dibuka.
class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

/// Versi terpasang adalah yang terbaru (atau lebih baru dari rilis).
class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate(this.latest);

  /// Rilis terbaru; null bila repo belum punya rilis.
  final ReleaseInfo? latest;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);

  final ReleaseInfo release;

  @override
  bool get hasUpdate => true;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.release, {required this.received, required this.total, required this.cancel});

  final ReleaseInfo release;
  final int received;
  final int total;
  final UpdateCancelToken cancel;

  /// 0-100, atau null bila ukuran tidak diketahui.
  int? get percent => total <= 0 ? null : (received * 100 ~/ total).clamp(0, 100);

  @override
  bool get hasUpdate => true;
}

/// APK sudah diunduh dan cocok dengan checksum; tinggal dipasang.
class UpdateReady extends UpdateState {
  const UpdateReady(this.release, this.path);

  final ReleaseInfo release;
  final String path;

  @override
  bool get hasUpdate => true;
}

/// Gagal memeriksa ([release] null) atau gagal mengunduh atau memasang [release].
class UpdateFailed extends UpdateState {
  const UpdateFailed(this.failure, {this.release, this.readyPath});

  final UpdateFailure failure;
  final ReleaseInfo? release;

  /// Berkas siap pasang yang masih ada (gagal membuka penginstal).
  final String? readyPath;

  @override
  bool get hasUpdate => release != null;
}

class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateIdle();

  bool get _busy => state is UpdateChecking || state is UpdateDownloading;

  /// Memeriksa rilis terbaru. Diabaikan selagi memeriksa atau mengunduh, dan selagi berkas siap pasang ada.
  Future<void> check() async {
    if (_busy || state is UpdateReady) return;
    state = const UpdateChecking();
    try {
      final installed = await ref.read(installedVersionProvider.future);
      final latest = await ref.read(updateServiceProvider).latest();
      if (!ref.mounted) return;
      state = latest != null && latest.version.isNewerThan(installed)
          ? UpdateAvailable(latest)
          : UpdateUpToDate(latest);
    } on UpdateException catch (e) {
      debugPrint('[termul] periksa pembaruan gagal: $e');
      if (ref.mounted) state = UpdateFailed(e.failure);
    } on Object catch (e) {
      debugPrint('[termul] periksa pembaruan gagal: ${e.runtimeType}');
      if (ref.mounted) state = const UpdateFailed(UpdateFailure.network);
    }
  }

  /// Mengunduh APK rilis yang tersedia; selesai di [UpdateReady] bila checksum cocok.
  Future<void> download() async {
    final release = switch (state) {
      UpdateAvailable(:final release) => release,
      UpdateFailed(:final release?) => release,
      _ => null,
    };
    if (release == null) return;
    final cancel = UpdateCancelToken();
    state = UpdateDownloading(release, received: 0, total: release.apk.size, cancel: cancel);
    try {
      final path = await ref
          .read(updateServiceProvider)
          .download(
            release,
            cancel: cancel,
            onProgress: (received, total) {
              if (!_owns(cancel)) return;
              final current = state as UpdateDownloading;
              // Lewati pembaruan yang tidak mengubah persen supaya layar tidak dibangun ulang tiap potongan data.
              if (current.total == total) {
                final next = UpdateDownloading(release, received: received, total: total, cancel: cancel);
                if (next.percent == current.percent && received != total) return;
              }
              state = UpdateDownloading(release, received: received, total: total, cancel: cancel);
            },
          );
      if (_owns(cancel)) state = UpdateReady(release, path);
    } on UpdateCancelled {
      // Keadaan sudah dikembalikan oleh [cancelDownload].
    } on UpdateException catch (e) {
      debugPrint('[termul] unduh pembaruan gagal: $e');
      if (_owns(cancel)) state = UpdateFailed(e.failure, release: release);
    }
  }

  /// Keadaan masih milik unduhan dengan token [cancel] (belum dibatalkan atau diganti unduhan lain).
  bool _owns(UpdateCancelToken cancel) {
    if (!ref.mounted || cancel.isCancelled) return false;
    final current = state;
    return current is UpdateDownloading && identical(current.cancel, cancel);
  }

  /// Membatalkan unduhan yang sedang berjalan; kembali ke [UpdateAvailable].
  void cancelDownload() {
    final current = state;
    if (current is! UpdateDownloading) return;
    current.cancel.cancel();
    state = UpdateAvailable(current.release);
  }

  /// Membuka penginstal sistem. Mengembalikan false tanpa mengubah keadaan bila izin "Pasang aplikasi tidak dikenal"
  /// belum diberikan (layar menampilkan penjelasannya).
  Future<bool> install() async {
    final (release, path) = switch (state) {
      UpdateReady(:final release, :final path) => (release, path),
      UpdateFailed(:final release?, readyPath: final path?) => (release, path),
      _ => (null, null),
    };
    if (release == null || path == null) return true;
    final platform = ref.read(updatePlatformProvider);
    try {
      if (!await platform.canInstall()) return false;
      await platform.install(path);
      if (ref.mounted) state = UpdateReady(release, path);
    } on PlatformException catch (e) {
      debugPrint('[termul] membuka penginstal gagal: ${e.code}');
      if (ref.mounted) state = UpdateFailed(UpdateFailure.install, release: release, readyPath: path);
    }
    return true;
  }
}

final updateControllerProvider = NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
