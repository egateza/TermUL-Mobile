import 'dart:async';

import '../models/snippet.dart';
import '../models/snippet_library.dart';
import 'load_result.dart';

/// Penyimpanan snippet dan kategorinya (`snippets.json`). Tanpa rahasia. Mutasi ditulis ke disk sebelum [library]
/// berubah; bila penulisan gagal, mutasi melempar `StorageException` dan [library] tidak berubah.
abstract interface class SnippetRepository {
  /// Keadaan terakhir di memori. Berisi kategori awal dan tanpa snippet sebelum [load] dipanggil.
  SnippetLibrary get library;

  Stream<SnippetLibrary> get changes;

  Future<LoadResult> load();

  /// Menambah snippet baru (di depan daftar) atau mengganti snippet dengan id yang sama (posisi tetap).
  Future<void> save(Snippet snippet);

  Future<void> delete(String id);

  /// Memindahkan snippet ke [newIndex] (indeks akhir setelah dicabut dari daftar). Urutan daftar ditentukan pemilik.
  Future<void> moveSnippet(String id, int newIndex);

  /// Melepas keterikatan ke host yang dihapus: snippet-nya jatuh ke "semua host".
  Future<void> clearHost(String hostId);

  /// Menambah kategori baru (di akhir) atau mengganti kategori dengan id yang sama (mis. mengubah nama).
  Future<void> saveCategory(SnippetCategory category);

  /// Menghapus kategori; snippet di dalamnya menjadi tanpa kategori dan tidak ikut terhapus.
  Future<void> deleteCategory(String id);

  /// Memindahkan kategori ke [newIndex] (indeks akhir setelah dicabut dari daftar). Urutan inilah yang dipakai chip
  /// filter dan pilihan kategori di mana-mana.
  Future<void> moveCategory(String id, int newIndex);
}

/// Salinan di memori untuk tes dan nilai bawaan provider; tidak menyentuh disk.
class MemorySnippetRepository implements SnippetRepository {
  MemorySnippetRepository([
    List<Snippet> snippets = const [],
    List<SnippetCategory> categories = SnippetCategory.defaults,
  ]) : _library = SnippetLibrary(categories: categories, snippets: snippets);

  final _controller = StreamController<SnippetLibrary>.broadcast();
  SnippetLibrary _library;

  @override
  SnippetLibrary get library => _library;

  @override
  Stream<SnippetLibrary> get changes => _controller.stream;

  @override
  Future<LoadResult> load() async => const LoadResult();

  @override
  Future<void> save(Snippet snippet) async => _emit(_library.withSnippet(snippet));

  @override
  Future<void> delete(String id) async => _emit(_library.withoutSnippet(id));

  @override
  Future<void> moveSnippet(String id, int newIndex) async => _emit(_library.withSnippetMoved(id, newIndex));

  @override
  Future<void> clearHost(String hostId) async => _emit(_library.withoutHost(hostId));

  @override
  Future<void> saveCategory(SnippetCategory category) async => _emit(_library.withCategory(category));

  @override
  Future<void> deleteCategory(String id) async => _emit(_library.withoutCategory(id));

  @override
  Future<void> moveCategory(String id, int newIndex) async => _emit(_library.withCategoryMoved(id, newIndex));

  void _emit(SnippetLibrary next) {
    _library = next;
    _controller.add(next);
  }
}
