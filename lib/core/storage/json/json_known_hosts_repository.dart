import 'dart:convert';
import 'dart:io';

import '../../io/async_lock.dart';
import '../../io/atomic_file.dart';
import '../../io/json_file.dart';
import '../../models/json_fields.dart';
import '../../models/known_host.dart';
import '../known_hosts_repository.dart';
import '../load_result.dart';

/// [KnownHostsRepository] di atas `known_hosts.json`: `{"version": 1, "hosts": [{host, port, type, fingerprint, addedAt}]}`.
///
/// Catatan keamanan: bila berkas rusak dan disisihkan, semua host kembali "baru" dan pin hilang sampai
/// pengguna memercayainya lagi. UI wajib menampilkan [LoadResult.hadCorruptFile].
class JsonKnownHostsRepository implements KnownHostsRepository {
  JsonKnownHostsRepository(this._file, {this._writer = _defaultWriter});

  static const currentVersion = 1;

  final File _file;
  final AtomicWriter _writer;
  final _lock = AsyncLock();
  List<KnownHost> _entries = const [];

  static Future<void> _defaultWriter(File f, List<int> b) => writeAtomic(f, b);

  @override
  Future<LoadResult> load() => _lock.run(() async {
    final loaded = await loadJsonOrQuarantine<List<KnownHost>>(
      _file,
      parse: (json) => List.unmodifiable([
        for (final e in optList(json, 'hosts'))
          if (e is Map<String, Object?>)
            KnownHost.fromJson(e)
          else
            throw const FormatException('Entri bukan objek'),
      ]),
      empty: const [],
    );
    _entries = loaded.value;
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  });

  @override
  List<KnownHost> get all => _entries;

  @override
  List<KnownHost> entriesFor(String host, int port) {
    final id = KnownHost.idFor(host, port);
    return [
      for (final e in _entries)
        if (e.id == id) e,
    ];
  }

  @override
  Future<void> add(KnownHost entry) => _lock.run(() async {
    for (final e in _entries) {
      if (e.id != entry.id || e.type != entry.type) continue;
      if (e.fingerprint == entry.fingerprint) return;
      throw StateError(
        'Sudah ada sidik jari ${entry.type} berbeda untuk ${entry.id}; gunakan replace',
      );
    }
    await _commit([..._entries, entry]);
  });

  @override
  Future<void> replace(KnownHost entry) => _lock.run(() async {
    await _commit([
      for (final e in _entries)
        if (!(e.id == entry.id && e.type == entry.type)) e,
      entry,
    ]);
  });

  @override
  Future<int> removeFor(String host, int port) => _lock.run(() async {
    final id = KnownHost.idFor(host, port);
    final kept = [
      for (final e in _entries)
        if (e.id != id) e,
    ];
    final removed = _entries.length - kept.length;
    if (removed > 0) await _commit(kept);
    return removed;
  });

  Future<void> _commit(List<KnownHost> next) async {
    const encoder = JsonEncoder.withIndent('  ');
    final json = {
      'version': currentVersion,
      'hosts': [for (final e in next) e.toJson()],
    };
    await _writer(_file, utf8.encode(encoder.convert(json)));
    _entries = List.unmodifiable(next);
  }
}
