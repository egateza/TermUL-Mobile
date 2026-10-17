import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../io/async_lock.dart';
import '../../io/atomic_file.dart';
import '../../io/json_file.dart';
import '../../models/snippet.dart';
import '../../models/snippet_library.dart';
import '../load_result.dart';
import '../snippet_repository.dart';

/// [SnippetRepository] di atas satu berkas JSON, ditulis atomik: `{"version": 2, "categories": [...], "snippets": [...]}`.
/// Berkas versi 1 (tanpa `categories`) tetap terbaca dan ditulis ulang sebagai versi 2 pada mutasi pertama.
class JsonSnippetRepository implements SnippetRepository {
  JsonSnippetRepository(this._file, {this._writer = _defaultWriter});

  final File _file;
  final AtomicWriter _writer;
  final _lock = AsyncLock();
  final _controller = StreamController<SnippetLibrary>.broadcast();
  SnippetLibrary _library = SnippetLibrary();

  static Future<void> _defaultWriter(File f, List<int> b) => writeAtomic(f, b);

  @override
  SnippetLibrary get library => _library;

  @override
  Stream<SnippetLibrary> get changes => _controller.stream;

  @override
  Future<LoadResult> load() => _lock.run(() async {
    final loaded = await loadJsonOrQuarantine<SnippetLibrary>(
      _file,
      parse: SnippetLibrary.fromJson,
      empty: SnippetLibrary(),
    );
    _library = loaded.value;
    _controller.add(_library);
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  });

  @override
  Future<void> save(Snippet snippet) => _mutate((lib) => lib.withSnippet(snippet));

  @override
  Future<void> delete(String id) => _mutate((lib) => lib.hasSnippet(id) ? lib.withoutSnippet(id) : lib);

  @override
  Future<void> clearHost(String hostId) =>
      _mutate((lib) => lib.hasSnippetForHost(hostId) ? lib.withoutHost(hostId) : lib);

  @override
  Future<void> saveCategory(SnippetCategory category) => _mutate((lib) => lib.withCategory(category));

  @override
  Future<void> deleteCategory(String id) => _mutate((lib) => lib.hasCategory(id) ? lib.withoutCategory(id) : lib);

  @override
  Future<void> moveSnippet(String id, int newIndex) => _mutate((lib) => lib.withSnippetMoved(id, newIndex));

  @override
  Future<void> moveCategory(String id, int newIndex) => _mutate((lib) => lib.withCategoryMoved(id, newIndex));

  Future<void> _mutate(SnippetLibrary Function(SnippetLibrary) change) => _lock.run(() async {
    final updated = change(_library);
    if (identical(updated, _library)) return;
    const encoder = JsonEncoder.withIndent('  ');
    await _writer(_file, utf8.encode(encoder.convert(updated.toJson())));
    _library = updated;
    _controller.add(updated);
  });
}
