import 'dart:convert';
import 'dart:io';

import '../../io/async_lock.dart';
import '../../io/atomic_file.dart';
import '../../io/json_file.dart';
import '../../models/json_fields.dart';
import '../load_result.dart';
import '../ui_state_repository.dart';

typedef _UiState = ({Set<String> collapsed, int? seen, PendingNotes? pending});

/// `ui_state.json`: `{"version": 1, "collapsedGroups": ["Produksi", "Produksi/DB"], "seenVersionCode": 111,
/// "pendingNotes": {"versionCode": 120, "version": "0.1.120", "notes": "..."}}`. Properti yang tidak dikenal diabaikan;
/// berkas rusak disisihkan ke `ui_state.json.corrupt-<waktu>` dan semua grup terbuka (tanpa banner). Penulisan
/// diantrekan supaya ketukan beruntun tersimpan sesuai urutan.
class JsonUiStateRepository implements UiStateRepository {
  JsonUiStateRepository(this._file, {this._writer = writeAtomic});

  static const currentVersion = 1;

  final File _file;
  final AtomicWriter _writer;
  final _lock = AsyncLock();

  _UiState _state = (collapsed: const {}, seen: null, pending: null);

  @override
  Set<String> get collapsedGroups => _state.collapsed;

  @override
  int? get seenVersionCode => _state.seen;

  @override
  PendingNotes? get pendingNotes => _state.pending;

  Future<LoadResult> load() async {
    final loaded = await loadJsonOrQuarantine<_UiState>(
      _file,
      parse: (json) {
        final p = optObject(json, 'pendingNotes');
        final code = p == null ? null : optInt(p, 'versionCode');
        final version = p == null ? null : optString(p, 'version');
        final notes = p == null ? null : optString(p, 'notes');
        return (
          collapsed: Set.unmodifiable(stringList(json, 'collapsedGroups')),
          seen: optInt(json, 'seenVersionCode'),
          pending: code == null || version == null || notes == null
              ? null
              : PendingNotes(versionCode: code, version: version, notes: notes),
        );
      },
      empty: (collapsed: const {}, seen: null, pending: null),
    );
    _state = loaded.value;
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  }

  @override
  Future<void> saveCollapsedGroups(Set<String> paths) {
    final next = Set<String>.unmodifiable(paths);
    return _lock.run(() => _write((collapsed: next, seen: _state.seen, pending: _state.pending)));
  }

  @override
  Future<void> saveUpdateState({required int? seenVersionCode, required PendingNotes? pendingNotes}) =>
      _lock.run(() => _write((collapsed: _state.collapsed, seen: seenVersionCode, pending: pendingNotes)));

  Future<void> _write(_UiState next) async {
    final pending = next.pending;
    final json = {
      'version': currentVersion,
      'collapsedGroups': next.collapsed.toList()..sort(),
      if (next.seen != null) 'seenVersionCode': next.seen,
      if (pending != null)
        'pendingNotes': {'versionCode': pending.versionCode, 'version': pending.version, 'notes': pending.notes},
    };
    await _writer(_file, utf8.encode('${const JsonEncoder.withIndent('  ').convert(json)}\n'));
    _state = next;
  }
}
