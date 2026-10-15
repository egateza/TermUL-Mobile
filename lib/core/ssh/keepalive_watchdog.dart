import 'dart:async';

import 'package:dartssh2/dartssh2.dart';

/// Pengawas keepalive dengan batas waktu balasan. Keepalive bawaan `dartssh2` mengirim ping tanpa batas waktu
/// dan menelan galatnya, sehingga sinyal hilang diam-diam (tanpa FIN) tidak pernah terdeteksi (K9 di spike).
///
/// Memanggil `client.ping()` tiap [interval]; bila tidak dibalas dalam [timeout], [onDead] dipanggil lalu
/// klien ditutup (yang menyelesaikan `client.done`). Dipakai bersama `keepAliveInterval: null`.
/// Terbukti di spike (A2): interval 2 s dan batas 3 s terdeteksi sekitar 5 s; aplikasi memakai 15 s dan 10 s.
Timer startKeepAliveWatchdog(
  SSHClient client, {
  Duration interval = const Duration(seconds: 15),
  Duration timeout = const Duration(seconds: 10),
  void Function()? onDead,
}) {
  var pinging = false;
  return Timer.periodic(interval, (timer) async {
    if (pinging) return;
    pinging = true;
    try {
      await client.ping().timeout(timeout);
    } on TimeoutException {
      timer.cancel();
      onDead?.call();
      client.close();
    } on Object {
      // Galat lain (mis. klien sudah tertutup): berhenti mengawasi; penutupan dilaporkan lewat client.done.
      timer.cancel();
    } finally {
      pinging = false;
    }
  });
}
