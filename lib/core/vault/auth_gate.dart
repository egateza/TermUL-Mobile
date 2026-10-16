import 'dart:async';

/// Gerbang bersama untuk pembacaan vault yang memunculkan prompt biometrik:
/// - [run] memberi giliran satu per satu, supaya dua sesi yang butuh rahasia tidak membuka dua prompt sekaligus
///   (prompt kedua membatalkan yang pertama);
/// - [recordDenied] mengingat prompt yang dibatalkan atau gagal, supaya sambung ulang otomatis tidak memunculkan
///   prompt lagi selama [window]; pengguna menekan tombol untuk menampilkannya.
class AuthGate {
  AuthGate({this.window = const Duration(seconds: 30), DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;
  Future<void> _tail = Future.value();
  DateTime? _deniedAt;

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  /// Prompt dibatalkan atau gagal baru-baru ini (dalam [window]).
  bool get recentlyDenied {
    final at = _deniedAt;
    return at != null && _now().difference(at) < window;
  }

  void recordDenied() => _deniedAt = _now();

  void clearDenied() => _deniedAt = null;
}
