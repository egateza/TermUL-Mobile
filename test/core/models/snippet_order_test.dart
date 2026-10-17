import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/models/snippet_library.dart';
import 'package:termul_mobile/core/storage/json/json_snippet_repository.dart';

Snippet sn(String id) => Snippet(id: id, title: 'judul $id', command: 'ls $id');

List<String> ids(SnippetLibrary l) => [for (final s in l.snippets) s.id];

void main() {
  group('urutan snippet (model)', () {
    final lib = SnippetLibrary(snippets: [sn('a'), sn('b'), sn('c'), sn('d')]);

    test('pindah ke bawah, ke atas, ke ujung', () {
      expect(ids(lib.withSnippetMoved('a', 2)), ['b', 'c', 'a', 'd']);
      expect(ids(lib.withSnippetMoved('d', 0)), ['d', 'a', 'b', 'c']);
      expect(ids(lib.withSnippetMoved('b', 3)), ['a', 'c', 'd', 'b']);
    });

    test('indeks di luar rentang dibatasi; posisi tetap atau id tidak ada: objek yang sama', () {
      expect(ids(lib.withSnippetMoved('a', 99)), ['b', 'c', 'd', 'a']);
      expect(ids(lib.withSnippetMoved('c', -3)), ['c', 'a', 'b', 'd']);
      expect(identical(lib.withSnippetMoved('b', 1), lib), isTrue);
      expect(identical(lib.withSnippetMoved('x', 0), lib), isTrue);
    });

    test('isi snippet dan kategori tidak berubah saat dipindah', () {
      final moved = lib.withSnippetMoved('a', 3);
      expect(moved.categories, lib.categories);
      expect(moved.snippets.firstWhere((s) => s.id == 'a'), sn('a'));
    });
  });

  group('urutan snippet (penyimpanan)', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('termul_sniporder_');
      file = File('${dir.path}${Platform.pathSeparator}snippets.json');
    });
    tearDown(() async => dir.delete(recursive: true));

    test('urutan tersimpan dan dipakai setelah dimuat ulang; snippet baru tetap di depan', () async {
      final r = JsonSnippetRepository(file);
      await r.load();
      await r.save(sn('a'));
      await r.save(sn('b'));
      await r.save(sn('c')); // c, b, a
      await r.moveSnippet('a', 0); // a, c, b
      await r.save(sn('d')); // d, a, c, b
      final again = JsonSnippetRepository(file);
      await again.load();
      expect(ids(again.library), ['d', 'a', 'c', 'b']);
    });

    test('memindahkan ke posisi yang sama tidak menulis berkas', () async {
      var writes = 0;
      final r = JsonSnippetRepository(
        file,
        writer: (f, b) async {
          writes++;
          await f.writeAsBytes(b);
        },
      );
      await r.load();
      await r.save(sn('a'));
      await r.save(sn('b')); // b, a
      writes = 0;
      await r.moveSnippet('b', 0);
      await r.moveSnippet('x', 1);
      expect(writes, 0);
      await r.moveSnippet('b', 1);
      expect(writes, 1);
    });
  });
}
