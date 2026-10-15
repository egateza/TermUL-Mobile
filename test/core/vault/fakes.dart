import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/secret_store.dart';
import 'package:termul_mobile/core/vault/vault_exceptions.dart';
import 'package:termul_mobile/core/vault/vault_index.dart';
import 'package:termul_mobile/core/storage/load_result.dart';

/// Autentikasi palsu: mencatat jumlah prompt dan hasilnya bisa diatur.
class FakeDeviceAuth implements DeviceAuth {
  FakeDeviceAuth({this.currentLevel = AuthLevel.biometric, this.result = true});

  AuthLevel currentLevel;
  bool result;
  Object? throwOnAuthenticate;
  final reasons = <String>[];

  @override
  Future<AuthLevel> level() async => currentLevel;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    if (throwOnAuthenticate != null) throw throwOnAuthenticate!;
    return result;
  }
}

/// Penyimpanan rahasia di memori dengan kegagalan yang bisa disuntik.
class MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  bool failWrites = false;
  bool failDeletes = false;
  bool failReads = false;
  int reads = 0;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw const VaultStorageException('tulis gagal');
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    reads++;
    if (failReads) throw const VaultStorageException('baca gagal');
    return values[key];
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw const VaultStorageException('hapus gagal');
    values.remove(key);
  }

  @override
  Future<bool> contains(String key) async => values.containsKey(key);
}

/// Indeks di memori; mencatat urutan operasi bersama penyimpanan untuk memeriksa urutan tulis dan hapus.
class MemoryVaultIndex implements VaultIndex {
  MemoryVaultIndex([this.log]);

  final List<String>? log;
  final _names = <String>{};

  @override
  Set<String> get names => Set.unmodifiable(_names);

  @override
  Future<LoadResult> load() async => const LoadResult();

  @override
  Future<void> add(String name) async {
    log?.add('index+');
    _names.add(name);
  }

  @override
  Future<void> remove(String name) async {
    log?.add('index-');
    _names.remove(name);
  }
}
