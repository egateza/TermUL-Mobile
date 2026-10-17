import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/storage/json/json_snippet_repository.dart';

Snippet sn(String id, {String? hostId, String? categoryId, String title = 'judul'}) =>
    Snippet(id: id, title: title, command: 'ls $id', hostId: hostId, categoryId: categoryId);

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_snippets_');
    file = File('${dir.path}${Platform.pathSeparator}snippets.json');
  });
  tearDown(() async => dir.delete(recursive: true));

  Future<Map<String, Object?>> readJson() async => jsonDecode(await file.readAsString()) as Map<String, Object?>;

  test('berkas belum ada: kategori bawaan, tanpa snippet, tanpa karantina, berkas belum dibuat', () async {
    final r = JsonSnippetRepository(file);
    final result = await r.load();
    expect(result.hadCorruptFile, isFalse);
    expect(r.library.snippets, isEmpty);
    expect(r.library.categories.map((c) => c.name), ['Sistem', 'Nginx', 'Docker', 'Database']);
    expect(await file.exists(), isFalse);
  });

  test('simpan lalu muat di instans baru menghasilkan data yang sama; berkas versi 2 memuat kategori', () async {
    final a = JsonSnippetRepository(file);
    await a.load();
    await a.saveCategory(SnippetCategory.create('Jaringan'));
    await a.save(sn('a', hostId: 'h1', categoryId: 'nginx'));
    await a.save(sn('b'));
    final b = JsonSnippetRepository(file);
    await b.load();
    expect(b.library, a.library);
    final json = await readJson();
    expect(json['version'], 2);
    expect((json['categories']! as List), hasLength(5));
  });

  test('berkas versi 1 tetap terbaca; ditulis ulang sebagai versi 2 pada mutasi pertama', () async {
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'snippets': [
          {'id': 'a', 'title': 't', 'command': 'ls', 'category': 'docker'},
        ],
      }),
    );
    final r = JsonSnippetRepository(file);
    final result = await r.load();
    expect(result.hadCorruptFile, isFalse);
    expect(r.library.snippets.single.categoryId, 'docker');
    expect(r.library.categoryOf('docker')!.name, 'Docker');
    await r.save(sn('b'));
    final json = await readJson();
    expect(json['version'], 2);
    expect(json['categories'], isNotEmpty);
  });

  test('snippet baru di depan; menyimpan id yang sama mengganti di tempat', () async {
    final r = JsonSnippetRepository(file);
    await r.load();
    await r.save(sn('a'));
    await r.save(sn('b'));
    expect(r.library.snippets.map((s) => s.id), ['b', 'a']);
    await r.save(sn('a', title: 'baru'));
    expect(r.library.snippets.map((s) => s.id), ['b', 'a']);
    expect(r.library.snippets.last.title, 'baru');
  });

  test('hapus; id yang tidak ada tidak menulis berkas', () async {
    final r = JsonSnippetRepository(file);
    await r.load();
    await r.delete('x');
    await r.deleteCategory('tidak-ada');
    await r.clearHost('tidak-ada');
    expect(await file.exists(), isFalse);
    await r.save(sn('a'));
    await r.delete('a');
    expect(r.library.snippets, isEmpty);
  });

  test('clearHost melepas host dari snippet yang terikat saja', () async {
    final r = JsonSnippetRepository(file);
    await r.load();
    await r.save(sn('a', hostId: 'h1'));
    await r.save(sn('b', hostId: 'h2'));
    await r.clearHost('h1');
    expect(r.library.snippets.firstWhere((s) => s.id == 'a').hostId, isNull);
    expect(r.library.snippets.firstWhere((s) => s.id == 'b').hostId, 'h2');
  });

  group('kategori', () {
    test('tambah, ganti nama (snippet tetap di kategorinya), dan tersimpan di disk', () async {
      final r = JsonSnippetRepository(file);
      await r.load();
      final baru = SnippetCategory.create('Jaringan');
      await r.saveCategory(baru);
      await r.save(sn('a', categoryId: baru.id));
      await r.saveCategory(baru.copyWith(name: 'Network'));
      final again = JsonSnippetRepository(file);
      await again.load();
      expect(again.library.categoryOf(baru.id)!.name, 'Network');
      expect(again.library.snippets.single.categoryId, baru.id);
    });

    test('hapus kategori: snippet-nya menjadi tanpa kategori dan tetap ada, dalam satu penulisan', () async {
      var writes = 0;
      final r = JsonSnippetRepository(
        file,
        writer: (f, b) async {
          writes++;
          await f.writeAsBytes(b);
        },
      );
      await r.load();
      await r.save(sn('a', categoryId: 'nginx'));
      writes = 0;
      await r.deleteCategory('nginx');
      expect(writes, 1);
      expect(r.library.hasCategory('nginx'), isFalse);
      expect(r.library.snippets.single.categoryId, isNull);
      final again = JsonSnippetRepository(file);
      await again.load();
      expect(again.library.snippets.single.categoryId, isNull);
      expect(again.library.hasCategory('nginx'), isFalse);
    });

    test('semua kategori dihapus tetap kosong setelah dimuat ulang (tidak kembali ke bawaan)', () async {
      final r = JsonSnippetRepository(file);
      await r.load();
      for (final c in List.of(r.library.categories)) {
        await r.deleteCategory(c.id);
      }
      final again = JsonSnippetRepository(file);
      await again.load();
      expect(again.library.categories, isEmpty);
    });

    test('snippet yang menunjuk kategori yang tidak ada dilepas saat dimuat', () async {
      await file.writeAsString(
        jsonEncode({
          'version': 2,
          'categories': [
            {'id': 'x', 'name': 'X'},
          ],
          'snippets': [
            {'id': 'a', 'title': 't', 'command': 'ls', 'category': 'hilang'},
          ],
        }),
      );
      final r = JsonSnippetRepository(file);
      final result = await r.load();
      expect(result.hadCorruptFile, isFalse);
      expect(r.library.snippets.single.categoryId, isNull);
    });
  });

  test('changes mengumumkan keadaan baru setelah ditulis', () async {
    final r = JsonSnippetRepository(file);
    await r.load();
    final seen = <int>[];
    final sub = r.changes.listen((s) => seen.add(s.snippets.length));
    await r.save(sn('a'));
    await r.save(sn('b'));
    await Future<void>.delayed(Duration.zero);
    expect(seen, [1, 2]);
    await sub.cancel();
  });

  test(
    'berkas rusak (bukan JSON, id snippet atau kategori ganda, kategori tanpa nama): disisihkan, mulai dari awal',
    () async {
      final dupSnippet = jsonEncode({
        'version': 2,
        'snippets': [sn('a').toJson(), sn('a').toJson()],
      });
      final dupCategory = jsonEncode({
        'version': 2,
        'categories': [
          {'id': 'x', 'name': 'A'},
          {'id': 'x', 'name': 'B'},
        ],
      });
      final noName = jsonEncode({
        'version': 2,
        'categories': [
          {'id': 'x'},
        ],
      });
      for (final content in ['{ini rusak', dupSnippet, dupCategory, noName]) {
        await file.writeAsString(content);
        final r = JsonSnippetRepository(file);
        final result = await r.load();
        expect(result.hadCorruptFile, isTrue, reason: content);
        expect(r.library.snippets, isEmpty);
        expect(r.library.categories.map((c) => c.id), ['sistem', 'nginx', 'docker', 'database']);
        expect(await File(result.quarantinedPath!).readAsString(), content);
        expect(await file.exists(), isFalse);
        await File(result.quarantinedPath!).delete();
      }
    },
  );

  test('penulisan gagal: StorageException, keadaan dan berkas lama tidak berubah', () async {
    var fail = false;
    final r = JsonSnippetRepository(
      file,
      writer: (f, b) async {
        if (fail) throw const StorageException('disk penuh');
        await f.writeAsBytes(b);
      },
    );
    await r.load();
    await r.save(sn('a'));
    final before = await file.readAsString();
    fail = true;
    await expectLater(r.save(sn('b')), throwsA(isA<StorageException>()));
    await expectLater(r.deleteCategory('nginx'), throwsA(isA<StorageException>()));
    expect(r.library.snippets.map((s) => s.id), ['a']);
    expect(r.library.hasCategory('nginx'), isTrue);
    expect(await file.readAsString(), before);
  });
}
