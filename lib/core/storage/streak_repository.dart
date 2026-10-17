import '../streak/streak_record.dart';
import 'load_result.dart';

/// Penyimpanan streak api (`streak.json`). Tanpa rahasia. [save] menulis ke disk sebelum [record] berubah; bila
/// penulisan gagal, melempar `StorageException` dan [record] tidak berubah.
abstract interface class StreakRepository {
  /// Keadaan terakhir di memori; kosong sebelum [load].
  StreakRecord get record;

  Future<LoadResult> load();

  Future<void> save(StreakRecord record);
}

/// Salinan di memori untuk tes dan nilai bawaan provider; tidak menyentuh disk.
class MemoryStreakRepository implements StreakRepository {
  MemoryStreakRepository([StreakRecord? record]) : _record = record ?? StreakRecord();

  StreakRecord _record;

  /// Jumlah penyimpanan (untuk tes).
  int saves = 0;

  @override
  StreakRecord get record => _record;

  @override
  Future<LoadResult> load() async => const LoadResult();

  @override
  Future<void> save(StreakRecord record) async {
    _record = record;
    saves++;
  }
}
