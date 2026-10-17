import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/features/snippets/snippet_list_model.dart';

void main() {
  const all = [
    Snippet(id: '1', title: 'Cek Nginx', command: 'sudo nginx -t', categoryId: 'nginx', favorite: true),
    Snippet(id: '2', title: 'Disk', command: 'df -h /'),
    Snippet(id: '3', title: 'Log container', command: 'docker logs -f web', categoryId: 'docker'),
  ];
  List<String> ids(List<Snippet> l) => [for (final s in l) s.id];

  test('tanpa kriteria: semua, urutan asli', () => expect(ids(filterSnippets(all)), ['1', '2', '3']));

  test('cari di judul atau perintah tanpa membedakan huruf', () {
    expect(ids(filterSnippets(all, query: 'NGINX')), ['1']);
    expect(ids(filterSnippets(all, query: ' logs ')), ['3']);
    expect(ids(filterSnippets(all, query: 'df')), ['2']);
  });

  test('favorit dan kategori, bisa digabung dengan pencarian', () {
    expect(ids(filterSnippets(all, favoritesOnly: true)), ['1']);
    expect(ids(filterSnippets(all, categoryId: 'docker')), ['3']);
    expect(ids(filterSnippets(all, categoryId: 'docker', query: 'nginx')), isEmpty);
  });
}
