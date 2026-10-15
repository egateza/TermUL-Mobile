import '../models/known_host.dart';
import 'load_result.dart';

/// Penyimpanan sidik jari host key yang dipercaya (`known_hosts.json`), permanen.
abstract interface class KnownHostsRepository {
  Future<LoadResult> load();

  /// Entri tersimpan untuk `host:port` (dari memori; panggil setelah [load]).
  List<KnownHost> entriesFor(String host, int port);

  List<KnownHost> get all;

  /// Menambah entri. Tidak berbuat apa-apa bila entri identik sudah ada. Melempar [StateError] bila sudah
  /// ada entri bertipe sama dengan sidik jari berbeda: itu kasus "host key berubah" dan harus lewat [replace]
  /// setelah konfirmasi pengguna, supaya penambahan biasa tidak diam-diam melemahkan pin.
  ///
  /// Selesai (berhasil ditulis ke disk) sebelum login boleh dilanjutkan.
  Future<void> add(KnownHost entry);

  /// Mengganti entri bertipe sama untuk `host:port` yang sama dengan [entry].
  Future<void> replace(KnownHost entry);

  /// Menghapus semua entri `host:port`. Mengembalikan jumlah yang dihapus.
  Future<int> removeFor(String host, int port);
}
