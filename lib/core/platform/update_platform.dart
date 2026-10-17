import 'package:flutter/services.dart';

import '../update/release.dart';

/// Jembatan ke Android untuk pembaruan (`android/.../UpdateInstaller.kt`): versi terpasang, izin memasang aplikasi
/// dari sumber ini, dan membuka penginstal sistem. Android saja; setiap pemasangan tetap dikonfirmasi pengguna.
abstract interface class UpdatePlatform {
  /// `versionName` dan `versionCode` APK yang terpasang.
  Future<AppVersion> installedVersion();

  /// Aplikasi boleh meminta pemasangan paket ("Pasang aplikasi tidak dikenal" diizinkan untuk TermUL).
  Future<bool> canInstall();

  /// Membuka halaman izin "Pasang aplikasi tidak dikenal" untuk TermUL.
  Future<void> openInstallSettings();

  /// Membuka penginstal sistem untuk APK di [path] (harus di `cache/update/`). Melempar [PlatformException] bila
  /// tidak bisa dibuka.
  Future<void> install(String path);
}

class MethodChannelUpdatePlatform implements UpdatePlatform {
  MethodChannelUpdatePlatform([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/update');

  final MethodChannel _channel;

  @override
  Future<AppVersion> installedVersion() async {
    final v = await _channel.invokeMapMethod<String, Object?>('version');
    final name = v?['name'];
    final code = v?['code'];
    return AppVersion(name is String ? name : '?', code is int ? code : 0);
  }

  @override
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallSettings() => _channel.invokeMethod<void>('openInstallSettings');

  @override
  Future<void> install(String path) => _channel.invokeMethod<void>('install', {'path': path});
}

/// Untuk tes: versi tetap, izin bisa diatur, dan mencatat permintaan pasang.
class FakeUpdatePlatform implements UpdatePlatform {
  FakeUpdatePlatform({this.version = const AppVersion('0.1.0', 1), this.allowed = true});

  AppVersion version;
  bool allowed;
  Object? installError;
  final installed = <String>[];
  int settingsOpened = 0;

  @override
  Future<AppVersion> installedVersion() async => version;

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<void> install(String path) async {
    if (installError != null) throw installError!;
    installed.add(path);
  }
}
