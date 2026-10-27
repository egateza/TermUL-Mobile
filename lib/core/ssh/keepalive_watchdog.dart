import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'connection_log.dart';

/// Membungkus soket SSH supaya setiap data masuk tercatat sebagai tanda hidup.
///
/// Dibutuhkan karena sebagian server (mis. MikroTik RouterOS) tidak menjawab `keepalive@openssh.com` dengan
/// `REQUEST_SUCCESS`/`REQUEST_FAILURE`; jawaban `SSH_MSG_UNIMPLEMENTED` ditelan `dartssh2` sehingga `ping()` tidak
/// pernah selesai walaupun koneksinya sehat.
class InboundActivitySocket implements SSHSocket {
  InboundActivitySocket(this._inner);

  final SSHSocket _inner;
  Completer<void>? _next;

  @override
  late final Stream<Uint8List> stream = _inner.stream.map((data) {
    final waiting = _next;
    _next = null;
    waiting?.complete();
    return data;
  });

  /// Selesai saat potongan data berikutnya datang dari server.
  Future<void> nextInbound() => (_next ??= Completer<void>()).future;

  @override
  StreamSink<List<int>> get sink => _inner.sink;

  @override
  Future<void> get done => _inner.done;

  @override
  Future<void> close() => _inner.close();

  @override
  void destroy() => _inner.destroy();

  @override
  Future<void> flush() => _inner.flush();
}

/// Memeriksa apakah sambungan masih hidup: hidup bila, dalam batas waktu, `ping` dibalas **atau** ada data apa pun
/// dari server. `ping` tetap dikirim tiap pemeriksaan karena itulah yang memancing jawaban (termasuk
/// `SSH_MSG_UNIMPLEMENTED`) dari server yang diam.
class KeepAliveProbe {
  KeepAliveProbe({required this.ping, required this.isClosed, this.nextInbound});

  final Future<void> Function() ping;
  final bool Function() isClosed;

  /// Selesai saat data berikutnya datang dari server; `null` = hanya mengandalkan balasan `ping`.
  final Future<void> Function()? nextInbound;

  bool _pingUnanswered = false;

  /// `true` setelah koneksi terbukti hidup lewat data masuk sementara `ping` tidak dibalas (mis. MikroTik).
  bool get pingUnanswered => _pingUnanswered;

  /// `false` bila batas waktu habis tanpa tanda hidup. Galat selain batas waktu (mis. klien sudah tertutup)
  /// diteruskan ke pemanggil.
  Future<bool> check(Duration timeout) async {
    if (isClosed()) return false;
    var answered = false;
    final waits = <Future<void>>[
      if (nextInbound != null) nextInbound!(),
      ping().then((_) => answered = true),
    ];
    try {
      await Future.any(waits).timeout(timeout);
    } on TimeoutException {
      return false;
    }
    if (!answered && !_pingUnanswered) {
      _pingUnanswered = true;
      connLog('keepalive: server tidak membalas ping global; tanda hidup dari data masuk');
    }
    return true;
  }
}

/// Pengawas keepalive dengan batas waktu balasan. Keepalive bawaan `dartssh2` mengirim ping tanpa batas waktu
/// dan menelan galatnya, sehingga sinyal hilang diam-diam (tanpa FIN) tidak pernah terdeteksi (K9 di spike).
///
/// Memanggil [KeepAliveProbe.check] tiap [interval]; bila tidak ada tanda hidup dalam [timeout], [onDead] dipanggil
/// lalu [onClose] (yang menutup klien dan menyelesaikan `client.done`). Dipakai bersama `keepAliveInterval: null`.
/// Terbukti di spike (A2): interval 2 s dan batas 3 s terdeteksi sekitar 5 s; aplikasi memakai 15 s dan 10 s.
Timer startKeepAliveWatchdog(
  KeepAliveProbe probe, {
  required void Function() onClose,
  Duration interval = const Duration(seconds: 15),
  Duration timeout = const Duration(seconds: 10),
  void Function()? onDead,
}) {
  var pinging = false;
  return Timer.periodic(interval, (timer) async {
    if (pinging) return;
    if (probe.isClosed()) {
      // Penutupan dilaporkan lewat client.done, bukan sebagai keepalive habis.
      timer.cancel();
      return;
    }
    pinging = true;
    try {
      if (!await probe.check(timeout)) {
        timer.cancel();
        onDead?.call();
        onClose();
      }
    } on Object {
      // Galat lain (mis. klien sudah tertutup): berhenti mengawasi; penutupan dilaporkan lewat client.done.
      timer.cancel();
    } finally {
      pinging = false;
    }
  });
}
