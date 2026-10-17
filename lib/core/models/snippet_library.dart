import 'package:flutter/foundation.dart';

import 'json_fields.dart';
import 'snippet.dart';

/// Isi `snippets.json`: kategori dan snippet. Immutable; setiap perubahan menghasilkan salinan baru.
///
/// Aturan yang dijaga: id kategori dan id snippet unik (duplikat ditolak dengan [ArgumentError], jadi berkas dianggap
/// rusak), dan snippet yang menunjuk kategori yang tidak ada dilepas menjadi tanpa kategori.
@immutable
final class SnippetLibrary {
  factory SnippetLibrary({
    List<SnippetCategory> categories = SnippetCategory.defaults,
    List<Snippet> snippets = const [],
  }) {
    final categoryIds = <String>{};
    for (final c in categories) {
      if (!categoryIds.add(c.id)) throw ArgumentError('Terdapat id kategori duplikat');
    }
    final snippetIds = <String>{};
    for (final s in snippets) {
      if (!snippetIds.add(s.id)) throw ArgumentError('Terdapat id snippet duplikat');
    }
    return SnippetLibrary._(
      List.unmodifiable(categories),
      List.unmodifiable([
        for (final s in snippets)
          if (s.categoryId != null && !categoryIds.contains(s.categoryId)) s.copyWith(categoryId: null) else s,
      ]),
    );
  }

  const SnippetLibrary._(this.categories, this.snippets);

  /// Skema: `{"version": 2, "categories": [...], "snippets": [...]}`. Tanpa kunci `categories` (berkas versi 1)
  /// dipakai [SnippetCategory.defaults]; `categories` kosong tetap kosong (pengguna menghapus semuanya).
  factory SnippetLibrary.fromJson(Map<String, Object?> json) => SnippetLibrary(
    categories: json.containsKey('categories')
        ? [for (final c in optList(json, 'categories')) SnippetCategory.fromJson(_object(c, 'Kategori'))]
        : SnippetCategory.defaults,
    snippets: [for (final s in optList(json, 'snippets')) Snippet.fromJson(_object(s, 'Snippet'))],
  );

  static Map<String, Object?> _object(Object? v, String what) {
    if (v is Map<String, Object?>) return v;
    throw FormatException('$what bukan objek');
  }

  static const currentVersion = 2;

  final List<SnippetCategory> categories;

  /// Terbaru di depan.
  final List<Snippet> snippets;

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'categories': [for (final c in categories) c.toJson()],
    'snippets': [for (final s in snippets) s.toJson()],
  };

  SnippetCategory? categoryOf(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Jumlah snippet di kategori [id].
  int countIn(String id) => snippets.where((s) => s.categoryId == id).length;

  /// Nama [name] sudah dipakai kategori lain (tanpa membedakan huruf). [exceptId] = kategori yang sedang diubah.
  bool nameTaken(String name, {String? exceptId}) {
    final n = name.trim().toLowerCase();
    return categories.any((c) => c.id != exceptId && c.name.toLowerCase() == n);
  }

  /// Menambah snippet baru di depan, atau mengganti snippet dengan id yang sama di tempatnya.
  SnippetLibrary withSnippet(Snippet snippet) {
    final i = snippets.indexWhere((s) => s.id == snippet.id);
    final next = i < 0 ? [snippet, ...snippets] : ([...snippets]..[i] = snippet);
    return SnippetLibrary(categories: categories, snippets: next);
  }

  /// Memindahkan snippet [id] ke posisi [newIndex] (indeks akhir setelah snippet itu dicabut dari daftar, dibatasi
  /// ke rentang yang sah). Tidak berubah (objek yang sama) bila posisinya tetap atau [id] tidak ada.
  SnippetLibrary withSnippetMoved(String id, int newIndex) {
    final from = snippets.indexWhere((s) => s.id == id);
    if (from < 0) return this;
    final list = [...snippets];
    final moved = list.removeAt(from);
    final to = newIndex.clamp(0, list.length);
    if (to == from) return this;
    list.insert(to, moved);
    return SnippetLibrary(categories: categories, snippets: list);
  }

  SnippetLibrary withoutSnippet(String id) => SnippetLibrary(
    categories: categories,
    snippets: [
      for (final s in snippets)
        if (s.id != id) s,
    ],
  );

  /// Melepas keterikatan ke host yang dihapus: snippet-nya jatuh ke "semua host".
  SnippetLibrary withoutHost(String hostId) => SnippetLibrary(
    categories: categories,
    snippets: [
      for (final s in snippets)
        if (s.hostId == hostId) s.copyWith(hostId: null) else s,
    ],
  );

  /// Menambah kategori baru di akhir, atau mengganti kategori dengan id yang sama di tempatnya.
  SnippetLibrary withCategory(SnippetCategory category) {
    final i = categories.indexWhere((c) => c.id == category.id);
    final next = i < 0 ? [...categories, category] : ([...categories]..[i] = category);
    return SnippetLibrary(categories: next, snippets: snippets);
  }

  /// Memindahkan kategori [id] ke posisi [newIndex] (indeks akhir setelah kategori itu dicabut dari daftar, dibatasi
  /// ke rentang yang sah). Tidak berubah (objek yang sama) bila posisinya tetap atau [id] tidak ada.
  SnippetLibrary withCategoryMoved(String id, int newIndex) {
    final from = categories.indexWhere((c) => c.id == id);
    if (from < 0) return this;
    final list = [...categories];
    final moved = list.removeAt(from);
    final to = newIndex.clamp(0, list.length);
    if (to == from) return this;
    list.insert(to, moved);
    return SnippetLibrary(categories: list, snippets: snippets);
  }

  /// Menghapus kategori; snippet di dalamnya menjadi tanpa kategori (snippet tidak ikut terhapus).
  SnippetLibrary withoutCategory(String id) => SnippetLibrary(
    categories: [
      for (final c in categories)
        if (c.id != id) c,
    ],
    snippets: [
      for (final s in snippets)
        if (s.categoryId == id) s.copyWith(categoryId: null) else s,
    ],
  );

  bool hasSnippet(String id) => snippets.any((s) => s.id == id);

  bool hasCategory(String id) => categories.any((c) => c.id == id);

  bool hasSnippetForHost(String hostId) => snippets.any((s) => s.hostId == hostId);

  @override
  bool operator ==(Object other) =>
      other is SnippetLibrary && listEquals(other.categories, categories) && listEquals(other.snippets, snippets);

  @override
  int get hashCode => Object.hash(Object.hashAll(categories), Object.hashAll(snippets));
}
