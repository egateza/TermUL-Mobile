import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/snippet.dart';

void main() {
  group('variabel', () {
    test('variablesOf: urutan kemunculan, tanpa duplikat, hanya huruf kecil dan garis bawah', () {
      expect(Snippet.variablesOf(r'a ${layanan} b ${nama_x} c ${layanan} ${Besar} ${1}'), ['layanan', 'nama_x']);
      expect(Snippet.variablesOf('tanpa variabel'), isEmpty);
    });

    test('fill: variabel terisi diganti, yang kosong atau belum ada dibiarkan', () {
      expect(Snippet.fill(r'systemctl status ${layanan}', {'layanan': 'nginx'}), 'systemctl status nginx');
      expect(Snippet.fill(r'a ${x} ${y}', {'x': '1', 'y': ''}), r'a 1 ${y}');
      expect(Snippet.fill(r'a ${x}', const {}), r'a ${x}');
    });

    test('nilai pengganti tidak ditafsirkan ulang sebagai variabel', () {
      expect(Snippet.fill(r'a ${x} ${y}', {'x': r'${y}', 'y': 'z'}), r'a ${y} z');
    });
  });

  test('firstLine: baris pertama, diberi tanda lanjut bila beberapa baris', () {
    expect(Snippet.create(title: 't', command: 'df -h').firstLine, 'df -h');
    expect(Snippet.create(title: 't', command: 'df -h\ndu -sh').firstLine, 'df -h …');
  });

  group('JSON', () {
    test('bolak-balik, termasuk host, favorit, dan nilai bawaan', () {
      final s = Snippet(
        id: 'a',
        title: 'Status',
        command: r'systemctl status ${layanan}',
        categoryId: 'docker',
        hostId: 'h1',
        favorite: true,
        defaults: {'layanan': 'nginx'},
      );
      expect(Snippet.fromJson(s.toJson()), s);
    });

    test('tanpa host tidak menulis hostId, tanpa kategori tidak menulis category; favorit punya nilai bawaan', () {
      final json = Snippet.create(title: 't', command: 'ls').toJson();
      expect(json.containsKey('hostId'), isFalse);
      expect(json.containsKey('category'), isFalse);
      final s = Snippet.fromJson({'id': 'a', 'title': 't', 'command': 'ls'});
      expect(s.categoryId, isNull);
      expect(s.favorite, isFalse);
      expect(s.hostId, isNull);
    });

    test('rusak: tanpa id, judul, atau perintah; tipe salah', () {
      for (final bad in <Map<String, Object?>>[
        {'title': 't', 'command': 'ls'},
        {'id': 'a', 'title': ' ', 'command': 'ls'},
        {'id': 'a', 'title': 't', 'command': ''},
        {'id': 'a', 'title': 't', 'command': 'ls', 'favorite': 'ya'},
        {'id': 'a', 'title': 't', 'command': 'ls', 'category': 1},
        {
          'id': 'a',
          'title': 't',
          'command': 'ls',
          'defaults': {'x': 1},
        },
      ]) {
        expect(() => Snippet.fromJson(bad), throwsFormatException, reason: '$bad');
      }
    });
  });

  group('penanda berbahaya', () {
    test('bawaan mati; hanya ditulis ke JSON bila menyala; bolak-balik', () {
      final off = Snippet.create(title: 't', command: 'ls');
      expect(off.dangerous, isFalse);
      expect(off.toJson().containsKey('dangerous'), isFalse);
      final on = Snippet.create(title: 't', command: 'ls', dangerous: true);
      expect(on.toJson()['dangerous'], isTrue);
      expect(Snippet.fromJson(on.toJson()), on);
      expect(Snippet.fromJson({'id': 'a', 'title': 't', 'command': 'ls'}).dangerous, isFalse);
    });

    test('tipe salah ditolak; copyWith mengubah dan mempertahankan; ikut dalam kesamaan', () {
      expect(
        () => Snippet.fromJson({'id': 'a', 'title': 't', 'command': 'ls', 'dangerous': 'ya'}),
        throwsFormatException,
      );
      final s = Snippet.create(title: 't', command: 'ls');
      expect(s.copyWith(dangerous: true).dangerous, isTrue);
      expect(s.copyWith(title: 'u').dangerous, isFalse);
      expect(s.copyWith(dangerous: true), isNot(s));
    });
  });

  test('copyWith(hostId: null) melepas host; tanpa argumen mempertahankannya', () {
    final s = Snippet.create(title: 't', command: 'ls', hostId: 'h1');
    expect(s.copyWith(title: 'u').hostId, 'h1');
    expect(s.copyWith(hostId: null).hostId, isNull);
  });
}
