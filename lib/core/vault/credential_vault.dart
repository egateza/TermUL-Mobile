import 'device_auth.dart';
import 'secret_type.dart';

export 'device_auth.dart' show AuthLevel;

/// Penyimpanan rahasia per profil (password, passphrase, isi kunci privat), menyerupai `CredentialVault`
/// desktop tetapi tanpa master password: enkripsi oleh Android Keystore, gerbang baca oleh [AuthLevel].
///
/// Aturan: rahasia tidak pernah ditulis ke berkas, log, atau konsol. Dart tidak bisa menimpa memori `String`
/// dengan nol seperti `char[]` di desktop, jadi jangan simpan rahasia di field berumur panjang.
abstract interface class CredentialVault {
  /// Tingkat penguncian HP saat ini; dibaca ulang setiap dipanggil.
  Future<AuthLevel> authLevel();

  /// Membaca satu rahasia. Menampilkan prompt sesuai [authLevel] (kecuali `none`). `null` bila tidak ada.
  /// Melempar `VaultAuthException` bila autentikasi gagal atau dibatalkan, dan `VaultStorageException` bila
  /// Keystore gagal (perlakukan seperti "rahasia tidak ditemukan").
  Future<String?> get(String profileId, SecretType type, {required String reason});

  /// Membaca beberapa rahasia dengan **satu** prompt. Hanya tipe yang ada yang masuk ke hasil.
  Future<Map<SecretType, String>> getMany(String profileId, Set<SecretType> types, {required String reason});

  /// Apakah rahasia ada. Tanpa prompt dan tanpa membaca nilainya.
  Future<bool> has(String profileId, SecretType type);

  /// Menyimpan atau mengganti rahasia. Tidak meminta autentikasi (yang dilindungi adalah pembacaan).
  Future<void> put(String profileId, SecretType type, String secret);

  Future<void> remove(String profileId, SecretType type);

  /// Menghapus semua jenis rahasia milik profil (dipakai saat host dihapus).
  Future<void> removeProfile(String profileId);

  /// Menghapus rahasia yatim: entri yang tercatat di indeks tetapi bukan milik profil di [liveProfileIds].
  /// **Jangan dipanggil bila `profiles.json` baru saja dikarantina**: semua rahasia akan tampak yatim.
  /// Mengembalikan jumlah yang dihapus.
  Future<int> sweepOrphans({required Set<String> liveProfileIds});
}
