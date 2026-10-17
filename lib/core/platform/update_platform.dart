import 'package:flutter/services.dart';

import '../update/release.dart';

/// Jembatan ke Android untuk pembaruan (`android/.../UpdateInstaller.kt`): versi terpasang, izin memasang aplikasi
/// dari sumber ini, dan membuka penginstal sistem. Android saja; setiap pemasangan tetap dikonfirmasi pengguna.
abstract interface class UpdatePlatform {
  /// `versionName` dan `versionCode` APK yang terpasang.
  Future<AppVersion> installedVersion();

  /// Aplikasi boleh meminta pemasangan paket ("Pasang aplikasi tidak dikenal" diizinkan untuk TermUL).
  Future<bool> canInstall();

  /// Isi APK di [path]: nama paket, versionCode, dan apakah sertifikatnya sama dengan aplikasi terpasang.
  Future<ApkInfo> inspectApk(String path);

  /// Membuka halaman izin "Pasang aplikasi tidak dikenal" untuk TermUL.
  Future<void> openInstallSettings();

  /// Membuka penginstal sistem untuk APK di [path] (harus di `cache/update/`). Melempar [PlatformException] bila
  /// tidak bisa dibuka.
  Future<void> install(String path);
}

/// Hasil [UpdatePlatform.inspectApk]. [packageName] null bila berkas bukan APK yang bisa dibaca.
class ApkInfo {
  const ApkInfo({required this.packageName, required this.versionCode, required this.sameSigner});

  final String? packageName;
  final int versionCode;
  final bool sameSigner;
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
  Future<ApkInfo> inspectApk(String path) async {
    final v = await _channel.invokeMapMethod<String, Object?>('inspect', {'path': path});
    final package = v?['package'];
    final code = v?['code'];
    return ApkInfo(
      packageName: package is String ? package : null,
      versionCode: code is int ? code : 0,
      sameSigner: v?['sameSigner'] == true,
    );
  }

  @override
  Future<void> openInstallSettings() => _channel.invokeMethod<void>('openInstallSettings');

  @override
  Future<void> install(String path) => _channel.invokeMethod<void>('install', {'path': path});
}

/// Nama paket aplikasi (`applicationId`).
const appPackageName = 'io.github.egateza.termul';

/// Untuk tes: versi tetap, izin bisa diatur, dan mencatat permintaan pasang.
class FakeUpdatePlatform implements UpdatePlatform {
  FakeUpdatePlatform({this.version = const AppVersion('0.1.0', 1), this.allowed = true});

  AppVersion version;
  bool allowed;

  /// Hasil [inspectApk]; tes mengisi [apkCode] dengan versionCode rilis supaya APK dianggap cocok.
  int apkCode = 0;
  bool apkSameSigner = true;
  String? apkPackage = appPackageName;
  Object? installError;
  final installed = <String>[];
  int settingsOpened = 0;

  @override
  Future<AppVersion> installedVersion() async => version;

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<ApkInfo> inspectApk(String path) async =>
      ApkInfo(packageName: apkPackage, versionCode: apkCode, sameSigner: apkSameSigner);

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<void> install(String path) async {
    if (installError != null) throw installError!;
    installed.add(path);
  }
}
