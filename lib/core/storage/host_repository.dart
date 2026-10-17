import '../models/host_profile.dart';
import '../models/profile_snapshot.dart';
import 'load_result.dart';

/// Penyimpanan daftar host (`profiles.json`). Tanpa rahasia: password dan kunci ada di `CredentialVault`.
///
/// Semua mutasi ditulis ke disk sebelum [snapshot] berubah dan sebelum [changes] mengumumkannya.
/// Bila penulisan gagal, mutasi melempar `StorageException` dan [snapshot] tidak berubah.
abstract interface class HostRepository {
  /// Keadaan terakhir di memori. Kosong sebelum [load] dipanggil.
  ProfileSnapshot get snapshot;

  /// Mengumumkan snapshot baru setiap kali ada perubahan.
  Stream<ProfileSnapshot> get changes;

  Future<LoadResult> load();

  /// Menambah profil baru atau mengganti profil dengan id yang sama.
  Future<ProfileSnapshot> save(HostProfile profile);

  /// Menghapus baris profil saja. Urutan penghapusan lengkap (rahasia, baris, sidik jari) ada di pemanggil.
  Future<ProfileSnapshot> delete(String id);

  Future<ProfileSnapshot> setFavorite(String id, {required bool favorite});

  /// Mencatat profil baru dipakai (maksimal [ProfileSnapshot.recentLimit]).
  Future<ProfileSnapshot> markUsed(String id);

  Future<ProfileSnapshot> clearRecent();

  /// Mengganti snapshot dengan hasil [change] yang dihitung dari keadaan terkini di dalam kunci tulis
  /// (dipakai impor: penggabungan tidak boleh memakai salinan yang sudah usang).
  Future<ProfileSnapshot> update(ProfileSnapshot Function(ProfileSnapshot current) change);

  Future<ProfileSnapshot> addGroup(String group);

  /// Menghapus grup dan subgrup kosong. Melempar [StateError] bila masih ada profil di dalamnya.
  Future<ProfileSnapshot> deleteGroup(String group);

  /// Mengganti nama atau memindahkan grup beserta subgrup dan profilnya.
  Future<ProfileSnapshot> renameGroup(String from, String to);
}
