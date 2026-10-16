import 'dart:async';
import 'dart:io';

/// Memeriksa apakah [host]:[port] bisa dijangkau lewat TCP (tanpa login). Dipakai sebelum sambung ulang supaya
/// tidak membaca vault (prompt biometrik) saat jaringan belum ada.
typedef HostProbe = Future<bool> Function(String host, int port);

/// Probe TCP bawaan: berhasil bila soket terbuka sebelum [timeout]. Galat apa pun dianggap tidak terjangkau.
Future<bool> tcpProbe(String host, int port, {Duration timeout = const Duration(seconds: 4)}) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

/// Jeda antar percobaan sambung ulang: naik bertahap lalu tetap di nilai terakhir.
class ReconnectBackoff {
  const ReconnectBackoff([
    this.delays = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ],
  ]);

  /// Tidak boleh kosong.
  final List<Duration> delays;

  /// Jeda sebelum percobaan ke-[attempt] (mulai dari 0) setelah percobaan sebelumnya gagal.
  Duration delayAfter(int attempt) => delays[attempt < 0 ? 0 : (attempt >= delays.length ? delays.length - 1 : attempt)];
}
