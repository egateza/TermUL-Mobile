import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_exceptions.dart';

/// Penyimpanan nilai rahasia berkunci nama. Implementasi nyata: Android Keystore lewat `flutter_secure_storage`.
abstract interface class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<bool> contains(String key);
}

/// [SecretStore] di atas `flutter_secure_storage` (Keystore: RSA-OAEP membungkus kunci AES-GCM). Nilai
/// terenkripsi; nama kunci ditulis apa adanya di `shared_prefs`, sebab itu nama kunci wajib berupa hash.
class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<T> _guard<T>(String what, Future<T> Function() op) async {
    try {
      return await op();
    } on Object catch (e) {
      throw VaultStorageException('Keystore gagal $what', e);
    }
  }

  @override
  Future<void> write(String key, String value) => _guard('menulis', () => _storage.write(key: key, value: value));

  @override
  Future<String?> read(String key) => _guard('membaca', () => _storage.read(key: key));

  @override
  Future<void> delete(String key) => _guard('menghapus', () => _storage.delete(key: key));

  @override
  Future<bool> contains(String key) => _guard('memeriksa', () => _storage.containsKey(key: key));
}
