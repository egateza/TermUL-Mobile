import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/auth_method.dart';
import '../../core/models/host_profile.dart';
import '../../core/ssh/ssh_connector.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../core/storage/host_repository.dart';
import '../../core/vault/credential_vault.dart';
import '../../core/vault/secret_type.dart';
import '../../core/vault/vault_exceptions.dart';

typedef ConnectFunction = Future<SshConnection> Function({
  required HostProfile profile,
  required SshCredentials credentials,
  required HostKeyDecider decideHostKey,
});

/// Keadaan alur sambung ke satu host.
sealed class ConnectState {
  const ConnectState();
}

/// Membuka rahasia dari vault (bisa menampilkan prompt sidik jari atau PIN).
final class ConnectPreparing extends ConnectState {
  const ConnectPreparing();
}

/// Menyambung dan login.
final class ConnectConnecting extends ConnectState {
  const ConnectConnecting();
}

/// Menunggu keputusan pengguna tentang host key. Jawab lewat [ConnectFlow.answerHostKey].
final class ConnectNeedsHostKey extends ConnectState {
  const ConnectNeedsHostKey(this.challenge);

  final HostKeyChallenge challenge;
}

/// Rahasia tidak ada di vault (Keystore tidak berlaku atau baris host ada tanpa rahasia): minta dimasukkan ulang.
final class ConnectNeedsSecret extends ConnectState {
  const ConnectNeedsSecret({required this.method, this.wrongPassphrase = false});

  final AuthMethod method;

  /// true bila yang bermasalah passphrase kunci tersimpan (tidak cocok atau kunci rusak).
  final bool wrongPassphrase;
}

/// Autentikasi perangkat (sidik jari, PIN, pola) dibatalkan atau tidak bisa dipakai; rahasia tidak dibaca.
final class ConnectAuthDenied extends ConnectState {
  const ConnectAuthDenied({required this.cancelled});

  final bool cancelled;
}

final class ConnectFailed extends ConnectState {
  const ConnectFailed(this.failure);

  final SshFailure failure;
}

/// Tersambung. Pemilik keadaan ini yang bertanggung jawab menutup [connection].
final class ConnectDone extends ConnectState {
  const ConnectDone(this.connection);

  final SshConnection connection;
}

/// Mesin keadaan sambungan satu host: baca rahasia dari vault (satu prompt), sambung, putuskan host key lewat
/// pengguna, dan petakan semua kegagalan ke keadaan yang bisa ditampilkan. Tanpa UI sehingga bisa dites.
class ConnectFlow extends ChangeNotifier {
  ConnectFlow({
    required this.profile,
    required this.vault,
    required this.hosts,
    required this.connect,
    required this.unlockReason,
  });

  final HostProfile profile;
  final CredentialVault vault;
  final HostRepository hosts;
  final ConnectFunction connect;

  /// Teks alasan untuk prompt autentikasi perangkat (sudah dilokalkan oleh UI).
  final String unlockReason;

  ConnectState _state = const ConnectPreparing();
  Completer<HostKeyChoice>? _pendingHostKey;
  bool _cancelled = false;
  bool _disposed = false;

  ConnectState get state => _state;

  void _set(ConnectState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  /// Memulai (atau mengulang) alur. Aman dipanggil lagi dari keadaan gagal.
  Future<void> start() async {
    _cancelled = false;
    if (profile.authMethod == AuthMethod.agent) {
      _set(const ConnectFailed(SshUnknownFailure('Profil agen SSH tidak bisa disambung dari HP')));
      return;
    }
    _set(const ConnectPreparing());
    final SshCredentials credentials;
    try {
      final creds = await _readCredentials();
      if (creds == null) {
        _set(ConnectNeedsSecret(method: profile.authMethod));
        return;
      }
      credentials = creds;
    } on VaultAuthException catch (e) {
      _set(ConnectAuthDenied(cancelled: e.cancelled));
      return;
    } on VaultStorageException {
      _set(ConnectNeedsSecret(method: profile.authMethod));
      return;
    }
    await _connect(credentials);
  }

  Future<SshCredentials?> _readCredentials() async {
    if (profile.authMethod == AuthMethod.password) {
      final got = await vault.getMany(profile.id, {SecretType.loginPassword}, reason: unlockReason);
      final pw = got[SecretType.loginPassword];
      return pw == null ? null : PasswordCredentials(pw);
    }
    final got = await vault.getMany(profile.id, {
      SecretType.privateKeyPem,
      SecretType.keyPassphrase,
    }, reason: unlockReason);
    final pem = got[SecretType.privateKeyPem];
    return pem == null ? null : KeyCredentials(pem, passphrase: got[SecretType.keyPassphrase]);
  }

  Future<void> _connect(SshCredentials credentials) async {
    _set(const ConnectConnecting());
    try {
      final connection = await connect(profile: profile, credentials: credentials, decideHostKey: _decide);
      if (_cancelled || _disposed) {
        connection.close();
        return;
      }
      try {
        await hosts.markUsed(profile.id);
      } on Object {
        // Catatan "terakhir dipakai" tidak boleh menggagalkan sambungan.
      }
      _set(ConnectDone(connection));
    } on SshKeyUnusable catch (e) {
      _set(ConnectNeedsSecret(method: profile.authMethod, wrongPassphrase: e.wrongPassphrase));
    } on SshFailure catch (e) {
      if (!_cancelled) _set(ConnectFailed(e));
    } on Object catch (e) {
      if (!_cancelled) _set(ConnectFailed(SshUnknownFailure('Gagal menyambung', e)));
    }
  }

  Future<HostKeyChoice> _decide(HostKeyChallenge challenge) {
    if (_cancelled) return Future.value(HostKeyChoice.reject);
    final completer = Completer<HostKeyChoice>();
    _pendingHostKey = completer;
    _set(ConnectNeedsHostKey(challenge));
    return completer.future;
  }

  /// Jawaban pengguna untuk [ConnectNeedsHostKey]. Setelah itu keadaan kembali ke [ConnectConnecting].
  void answerHostKey(HostKeyChoice choice) {
    final c = _pendingHostKey;
    if (c == null || c.isCompleted) return;
    _pendingHostKey = null;
    if (choice != HostKeyChoice.reject) _set(const ConnectConnecting());
    c.complete(choice);
  }

  /// Menyimpan rahasia yang dimasukkan ulang lalu mengulang sambungan. Rahasia hanya masuk ke vault.
  Future<void> submitSecret({String? password, String? privateKeyPem, String? passphrase}) async {
    try {
      if (profile.authMethod == AuthMethod.password) {
        if (password == null || password.isEmpty) return;
        await vault.put(profile.id, SecretType.loginPassword, password);
      } else {
        if (privateKeyPem != null) {
          await vault.put(profile.id, SecretType.privateKeyPem, privateKeyPem);
          if (passphrase == null || passphrase.isEmpty) {
            await vault.remove(profile.id, SecretType.keyPassphrase);
          }
        }
        if (passphrase != null && passphrase.isNotEmpty) {
          await vault.put(profile.id, SecretType.keyPassphrase, passphrase);
        }
      }
    } on Object {
      _set(const ConnectFailed(SshUnknownFailure('Rahasia tidak bisa disimpan')));
      return;
    }
    await start();
  }

  /// Membatalkan: menolak keputusan host key yang menunggu, dan menutup sambungan yang selesai sesudahnya.
  void cancel() {
    _cancelled = true;
    final c = _pendingHostKey;
    if (c != null && !c.isCompleted) c.complete(HostKeyChoice.reject);
    _pendingHostKey = null;
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    super.dispose();
  }
}
