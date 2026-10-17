import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'credential_vault.dart';
import 'device_auth.dart';
import 'secret_store.dart';
import 'secret_type.dart';
import 'vault_exceptions.dart';
import 'vault_index.dart';
import 'vault_lock.dart';

/// [CredentialVault] di atas Android Keystore ([SecretStore]) dengan gerbang [DeviceAuth].
///
/// - Nama kunci: `termul.secret.<32 hex pertama sha256("<uuid>|<TIPE>")>`. Nama ditulis apa adanya di
///   `shared_prefs`, jadi tidak boleh memuat id profil, host, atau user.
/// - Urutan tulis: nama masuk indeks, lalu rahasia disimpan. Urutan hapus: rahasia dihapus, lalu nama keluar
///   dari indeks. Kegagalan di tengah hanya meninggalkan nama tanpa rahasia.
class KeystoreCredentialVault implements CredentialVault {
  KeystoreCredentialVault({required this._auth, required this._store, required this._index, this._lock});

  static const keyPrefix = 'termul.secret.';

  final DeviceAuth _auth;
  final SecretStore _store;
  final VaultIndex _index;

  /// Bila terbuka (sementara atau selalu), pembacaan tidak meminta autentikasi.
  final VaultLock? _lock;

  /// Nama kunci penyimpanan untuk pasangan (profil, tipe). Stabil dan tidak mengungkap id profil.
  static String keyName(String profileId, SecretType type) {
    final digest = sha256.convert(utf8.encode('${profileId.toLowerCase()}|${type.wire}')).toString();
    return '$keyPrefix${digest.substring(0, 32)}';
  }

  @override
  Future<AuthLevel> authLevel() => _auth.level();

  Future<void> _gate(String reason) async {
    if (await _auth.level() == AuthLevel.none) return;
    if (await _lock?.isOpen() ?? false) return;
    final bool ok;
    try {
      ok = await _auth.authenticate(reason);
    } on Object catch (e) {
      throw VaultAuthException('Autentikasi perangkat tidak bisa dipakai', cancelled: false, cause: e);
    }
    if (!ok) {
      throw const VaultAuthException('Autentikasi dibatalkan atau gagal');
    }
  }

  @override
  Future<String?> get(String profileId, SecretType type, {required String reason}) async {
    await _gate(reason);
    return _store.read(keyName(profileId, type));
  }

  @override
  Future<Map<SecretType, String>> getMany(String profileId, Set<SecretType> types, {required String reason}) async {
    await _gate(reason);
    final result = <SecretType, String>{};
    for (final t in types) {
      final v = await _store.read(keyName(profileId, t));
      if (v != null) result[t] = v;
    }
    return result;
  }

  @override
  Future<bool> has(String profileId, SecretType type) => _store.contains(keyName(profileId, type));

  @override
  Future<void> put(String profileId, SecretType type, String secret) async {
    final name = keyName(profileId, type);
    await _index.add(name);
    await _store.write(name, secret);
  }

  @override
  Future<void> remove(String profileId, SecretType type) => _removeName(keyName(profileId, type));

  Future<void> _removeName(String name) async {
    await _store.delete(name);
    await _index.remove(name);
  }

  @override
  Future<void> removeProfile(String profileId) async {
    for (final t in SecretType.values) {
      await remove(profileId, t);
    }
  }

  @override
  Future<int> sweepOrphans({required Set<String> liveProfileIds}) async {
    final expected = {
      for (final id in liveProfileIds)
        for (final t in SecretType.values) keyName(id, t),
    };
    var removed = 0;
    for (final name in _index.names.toList()) {
      if (expected.contains(name)) continue;
      await _removeName(name);
      removed++;
    }
    return removed;
  }
}
