import 'dart:async';

import 'package:flutter/services.dart';

/// Memantau layar mati (`android/.../ScreenOffTracker.kt`). Dipakai untuk melepas rahasia yang dipegang di memori:
/// layar mati dianggap pengguna sudah tidak memakai aplikasi, jadi sambung ulang berikutnya minta biometrik lagi.
/// Android saja.
abstract interface class ScreenMonitor {
  /// Berapa kali layar mati sejak proses mulai. Penghitung ada di sisi Kotlin sehingga tetap benar walau Dart
  /// dibekukan saat layar mati; bandingkan nilai sebelum dan sesudah.
  Future<int> screenOffCount();

  /// Layar baru saja mati (hanya sampai bila Dart sedang berjalan; jangan diandalkan sendirian).
  Stream<void> get onScreenOff;
}

/// Implementasi nyata lewat [MethodChannel].
class MethodChannelScreenMonitor implements ScreenMonitor {
  MethodChannelScreenMonitor([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/screen') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'screenOff') _events.add(null);
      return null;
    });
  }

  final MethodChannel _channel;
  final _events = StreamController<void>.broadcast();

  @override
  Future<int> screenOffCount() async => await _channel.invokeMethod<int>('screenOffCount') ?? 0;

  @override
  Stream<void> get onScreenOff => _events.stream;
}

/// Tanpa efek (tes, atau platform tanpa pemantau): layar dianggap tidak pernah mati.
class NoopScreenMonitor implements ScreenMonitor {
  const NoopScreenMonitor();

  @override
  Future<int> screenOffCount() async => 0;

  @override
  Stream<void> get onScreenOff => const Stream.empty();
}
