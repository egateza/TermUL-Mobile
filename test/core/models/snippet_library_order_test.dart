import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/models/snippet_library.dart';
import 'package:termul_mobile/core/storage/json/json_snippet_repository.dart';

List<String> ids(SnippetLibrary l) => [for (final c in l.categories) c.id];

void main() {
  group('urutan kategori (model)', () {
    final lib = SnippetLibrary(); // sistem, nginx, docker, database

    test('pindah ke bawah, ke atas, ke ujung', () {
      expect(ids(lib.withCategoryMoved('sistem', 2)), ['nginx', 'docker', 'sistem', 'database']);
      expect(ids(lib.withCategoryMoved('database', 0)), ['database', 'sistem', 'nginx', 'docker']);
      expect(ids(lib.withCategoryMoved('nginx', 3)), ['sistem', 'docker', 'database', 'nginx']);
    });

    test('indeks di luar rentang dibatasi', () {
      expect(ids(lib.withCategoryMoved('sistem', 99)), ['nginx', 'docker', 'database', 'sistem']);
      expect(ids(lib.withCategoryMoved('docker', -5)), ['docker', 'sistem', 'nginx', 'database']);
    });

    test('posisi tetap atau id tidak ada: objek yang sama (tidak ada penulisan)', () {
      expect(identical(lib.withCategoryMoved('nginx', 1), lib), isTrue);
      expect(identical(lib.withCategoryMoved('tidak-ada', 0), lib), isTrue);
    });

    test('snippet dan nama tidak berubah saat dipindah', () {
      final withSnippet = lib.withSnippet(const Snippet(id: 'a', title: 't', command: 'ls', categoryId: 'docker'));
      final moved = withSnippet.withCategoryMoved('docker', 0);
      expect(moved.snippets, withSnippet.snippets);
      expect(moved.categoryOf('docker')!.name, 'Docker');
    });
  });

  group('urutan kategori (penyimpanan)', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('termul_order_');
      file = File('${dir.path}${Platform.pathSeparator}snippets.json');
    });
    tearDown(() async => dir.delete(recursive: true));

    test('urutan tersimpan dan dipakai setelah dimuat ulang; kategori baru tetap di akhir', () async {
      final r = JsonSnippetRepository(file);
      await r.load();
      await r.moveCategory('database', 0);
      await r.saveCategory(const SnippetCategory(id: 'baru', name: 'Baru'));
      final again = JsonSnippetRepository(file);
      await again.load();
      expect(ids(again.library), ['database', 'sistem', 'nginx', 'docker', 'baru']);
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
      await r.moveCategory('sistem', 0);
      await r.moveCategory('tidak-ada', 1);
      expect(writes, 0);
      await r.moveCategory('sistem', 1);
      expect(writes, 1);
    });
  });
}
