import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/host_profile.dart';
import '../models/known_host.dart';
import '../storage/known_hosts_repository.dart';
import 'host_key_policy.dart';
import 'keepalive_watchdog.dart';
import 'ssh_failure.dart';

/// Cara login. Isinya rahasia: jangan dicatat dan jangan disimpan di field berumur panjang.
sealed class SshCredentials {
  const SshCredentials();
}

final class PasswordCredentials extends SshCredentials {
  const PasswordCredentials(this.password);

  final String password;
}

final class KeyCredentials extends SshCredentials {
  const KeyCredentials(this.pem, {this.passphrase});

  final String pem;

  /// `null` atau kosong untuk kunci tanpa passphrase.
  final String? passphrase;
}

/// Pilihan pengguna saat host key perlu diputuskan.
enum HostKeyChoice {
  /// Host baru: percayai dan simpan permanen.
  trustAndSave,

  /// Host baru: sambung kali ini saja, tidak disimpan.
  connectOnce,

  /// Host key berubah: ganti sidik jari tersimpan setelah pengguna memastikan perubahannya sah.
  replaceAndTrust,

  /// Batalkan koneksi.
  reject,
}

/// Bahan keputusan yang ditampilkan ke pengguna (layar verifikasi host key).
class HostKeyChallenge {
  const HostKeyChallenge({
    required this.host,
    required this.port,
    required this.type,
    required this.fingerprint,
    required this.verdict,
    required this.storedFingerprints,
  });

  final String host;
  final int port;

  /// Keluarga kunci, mis. `ssh-ed25519`, `ssh-rsa`.
  final String type;

  /// `SHA256:...`, sama dengan `ssh-keygen -lf`.
  final String fingerprint;

  /// [HostKeyVerdict.newHost] atau [HostKeyVerdict.changed].
  final HostKeyVerdict verdict;

  /// Sidik jari tersimpan untuk `host:port` ini (kosong untuk host baru), untuk ditampilkan berdampingan.
  final List<String> storedFingerprints;
}

typedef HostKeyDecider = Future<HostKeyChoice> Function(HostKeyChallenge challenge);

typedef SocketFactory = Future<SSHSocket> Function(String host, int port, Duration timeout);

enum CloseReason { userClosed, serverClosed, keepAliveTimeout, error }

/// Sambungan SSH yang sudah terautentikasi. Menutup sendiri bila keepalive tidak dibalas.
class SshConnection {
  SshConnection._(this.client, this.profile) {
    client.done.then<void>((_) => _finish(CloseReason.serverClosed), onError: (Object _) => _finish(CloseReason.error));
  }

  final SSHClient client;
  final HostProfile profile;
  Timer? _watchdog;
  CloseReason? _reason;
  final _closed = Completer<CloseReason>();

  /// Selesai sekali, saat sambungan tertutup (alasan pertama yang tercatat dipakai).
  Future<CloseReason> get closed => _closed.future;

  bool get isClosed => client.isClosed;

  CloseReason? get closeReason => _reason;

  void _finish(CloseReason fallback) {
    _watchdog?.cancel();
    _reason ??= fallback;
    if (!_closed.isCompleted) _closed.complete(_reason);
  }

  void _startWatchdog({required Duration interval, required Duration timeout}) {
    _watchdog = startKeepAliveWatchdog(
      client,
      interval: interval,
      timeout: timeout,
      onDead: () => _reason ??= CloseReason.keepAliveTimeout,
    );
  }

  /// Menutup atas permintaan pengguna.
  void close() {
    _reason ??= CloseReason.userClosed;
    _watchdog?.cancel();
    client.close();
  }

