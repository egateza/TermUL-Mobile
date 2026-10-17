import '../../core/models/snippet.dart';

/// Menyaring [all] menurut [query] (judul atau perintah, tanpa membedakan huruf), [favoritesOnly], dan [categoryId].
/// Urutan asli dipertahankan (terbaru di depan).
List<Snippet> filterSnippets(List<Snippet> all, {String query = '', bool favoritesOnly = false, String? categoryId}) {
  final q = query.trim().toLowerCase();
  return [
    for (final s in all)
      if ((!favoritesOnly || s.favorite) &&
          (categoryId == null || s.categoryId == categoryId) &&
          (q.isEmpty || '${s.title} ${s.command}'.toLowerCase().contains(q)))
        s,
  ];
}
