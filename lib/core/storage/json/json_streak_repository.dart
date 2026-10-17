import 'dart:convert';
import 'dart:io';

import '../../io/async_lock.dart';
import '../../io/atomic_file.dart';
import '../../io/json_file.dart';
import '../../streak/streak_record.dart';
import '../load_result.dart';
import '../streak_repository.dart';

/// [StreakRepository] di atas `streak.json`, ditulis atomik. Berkas rusak disisihkan sebagai
/// `streak.json.corrupt-<epoch ms>` lalu mulai dari streak kosong (pola `StreakStore` desktop).
class JsonStreakRepository implements StreakRepository {
  JsonStreakRepository(this._file, {this._writer = _defaultWriter});

  final File _file;
  final AtomicWriter _writer;
  final _lock = AsyncLock();
  StreakRecord _record = StreakRecord();

  static Future<void> _defaultWriter(File f, List<int> b) => writeAtomic(f, b);

  @override
  StreakRecord get record => _record;

  @override
  Future<LoadResult> load() => _lock.run(() async {
    final loaded = await loadJsonOrQuarantine<StreakRecord>(_file, parse: StreakRecord.fromJson, empty: StreakRecord());
    _record = loaded.value;
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  });

  @override
  Future<void> save(StreakRecord record) => _lock.run(() async {
    const encoder = JsonEncoder.withIndent('  ');
    await _writer(_file, utf8.encode(encoder.convert(record.toJson())));
    _record = record;
  });
}
