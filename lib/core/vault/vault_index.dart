import 'dart:convert';
import 'dart:io';

import '../io/async_lock.dart';
import '../io/atomic_file.dart';
import '../io/json_file.dart';
import '../models/json_fields.dart';
import '../storage/load_result.dart';

/// Catatan nama kunci (ber-hash) yang pernah ditulis ke Keystore, di `vault_index.json`. Tidak berisi rahasia
/// maupun id profil. Dipakai untuk membersihkan rahasia yatim tanpa mendekripsi seluruh isi Keystore.
///
/// Urutan: nama ditulis **sebelum** rahasia disimpan dan dihapus **setelah** rahasia dihapus, sehingga
/// kegagalan di tengah hanya meninggalkan nama tanpa rahasia (tidak berbahaya), tidak pernah sebaliknya.
abstract interface class VaultIndex {
  Future<LoadResult> load();
  Set<String> get names;
  Future<void> add(String name);
  Future<void> remove(String name);
}

class JsonVaultIndex implements VaultIndex {
  JsonVaultIndex(this._file, {this._writer = _defaultWriter});

  static const currentVersion = 1;

  final File _file;
  final AtomicWriter _writer;
  final _lock = AsyncLock();
  Set<String> _names = const {};

  static Future<void> _defaultWriter(File f, List<int> b) => writeAtomic(f, b);

  @override
  Set<String> get names => _names;

  @override
  Future<LoadResult> load() => _lock.run(() async {
    final loaded = await loadJsonOrQuarantine<Set<String>>(
      _file,
      parse: (json) => Set.unmodifiable(stringList(json, 'keys')),
      empty: const {},
    );
    _names = loaded.value;
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  });

  @override
  Future<void> add(String name) => _lock.run(() async {
    if (_names.contains(name)) return;
    await _commit({..._names, name});
  });

  @override
  Future<void> remove(String name) => _lock.run(() async {
    if (!_names.contains(name)) return;
    await _commit(_names.where((n) => n != name).toSet());
  });

  Future<void> _commit(Set<String> next) async {
    const encoder = JsonEncoder.withIndent('  ');
    final sorted = next.toList()..sort();
    await _writer(_file, utf8.encode(encoder.convert({'version': currentVersion, 'keys': sorted})));
    _names = Set.unmodifiable(next);
  }
}
