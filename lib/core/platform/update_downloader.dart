import 'package:flutter/services.dart';

/// Keadaan unduhan pembaruan di DownloadManager sistem.
enum BackgroundDownloadStatus { pending, running, paused, done, failed, missing }

/// Unduhan yang dicatat [UpdateDownloader]. [path] hanya terisi saat [status] `done` (berkas di folder unduhan
/// aplikasi, belum diperiksa). [reason]: kode alasan DownloadManager untuk `failed` dan `paused`.
class BackgroundDownload {
  const BackgroundDownload({
    required this.versionCode,
    required this.status,
    this.received = 0,
    this.total = -1,
    this.reason = 0,
    this.path,
  });

  final int versionCode;
  final BackgroundDownloadStatus status;
  final int received;
  final int total;
  final int reason;
  final String? path;

  /// Alasan DownloadManager yang berarti penyimpanan bermasalah (`ERROR_FILE_ERROR`, `ERROR_INSUFFICIENT_SPACE`,
  /// `ERROR_DEVICE_NOT_FOUND`).
  bool get storageFailure => reason == 1001 || reason == 1006 || reason == 1007;

  /// Kode HTTP dari server (DownloadManager memakai kode HTTP sebagai alasan gagal).
  bool get serverFailure => reason >= 400 && reason < 600;
}

/// Gagal memulai unduhan lewat sistem (DownloadManager dimatikan, penyimpanan eksternal tidak tersedia).
class BackgroundDownloadUnavailable implements Exception {
  const BackgroundDownloadUnavailable([this.cause]);

  final Object? cause;

  @override
  String toString() => 'BackgroundDownloadUnavailable($cause)';
}

/// Unduhan APK pembaruan lewat DownloadManager Android (`android/.../UpdateDownloader.kt`), supaya tetap berjalan
/// walau aplikasi ditutup atau prosesnya dimatikan. Satu unduhan aktif dicatat di sisi Android. Android saja.
abstract interface class UpdateDownloader {
  /// Memulai unduhan; unduhan sebelumnya dibatalkan. Teks `done*` dipakai notifikasi "siap dipasang" yang dipasang
  /// Android saat unduhan selesai. Melempar [BackgroundDownloadUnavailable] bila sistem tidak bisa mengunduh.
  Future<void> enqueue({
    required Uri url,
    required String fileName,
    required String title,
    required int versionCode,
    required String version,
    required String doneTitle,
    required String doneText,
    required String channelName,
  });

  /// Unduhan yang dicatat, atau null bila tidak ada (juga bila kanal tidak tersedia).
  Future<BackgroundDownload?> active();

  /// Membatalkan unduhan yang dicatat, menghapus berkas dan notifikasinya.
  Future<void> remove();
}

class MethodChannelUpdateDownloader implements UpdateDownloader {
  MethodChannelUpdateDownloader([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/update');

  final MethodChannel _channel;

  @override
  Future<void> enqueue({
    required Uri url,
    required String fileName,
    required String title,
    required int versionCode,
    required String version,
    required String doneTitle,
    required String doneText,
    required String channelName,
  }) async {
    try {
      await _channel.invokeMethod<int>('downloadEnqueue', {
        'url': url.toString(),
        'fileName': fileName,
        'title': title,
        'versionCode': versionCode,
        'version': version,
        'doneTitle': doneTitle,
        'doneText': doneText,
        'channelName': channelName,
      });
    } on PlatformException catch (e) {
      throw BackgroundDownloadUnavailable(e.message);
    } on MissingPluginException catch (e) {
      throw BackgroundDownloadUnavailable(e);
    }
  }

  @override
  Future<BackgroundDownload?> active() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('downloadActive');
      if (m == null) return null;
      int asInt(Object? v, int fallback) => v is int ? v : fallback;
      final status = BackgroundDownloadStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => BackgroundDownloadStatus.failed,
      );
      final path = m['path'];
      return BackgroundDownload(
        versionCode: asInt(m['versionCode'], 0),
        status: status,
        received: asInt(m['received'], 0),
        total: asInt(m['total'], -1),
        reason: asInt(m['reason'], 0),
        path: path is String ? path : null,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> remove() async {
    try {
      await _channel.invokeMethod<void>('downloadRemove');
    } on PlatformException {
      // Tidak ada yang bisa dibatalkan.
    } on MissingPluginException {
      // Platform tanpa kanal (tes).
    }
  }
}
