import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/io/atomic_file.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';

String uid(int n) => '${n.toString().padLeft(8, '0')}-0000-4000-8000-000000000000';

HostProfile p(int n, {String? group, AuthMethod auth = AuthMethod.password}) =>
    HostProfile(id: uid(n), name: 'host-$n', group: group, host: 'h$n', username: 'u', authMethod: auth);

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_hosts_');
    file = File('${dir.path}${Platform.pathSeparator}profiles.json');
  });
  tearDown(() async => dir.delete(recursive: true));

  JsonHostRepository repo({AtomicWriter? writer}) => writer == null ? JsonHostRepository(file) : JsonHostRepository(file, writer: writer);

  test('berkas belum ada: snapshot kosong, tidak ada karantina, berkas belum dibuat', () async {
    final r = repo();
    final result = await r.load();
    expect(result.hadCorruptFile, isFalse);
    expect(r.snapshot.profiles, isEmpty);
    expect(await file.exists(), isFalse);
  });

  test('simpan lalu muat di instans baru menghasilkan data yang sama', () async {
    final a = repo();
    await a.load();
    await a.save(p(1, group: 'Production'));
    await a.save(p(2, auth: AuthMethod.key));
    await a.setFavorite(uid(1), favorite: true);
    await a.markUsed(uid(2));
    final b = repo();
    await b.load();
    expect(b.snapshot.profiles, a.snapshot.profiles);
    expect(b.snapshot.favorites, [uid(1)]);
    expect(b.snapshot.recent, [uid(2)]);
    expect(b.snapshot.profiles.last.privateKeyPath, isNull);
  });

  test('berkas di disk berformat JSON dengan version, groups, profiles, favorites, recent', () async {
    final r = repo();
    await r.load();
    await r.save(p(1));
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    expect(json.keys, ['version', 'groups', 'profiles', 'favorites', 'recent']);
    expect(json['version'], 1);
  });

  test('changes mengumumkan snapshot baru hanya bila ada perubahan', () async {
    final r = repo();
    await r.load();
    final seen = <int>[];
    final sub = r.changes.listen((s) => seen.add(s.profiles.length));
    await r.save(p(1));
    await r.markUsed(uid(1));
    await r.markUsed(uid(1)); // sama dengan yang terdepan: tidak berubah
    await r.setFavorite(uid(99), favorite: true); // id tak ada: tidak berubah
    await r.delete(uid(1));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, [1, 1, 0]);
  });

  test('penulisan gagal: StorageException, snapshot dan berkas lama tidak berubah', () async {
    final good = repo();
    await good.load();
    await good.save(p(1));
    final before = await file.readAsString();

    var fail = false;
    final r = repo(writer: (f, b) async {
      if (fail) throw const StorageException('disk penuh');
      await writeAtomic(f, b);
    });
    await r.load();
    fail = true;
    await expectLater(r.save(p(2)), throwsA(isA<StorageException>()));
    expect(r.snapshot.profiles.map((e) => e.id), [uid(1)]);
    expect(await file.readAsString(), before);
    fail = false;
    await r.save(p(2)); // tetap bisa menulis setelah kegagalan
    expect(r.snapshot.profiles, hasLength(2));
  });

  test('berkas rusak: dikarantina, mulai kosong, dilaporkan, dan simpan berikutnya tidak menimpa berkas rusak', () async {
    await file.writeAsString('{ini rusak');
    final r = repo();
    final result = await r.load();
    expect(result.hadCorruptFile, isTrue);
    expect(r.snapshot.profiles, isEmpty);
    await r.save(p(1));
    final corrupt = File(result.quarantinedPath!);
    expect(await corrupt.readAsString(), '{ini rusak');
    final again = repo();
    await again.load();
    expect(again.snapshot.profiles, hasLength(1));
  });

  test('id profil duplikat di berkas dianggap rusak', () async {
    final one = p(1).toJson();
    await file.writeAsString(jsonEncode({'version': 1, 'profiles': [one, one]}));
    final result = await (repo()).load();
    expect(result.hadCorruptFile, isTrue);
  });

  test('versi tak dikenal dan properti tak dikenal tidak membuat berkas dianggap rusak, versi dipertahankan', () async {
    await file.writeAsString(jsonEncode({'version': 3, 'masa_depan': 1, 'profiles': [p(1).toJson()]}));
    final r = repo();
    final result = await r.load();
    expect(result.hadCorruptFile, isFalse);
    await r.save(p(2));
    expect((jsonDecode(await file.readAsString()) as Map<String, Object?>)['version'], 3);
  });

  test('50 penyimpanan serentak semuanya masuk (mutasi diserialkan)', () async {
    final r = repo();
    await r.load();
    await Future.wait([for (var i = 1; i <= 50; i++) r.save(p(i))]);
    final again = repo();
    await again.load();
    expect(again.snapshot.profiles, hasLength(50));
  });

  test('markUsed menjaga maksimal 5 terbaru; clearRecent mengosongkan', () async {
    final r = repo();
    await r.load();
    for (var i = 1; i <= 7; i++) {
      await r.save(p(i));
      await r.markUsed(uid(i));
    }
    expect(r.snapshot.recent, [uid(7), uid(6), uid(5), uid(4), uid(3)]);
    await r.clearRecent();
    expect(r.snapshot.recent, isEmpty);
  });

  group('grup', () {
    test('addGroup, deleteGroup gagal bila masih berisi profil, rename memindahkan subgrup dan profil', () async {
      final r = repo();
      await r.load();
      await r.addGroup('Kosong');
      await r.save(p(1, group: 'A/B'));
      await r.save(p(2, group: 'A'));
      expect(r.snapshot.allGroups, ['A', 'A/B', 'Kosong']);

      await expectLater(r.deleteGroup('A'), throwsStateError);
      await r.deleteGroup('Kosong');
      expect(r.snapshot.groups, isNot(contains('Kosong')));

      await r.renameGroup('A', 'Z/Y');
      expect(r.snapshot.find(uid(1))!.group, 'Z/Y/B');
      expect(r.snapshot.find(uid(2))!.group, 'Z/Y');
      expect(() => r.renameGroup('', 'X'), throwsArgumentError);
    });
  });

  group('fixture bergaya desktop (karangan, 23 profil)', () {
    late Map<String, Object?> raw;
    setUp(() => raw = jsonDecode(File('test/fixtures/profiles_desktop_like.json').readAsStringSync()) as Map<String, Object?>);

    test('termuat tanpa karantina dengan 23 profil dan semua keunikan', () async {
      await file.writeAsString(jsonEncode(raw));
      final r = repo();
      final result = await r.load();
      expect(result.hadCorruptFile, isFalse);
      final s = r.snapshot;
      expect(s.profiles, hasLength(23));
      expect(s.profiles.where((x) => x.authMethod == AuthMethod.agent), hasLength(22));
      expect(s.profiles.where((x) => x.authMethod == AuthMethod.password), hasLength(1));
      expect(s.profiles.where((x) => x.os == null), hasLength(5));
      expect(s.profiles.where((x) => x.jumpHostId != null), hasLength(1));
      expect(s.profiles.where((x) => x.wslDistro != null), hasLength(1));
      expect(s.profiles.where((x) => x.port == 2211), hasLength(2));
      expect(s.favorites, hasLength(1));
      expect(s.recent, hasLength(5));
    });

    test('grup yang dipakai profil tetapi tidak ada di "groups" ikut terhitung (termasuk root kosong)', () async {
      await file.writeAsString(jsonEncode(raw));
      final r = repo();
      await r.load();
      expect(r.snapshot.groups, ['Production', 'Sewa']);
      expect(r.snapshot.allGroups, ['Development', 'Production', 'Sewa']);
      expect(r.snapshot.profilesIn('').map((e) => e.name), ['Ubuntu-lokal']);
    });

    test('baca lalu tulis ulang tidak menghilangkan satu pun field profil', () async {
      await file.writeAsString(jsonEncode(raw));
      final r = repo();
      await r.load();
      final firstId = (raw['profiles']! as List<Object?>).cast<Map<String, Object?>>().first['id']! as String;
      await r.markUsed(firstId); // memicu penulisan
      final written = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final before = (raw['profiles']! as List<Object?>).cast<Map<String, Object?>>();
      final after = (written['profiles']! as List<Object?>).cast<Map<String, Object?>>();
      expect(after, before);
    });
  });
}
