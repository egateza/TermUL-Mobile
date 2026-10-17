import 'dart:convert';
import 'dart:io';

import '../../io/async_lock.dart';
import '../../io/atomic_file.dart';
import '../../io/json_file.dart';
import '../../models/json_fields.dart';
import '../load_result.dart';
import '../ui_state_repository.dart';

/// `ui_state.json`: `{"version": 1, "collapsedGroups": ["Produksi", "Produksi/DB"]}`. Properti yang tidak dikenal
/// diabaikan; berkas rusak disisihkan ke `ui_state.json.corrupt-<waktu>` dan semua grup terbuka (tanpa banner).
/// Penulisan diantrekan supaya ketukan beruntun tersimpan sesuai urutan.
class JsonUiStateRepository implements UiStateRepository {
  JsonUiStateRepository(this._file, {this._writer = writeAtomic});

  static const currentVersion = 1;

  final File _file;
  final AtomicWriter _writer;
  final _lock = AsyncLock();

  Set<String> _collapsed = const {};

  @override
  Set<String> get collapsedGroups => _collapsed;

  Future<LoadResult> load() async {
    final loaded = await loadJsonOrQuarantine<Set<String>>(
      _file,
      parse: (json) => Set.unmodifiable(stringList(json, 'collapsedGroups')),
      empty: const {},
    );
    _collapsed = loaded.value;
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  }

  @override
  Future<void> saveCollapsedGroups(Set<String> paths) {
    final next = Set<String>.unmodifiable(paths);
    return _lock.run(() async {
      final json = {'version': currentVersion, 'collapsedGroups': next.toList()..sort()};
      await _writer(_file, utf8.encode('${const JsonEncoder.withIndent('  ').convert(json)}\n'));
      _collapsed = next;
    });
  }
}
