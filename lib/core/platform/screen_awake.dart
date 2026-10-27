import 'package:flutter/services.dart';

/// Menjaga layar tetap menyala selama ada pemegang (`FLAG_KEEP_SCREEN_ON` di jendela `MainActivity`). Bendera itu
/// hanya berlaku selama aplikasi terlihat; Android tetap boleh mematikan layar lewat tombol daya. Android saja.
abstract interface class ScreenAwake {
  /// [owner] meminta layar tetap menyala; aman dipanggil berulang.
  void acquire(Object owner);

  /// [owner] melepas permintaannya; layar padam normal lagi bila tidak ada pemegang lain.
  void release(Object owner);
}

/// Pemegang dihitung di Dart supaya beberapa layar terminal (sesi multi) tidak saling mematikan bendera.
class MethodChannelScreenAwake implements ScreenAwake {
  MethodChannelScreenAwake([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/window');

  final MethodChannel _channel;
  final _owners = <Object>{};

  @override
  void acquire(Object owner) {
    if (_owners.add(owner) && _owners.length == 1) _set(true);
  }

  @override
  void release(Object owner) {
    if (_owners.remove(owner) && _owners.isEmpty) _set(false);
  }

  Future<void> _set(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepScreenOn', {'on': on});
    } on PlatformException {
      // Jendela tidak tersedia (Activity sedang ditutup): tidak ada yang perlu dijaga.
    } on MissingPluginException {
      // Platform tanpa kanal (tes).
    }
  }
}
