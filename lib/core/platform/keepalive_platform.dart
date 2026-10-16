import 'package:flutter/services.dart';

/// Jembatan ke foreground service Android yang menjaga proses aplikasi tetap hidup selama ada sesi SSH aktif
/// (`android/.../KeepAliveService.kt`). Service ini tidak menyentuh soket; ia hanya mencegah Android membekukan
/// proses lalu menutup soket TCP-nya. Android saja (iOS tidak diuji dan tidak dicakup).
abstract interface class KeepAlivePlatform {
  /// Menyalakan atau memperbarui notifikasi dan service. Melempar [PlatformException] bila Android menolak
  /// (mis. aplikasi tidak terlihat saat service dimulai).
  Future<void> update({
    required String title,
    required String text,
    required String actionLabel,
    required String channelName,
  });

  /// Menghentikan service (tidak melakukan apa pun bila belum berjalan).
  Future<void> stop();

  /// Notifikasi diizinkan (izin runtime di Android 13 ke atas, dan tidak diblokir di pengaturan HP).
  Future<bool> notificationsEnabled();

  /// Meminta izin notifikasi; hasilnya sama dengan [notificationsEnabled] setelah pengguna menjawab.
  Future<bool> requestNotifications();

  /// Membuka halaman info aplikasi di pengaturan Android (tempat pembatasan baterai diatur).
  Future<void> openAppSettings();

  /// Dipanggil bila pengguna mengetuk "Putuskan semua" di notifikasi.
  void setDisconnectAllHandler(void Function()? handler);
}

/// Implementasi nyata lewat [MethodChannel].
class MethodChannelKeepAlive implements KeepAlivePlatform {
  MethodChannelKeepAlive([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/keepalive') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'disconnectAll') _onDisconnectAll?.call();
      return null;
    });
  }

  final MethodChannel _channel;
  void Function()? _onDisconnectAll;

  @override
  Future<void> update({
    required String title,
    required String text,
    required String actionLabel,
    required String channelName,
  }) => _channel.invokeMethod<void>('update', {
    'title': title,
    'text': text,
    'actionLabel': actionLabel,
    'channelName': channelName,
  });

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<bool> notificationsEnabled() async => await _channel.invokeMethod<bool>('notificationsEnabled') ?? false;

  @override
  Future<bool> requestNotifications() async => await _channel.invokeMethod<bool>('requestNotifications') ?? false;

  @override
  Future<void> openAppSettings() => _channel.invokeMethod<void>('openAppSettings');

  @override
  void setDisconnectAllHandler(void Function()? handler) => _onDisconnectAll = handler;
}

/// Tanpa efek (tes, atau platform tanpa service). Notifikasi dianggap diizinkan.
class NoopKeepAlive implements KeepAlivePlatform {
  const NoopKeepAlive();

  @override
  Future<void> update({
    required String title,
    required String text,
    required String actionLabel,
    required String channelName,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<void> openAppSettings() async {}

  @override
  void setDisconnectAllHandler(void Function()? handler) {}
}
