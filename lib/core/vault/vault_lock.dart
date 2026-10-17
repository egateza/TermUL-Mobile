import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/screen_monitor.dart';
import 'device_auth.dart';

/// Status "vault terbuka" yang melonggarkan gerbang biometrik saat rahasia dibaca untuk sambung.
///
/// - **Buka sementara** ([unlock]): satu kali autentikasi perangkat, lalu semua host tersambung tanpa prompt.
///   Layar mati menguncinya lagi (penghitung layar mati di sisi Kotlin, seperti pelepasan rahasia di 11f); proses
///   yang dimatikan membuatnya terkunci karena status ada di memori.
/// - **Selalu terbuka** ([alwaysOpen]): pilihan pemilik di Pengaturan; gerbang dilewati terus.
///
/// Penyimpanan rahasia tidak berubah (tetap terenkripsi Keystore); yang dilonggarkan hanya prompt sebelum baca.
class VaultLock extends ChangeNotifier {
  VaultLock({required this._auth, ScreenMonitor? screen, this._alwaysOpen = false})
    : _screen = screen ?? const NoopScreenMonitor() {
    _sub = _screen.onScreenOff.listen((_) => lock());
  }

  final DeviceAuth _auth;
  final ScreenMonitor _screen;
  late final StreamSubscription<void> _sub;

  bool _alwaysOpen;
  bool _tempOpen = false;
  int _screenOffAtOpen = 0;

  bool get alwaysOpen => _alwaysOpen;

  /// Terbuka sementara (tanpa memeriksa layar mati; [isOpen] yang memeriksa).
  bool get tempOpen => _tempOpen;

  /// Status untuk tampilan: terbuka sementara atau permanen.
  bool get openNow => _alwaysOpen || _tempOpen;

  set alwaysOpen(bool value) {
    if (_alwaysOpen == value) return;
    _alwaysOpen = value;
    if (!value) _tempOpen = false;
    notifyListeners();
  }

  /// Apakah gerbang boleh dilewati sekarang. Membandingkan penghitung layar mati, jadi tetap benar walau Dart
  /// dibekukan saat layar mati dan peristiwanya tidak sampai.
  Future<bool> isOpen() async {
    if (_alwaysOpen) return true;
    if (!_tempOpen) return false;
    int count;
    try {
      count = await _screen.screenOffCount();
    } on Object {
      // Tidak bisa memastikan layar: gagal tertutup.
      lock();
      return false;
    }
    if (count != _screenOffAtOpen) {
      lock();
      return false;
    }
    return true;
  }

  /// Meminta autentikasi perangkat. true bila lolos (atau HP tanpa penguncian layar, yang memang tanpa prompt).
  /// Tidak mengubah status; dipakai [unlock] dan saklar permanen.
  Future<bool> authenticate(String reason) async {
    if (await _auth.level() == AuthLevel.none) return true;
    try {
      return await _auth.authenticate(reason);
    } on Object {
      return false;
    }
  }

  /// Membuka sementara setelah [authenticate] lolos.
  Future<bool> unlock(String reason) async {
    if (!await authenticate(reason)) return false;
    try {
      _screenOffAtOpen = await _screen.screenOffCount();
    } on Object {
      return false;
    }
    _tempOpen = true;
    notifyListeners();
    return true;
  }

  /// Mengunci lagi buka sementara. Tidak berpengaruh pada [alwaysOpen].
  void lock() {
    if (!_tempOpen) return;
    _tempOpen = false;
    notifyListeners();
  }

  /// Memeriksa ulang setelah aplikasi kembali terlihat (layar mungkin mati saat Dart dibekukan).
  Future<void> refresh() async {
    if (_tempOpen) await isOpen();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
