/// Galat vault. Pesan tidak pernah memuat rahasia.
sealed class VaultException implements Exception {
  const VaultException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Gerbang autentikasi (biometrik, PIN, pola, sandi) gagal atau dibatalkan; rahasia tidak dibaca.
final class VaultAuthException extends VaultException {
  const VaultAuthException(String message, {this.cancelled = true, Object? cause}) : super(message, cause);

  /// true bila pengguna membatalkan atau gagal; false bila perangkat tidak bisa melakukan autentikasi.
  final bool cancelled;
}

/// Keystore tidak bisa dibaca atau ditulis (mis. kunci tidak berlaku lagi). Pemanggil memperlakukannya seperti
/// "rahasia tidak ditemukan": minta pengguna memasukkan ulang.
final class VaultStorageException extends VaultException {
  const VaultStorageException(super.message, [super.cause]);
}