  /// Memeriksa apakah sambungan masih hidup (dipakai saat kembali dari latar belakang): sudah tertutup, atau
  /// `ping` tidak dibalas dalam [timeout]. Terbukti di spike (A4); batas 5 detik.
  Future<bool> checkAlive({Duration timeout = const Duration(seconds: 5)}) async {
    if (client.isClosed) return false;
    try {
      await client.ping().timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  }
}

/// Membuka sambungan SSH langsung dari perangkat. Aturan keamanan:
/// - Host key diverifikasi lewat [KnownHostsRepository]; sidik jari baru ditulis permanen **sebelum** login
///   dilanjutkan, dan bila penulisan gagal koneksi dibatalkan.
/// - Host key yang berubah memblokir koneksi kecuali pengguna eksplisit memilih [HostKeyChoice.replaceAndTrust].
/// - Algoritma host key dibatasi ke keluarga yang tersimpan untuk host itu.
/// - ChaCha20-Poly1305 didahulukan (AES-GCM di Dart murni sekitar 1 MB/s; spike A3).
/// - Keepalive buatan sendiri (`keepAliveInterval: null` agar tidak ganda).
class SshConnector {
  SshConnector({
    required this.knownHosts,
    SocketFactory? socketFactory,
    this.connectTimeout = const Duration(seconds: 15),
    this.handshakeBudget = const Duration(seconds: 20),
    this.authBudget = const Duration(seconds: 30),
    this.keepAliveInterval = const Duration(seconds: 15),
    this.keepAliveTimeout = const Duration(seconds: 10),
  }) : _socketFactory = socketFactory ?? _defaultSocket;

  final KnownHostsRepository knownHosts;
  final SocketFactory _socketFactory;
  final Duration connectTimeout;

  /// Batas sampai host key diterima (tidak termasuk waktu pengguna memutuskan).
  final Duration handshakeBudget;

  /// Batas dari keputusan host key sampai login selesai.
  final Duration authBudget;
  final Duration keepAliveInterval;
  final Duration keepAliveTimeout;

  static Future<SSHSocket> _defaultSocket(String host, int port, Duration timeout) =>
      SSHSocket.connect(host, port, timeout: timeout);

  static const cipherOrder = [
    SSHCipherType.chacha20poly1305,
    SSHCipherType.aes256ctr,
    SSHCipherType.aes128ctr,
    SSHCipherType.aes256gcm,
    SSHCipherType.aes128gcm,
  ];

