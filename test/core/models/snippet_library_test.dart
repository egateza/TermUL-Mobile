import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/models/snippet_library.dart';

Snippet sn(String id, {String? categoryId, String? hostId}) =>
    Snippet(id: id, title: 'judul $id', command: 'ls $id', categoryId: categoryId, hostId: hostId);

void main() {
  group('SnippetCategory', () {
    test('JSON bolak-balik; nama dipangkas; tanpa id atau nama ditolak', () {
      const c = SnippetCategory(id: 'a', name: 'Jaringan');
      expect(SnippetCategory.fromJson(c.toJson()), c);
      expect(SnippetCategory.fromJson({'id': 'a', 'name': '  Jaringan '}).name, 'Jaringan');
      for (final bad in <Map<String, Object?>>[
        {'name': 'x'},
        {'id': 'a'},
        {'id': 'a', 'name': '  '},
        {'id': 1, 'name': 'x'},
      ]) {
        expect(() => SnippetCategory.fromJson(bad), throwsFormatException, reason: '$bad');
      }
    });

    test('create memberi id unik dan memangkas nama', () {
      final a = SnippetCategory.create(' Satu ');
      final b = SnippetCategory.create('Satu');
      expect(a.name, 'Satu');
      expect(a.id, isNot(b.id));
    });
  });

  group('SnippetLibrary', () {
    test('awal: empat kategori bawaan, tanpa snippet', () {
      final lib = SnippetLibrary();
      expect(lib.categories.map((c) => c.name), ['Sistem', 'Nginx', 'Docker', 'Database']);
      expect(lib.snippets, isEmpty);
    });

    test('berkas versi 1 (tanpa categories): kategori bawaan dipakai dan id kategori lama tetap menunjuk', () {
      final lib = SnippetLibrary.fromJson({
        'version': 1,
        'snippets': [
          {'id': 'a', 'title': 't', 'command': 'ls', 'category': 'nginx'},
        ],
      });
      expect(lib.snippets.single.categoryId, 'nginx');
      expect(lib.categoryOf('nginx')!.name, 'Nginx');
    });

    test('categories kosong tetap kosong (bukan diganti bawaan); snippet-nya tanpa kategori', () {
      final lib = SnippetLibrary.fromJson({
        'version': 2,
        'categories': <Object?>[],
        'snippets': [
          {'id': 'a', 'title': 't', 'command': 'ls', 'category': 'nginx'},
        ],
      });
      expect(lib.categories, isEmpty);
      expect(lib.snippets.single.categoryId, isNull);
    });

    test('toJson berversi 2 dan bolak-balik', () {
      final lib = SnippetLibrary(
        categories: const [SnippetCategory(id: 'x', name: 'X')],
        snippets: [sn('a', categoryId: 'x', hostId: 'h')],
      );
      expect(lib.toJson()['version'], 2);
      expect(SnippetLibrary.fromJson(lib.toJson()), lib);
    });

    test('id kategori atau snippet kembar ditolak', () {
      expect(
        () => SnippetLibrary(
          categories: const [
            SnippetCategory(id: 'x', name: 'A'),
            SnippetCategory(id: 'x', name: 'B'),
          ],
        ),
        throwsArgumentError,
      );
      expect(() => SnippetLibrary(snippets: [sn('a'), sn('a')]), throwsArgumentError);
    });

    test('nameTaken: tanpa membedakan huruf dan spasi tepi; pengecualian untuk kategori yang sedang diubah', () {
      final lib = SnippetLibrary();
      expect(lib.nameTaken(' docker '), isTrue);
      expect(lib.nameTaken('Kubernetes'), isFalse);
      expect(lib.nameTaken('DOCKER', exceptId: 'docker'), isFalse);
      expect(lib.nameTaken('docker', exceptId: 'nginx'), isTrue);
    });

    test('withCategory: baru di akhir, id sama mengganti di tempat (ganti nama)', () {
      var lib = SnippetLibrary();
      lib = lib.withCategory(const SnippetCategory(id: 'baru', name: 'Baru'));
      expect(lib.categories.last.name, 'Baru');
      lib = lib.withCategory(const SnippetCategory(id: 'nginx', name: 'Web'));
      expect(lib.categories.map((c) => c.name), ['Sistem', 'Web', 'Docker', 'Database', 'Baru']);
    });

    test('ganti nama kategori tidak melepas snippet dari kategorinya', () {
      var lib = SnippetLibrary(snippets: [sn('a', categoryId: 'nginx')]);
      lib = lib.withCategory(const SnippetCategory(id: 'nginx', name: 'Web'));
      expect(lib.snippets.single.categoryId, 'nginx');
      expect(lib.categoryOf('nginx')!.name, 'Web');
    });

    test('withoutCategory: snippet di dalamnya menjadi tanpa kategori dan tidak terhapus; yang lain utuh', () {
      var lib = SnippetLibrary(
        snippets: [
          sn('a', categoryId: 'nginx'),
          sn('b', categoryId: 'docker'),
          sn('c'),
        ],
      );
      expect(lib.countIn('nginx'), 1);
      lib = lib.withoutCategory('nginx');
      expect(lib.categories.map((c) => c.id), ['sistem', 'docker', 'database']);
      expect(lib.snippets.map((s) => s.id), ['a', 'b', 'c']);
      expect(lib.snippets.firstWhere((s) => s.id == 'a').categoryId, isNull);
      expect(lib.snippets.firstWhere((s) => s.id == 'b').categoryId, 'docker');
    });

    test('withSnippet baru di depan, id sama di tempat; withoutHost hanya melepas host itu', () {
      var lib = SnippetLibrary().withSnippet(sn('a', hostId: 'h1')).withSnippet(sn('b', hostId: 'h2'));
      expect(lib.snippets.map((s) => s.id), ['b', 'a']);
      lib = lib.withSnippet(sn('a', hostId: 'h1').copyWith(title: 'baru'));
      expect(lib.snippets.map((s) => s.id), ['b', 'a']);
      expect(lib.snippets.last.title, 'baru');
      lib = lib.withoutHost('h1');
      expect(lib.snippets.firstWhere((s) => s.id == 'a').hostId, isNull);
      expect(lib.snippets.firstWhere((s) => s.id == 'b').hostId, 'h2');
    });
  });
}
