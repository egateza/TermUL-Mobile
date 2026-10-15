/// Kegagalan menyambung, sudah dipetakan dari galat `dartssh2` dan soket supaya UI tidak bergantung pada tipe
/// galat paket (mis. penolakan host key dilaporkan `dartssh2` sebagai `SSHAuthAbortError`). Pesan tidak pernah
/// memuat rahasia.
sealed class SshFailure implements Exception {
  const SshFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Soket tidak tersambung, waktu habis, atau server menutup koneksi sebelum login.
final class SshNetworkFailure extends SshFailure {
  const SshNetworkFailure(super.message, [super.cause]);
}

/// Negosiasi algoritma atau protokol gagal (mis. server lama tanpa algoritma yang kita izinkan).
final class SshHandshakeFailure extends SshFailure {
  const SshHandshakeFailure(super.message, [super.cause]);
}

/// Pengguna menolak host key, atau menolak mengganti host key yang berubah. [changed] true bila yang ditolak
/// adalah host key yang berubah.
final class SshHostKeyRejected extends SshFailure {
  const SshHostKeyRejected({required this.changed}) : super(changed ? 'Host key berubah ditolak' : 'Host key ditolak');

  final bool changed;
}

/// Sidik jari tidak bisa disimpan permanen, jadi koneksi dibatalkan (tidak boleh lanjut tanpa catatan).
final class SshHostKeyStoreFailure extends SshFailure {
  const SshHostKeyStoreFailure([Object? cause]) : super('Sidik jari host tidak bisa disimpan', cause);
}

/// Server menolak password atau kunci.
final class SshAuthFailure extends SshFailure {
  const SshAuthFailure([Object? cause]) : super('Login ditolak server', cause);
}

/// Kunci privat tersimpan tidak bisa dipakai (passphrase tidak cocok atau kunci rusak).
final class SshKeyUnusable extends SshFailure {
  const SshKeyUnusable({required this.wrongPassphrase, Object? cause})
    : super(wrongPassphrase ? 'Passphrase kunci salah' : 'Kunci tidak bisa dibaca', cause);

  final bool wrongPassphrase;
}

final class SshUnknownFailure extends SshFailure {
  const SshUnknownFailure(super.message, [super.cause]);
}