  /// Menyambung dan login. Melempar [SshFailure] (tidak pernah galat paket mentah).
  Future<SshConnection> connect({
    required HostProfile profile,
    required SshCredentials credentials,
    required HostKeyDecider decideHostKey,
  }) async {
    final List<SSHKeyPair>? identities;
    try {
      identities = switch (credentials) {
        KeyCredentials(:final pem, :final passphrase) => SSHKeyPair.fromPem(
          pem,
          (passphrase == null || passphrase.isEmpty) ? null : passphrase,
        ),
        PasswordCredentials() => null,
      };
    } on SSHKeyDecryptError catch (e) {
      throw SshKeyUnusable(wrongPassphrase: true, cause: e);
    } on Object catch (e) {
      throw SshKeyUnusable(wrongPassphrase: false, cause: e);
    }

    final stored = knownHosts.entriesFor(profile.host, profile.port);
    var outcome = _HostKeyOutcome.none;
    var timedOut = false;
    Timer? deadline;
    late final SSHClient client;

    void armDeadline(Duration d) {
      deadline?.cancel();
      deadline = Timer(d, () {
        timedOut = true;
        client.close();
      });
    }

    Future<bool> verify(String algorithm, Uint8List fingerprintBytes) async {
      deadline?.cancel(); // waktu pengguna memutuskan tidak dihitung
      try {
        final fp = utf8.decode(fingerprintBytes);
        final family = hostKeyFamily(algorithm);
        final verdict = evaluateHostKey(stored, type: family, fingerprint: fp);
        if (verdict == HostKeyVerdict.trusted) return true;

        final choice = await decideHostKey(
          HostKeyChallenge(
            host: profile.host,
            port: profile.port,
            type: family,
            fingerprint: fp,
            verdict: verdict,
            storedFingerprints: [for (final k in stored) k.fingerprint],
          ),
        );
        final entry = KnownHost(
          host: profile.host,
          port: profile.port,
          type: family,
          fingerprint: fp,
          addedAt: DateTime.now(),
        );
        switch ((verdict, choice)) {
          case (HostKeyVerdict.newHost, HostKeyChoice.trustAndSave):
            try {
              await knownHosts.add(entry); // permanen sebelum login dilanjutkan
            } on Object {
              outcome = _HostKeyOutcome.storeFailed;
              return false;
            }
            return true;
          case (HostKeyVerdict.newHost, HostKeyChoice.connectOnce):
            return true;
          case (HostKeyVerdict.changed, HostKeyChoice.replaceAndTrust):
            try {
              await knownHosts.replace(entry);
            } on Object {
              outcome = _HostKeyOutcome.storeFailed;
              return false;
            }
            return true;
          default:
            outcome = verdict == HostKeyVerdict.changed ? _HostKeyOutcome.changedRejected : _HostKeyOutcome.rejected;
            return false;
        }
      } finally {
        armDeadline(authBudget);
      }
    }

    final SSHSocket socket;
    try {
      socket = await _socketFactory(profile.host, profile.port, connectTimeout);
    } on SocketException catch (e) {
      throw SshNetworkFailure('Tidak bisa tersambung ke server', e);
    } on TimeoutException catch (e) {
      throw SshNetworkFailure('Waktu sambung habis', e);
    }

    client = SSHClient(
      socket,
      username: profile.username,
      onPasswordRequest: switch (credentials) {
        PasswordCredentials(:final password) => () => password,
        KeyCredentials() => null,
      },
      identities: identities,
      onVerifyHostKey: verify,
      algorithms: SSHAlgorithms(cipher: cipherOrder, hostkey: hostKeyAlgorithmsFor(stored)),
      keepAliveInterval: null,
    );
    armDeadline(handshakeBudget);

    try {
      await client.authenticated;
    } on Object catch (e) {
      deadline?.cancel();
      client.close();
      throw _map(e, outcome, timedOut);
    }
    deadline?.cancel();
    final connection = SshConnection._(client, profile)
      .._startWatchdog(interval: keepAliveInterval, timeout: keepAliveTimeout);
    return connection;
  }

  /// Memetakan galat paket ke [SshFailure]. Alasan penolakan host key dicatat sendiri karena `dartssh2` hanya
  /// melaporkan `SSHAuthAbortError` ("Connection closed before authentication").
  static SshFailure _map(Object e, _HostKeyOutcome outcome, bool timedOut) {
    switch (outcome) {
      case _HostKeyOutcome.rejected:
        return const SshHostKeyRejected(changed: false);
      case _HostKeyOutcome.changedRejected:
        return const SshHostKeyRejected(changed: true);
      case _HostKeyOutcome.storeFailed:
        return SshHostKeyStoreFailure(e);
      case _HostKeyOutcome.none:
        break;
    }
    if (timedOut) return SshNetworkFailure('Waktu habis menunggu server', e);
    return switch (e) {
      SSHAuthFailError() => SshAuthFailure(e),
      SSHAuthAbortError() => SshNetworkFailure('Server menutup koneksi sebelum login selesai', e),
      SSHHandshakeError() => SshHandshakeFailure('Negosiasi dengan server gagal', e),
      SSHHostkeyError() => SshHandshakeFailure('Tanda tangan host key tidak sah', e),
      SSHSocketError() || SocketException() => SshNetworkFailure('Koneksi terputus', e),
      TimeoutException() => SshNetworkFailure('Waktu habis', e),
      _ => SshUnknownFailure('Gagal menyambung', e),
    };
  }
}

enum _HostKeyOutcome { none, rejected, changedRejected, storeFailed }
