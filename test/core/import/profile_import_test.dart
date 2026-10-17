import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/import/profile_import.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/profile_snapshot.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';

String uid(int n) => '${n.toString().padLeft(8, '0')}-0000-4000-8000-000000000000';

Map<String, Object?> entry(
  int n, {
  String? group,
  String auth = 'AGENT',
  String? keyPath,
  String? jump,
  String? name,
}) => {
  'id': uid(n),
  'name': name ?? 'srv-$n',
  'group': group ?? '',
  'host': '10.0.0.$n',
  'port': 22,
  'username': 'u',
  'authMethod': auth,
  'privateKeyPath': keyPath,
  'jumpHostId': jump,
  'environment': 'NONE',
  'initialDirectory': null,
  'notes': null,
  'autoSudo': false,
  'os': null,
  'terminalTheme': null,
  'wslDistro': null,
};

String file(
  List<Object?> profiles, {
  List<String> groups = const [],
  List<String> favorites = const [],
  List<String> recent = const [],
}) => jsonEncode({'version': 1, 'groups': groups, 'profiles': profiles, 'favorites': favorites, 'recent': recent});

HostProfile local(int n, {String? group}) =>
    HostProfile(id: uid(n), name: 'hp-$n', group: group, host: 'hp$n', username: 'me', authMethod: AuthMethod.password);

void main() {
  group('baca berkas', () {
    test('membaca objek desktop lengkap dengan grup, favorit, dan recent', () {
      final s = ProfileImportSource.parse(
        file(
          [entry(1, group: 'Production'), entry(2)],
          groups: ['Sewa'],
          favorites: [uid(1)],
          recent: [uid(2), uid(1)],
        ),
      );
      expect(s.profiles.map((p) => p.id), [uid(1), uid(2)]);
      expect(s.groups, ['Sewa']);
      expect(s.favorites, [uid(1)]);
      expect(s.recent, [uid(2), uid(1)]);
      expect(s.rejections, isEmpty);
    });

    test('menerima daftar profil polos', () {
      final s = ProfileImportSource.parse(jsonEncode([entry(1)]));
      expect(s.profiles, hasLength(1));
    });

    test('bukan JSON, bukan daftar profil, atau tanpa profiles: ImportFormatException', () {
      expect(() => ProfileImportSource.parse('bukan json'), throwsA(isA<ImportFormatException>()));
      expect(() => ProfileImportSource.parse('"teks"'), throwsA(isA<ImportFormatException>()));
      expect(() => ProfileImportSource.parse('{"profiles": 3}'), throwsA(isA<ImportFormatException>()));
      expect(() => ProfileImportSource.parse('{}'), throwsA(isA<ImportFormatException>()));
    });

    test('entri rusak dilewati dan dilaporkan, entri lain tetap dibaca', () {
      final bad = entry(2)..['port'] = 99999;
      final noHost = entry(3)..['host'] = ' ';
      final s = ProfileImportSource.parse(file([entry(1), bad, 'bukan objek', noHost, entry(1, name: 'ganda')]));
      expect(s.profiles.map((p) => p.id), [uid(1)]);
      expect(s.rejections.map((r) => r.index), [2, 3, 4, 5]);
      expect(s.rejections.first.name, 'srv-2');
      expect(s.rejections.last.reason, contains('ganda'));
    });

    test('id favorit atau recent yang bukan UUID dibuang tanpa menggagalkan impor', () {
      final s = ProfileImportSource.parse(file([entry(1)], favorites: ['rusak', uid(1)], recent: ['x']));
      expect(s.favorites, [uid(1)]);
      expect(s.recent, isEmpty);
    });
  });

  group('penggabungan', () {
    final existing = ProfileSnapshot(
      groups: ['Lokal'],
      profiles: [
        local(1, group: 'Lokal'),
        local(9),
      ],
      favorites: [uid(9)],
      recent: [uid(1)],
    );

    test('profil di HP tidak pernah hilang, profil baru ditambahkan', () {
      final s = ProfileImportSource.parse(file([entry(2), entry(3)]));
      for (final policy in ImportConflictPolicy.values) {
        final plan = s.plan(existing, policy);
        expect(plan.merged.profiles.map((p) => p.id), containsAll([uid(1), uid(9), uid(2), uid(3)]));
        expect(plan.added, 2);
        expect(plan.merged.profiles, hasLength(4));
      }
    });

    test('id sama + lewati: profil di HP tidak berubah', () {
      final s = ProfileImportSource.parse(file([entry(1, name: 'dari-berkas')]));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.skipped, 1);
      expect(plan.added, 0);
      expect(plan.isEmpty, isTrue);
      expect(plan.merged.find(uid(1))!.name, 'hp-1');
    });

    test('id sama + perbarui: isi diganti, jumlah tetap', () {
      final s = ProfileImportSource.parse(file([entry(1, name: 'dari-berkas')]));
      final plan = s.plan(existing, ImportConflictPolicy.update);
      expect(plan.updated, 1);
      expect(plan.merged.find(uid(1))!.name, 'dari-berkas');
      expect(plan.merged.profiles, hasLength(2));
    });

    test('id sama + salinan: profil lama utuh, salinan berid baru', () {
      final s = ProfileImportSource.parse(file([entry(1, name: 'dari-berkas')]));
      final plan = s.plan(existing, ImportConflictPolicy.copy);
      expect(plan.copied, 1);
      expect(plan.merged.find(uid(1))!.name, 'hp-1');
      expect(plan.merged.profiles, hasLength(3));
      final copy = plan.merged.profiles.singleWhere((p) => p.name == 'dari-berkas (salinan)');
      expect(copy.id, isNot(uid(1)));
    });

    test('grup digabung, termasuk grup milik profil impor', () {
      final s = ProfileImportSource.parse(file([entry(2, group: 'Production')], groups: ['Sewa']));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.allGroups, containsAll(['Lokal', 'Sewa', 'Production']));
    });

    test('favorit dan recent digabung; yang lama tetap, yang lama di depan', () {
      final s = ProfileImportSource.parse(file([entry(2), entry(3)], favorites: [uid(3)], recent: [uid(3), uid(2)]));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.favorites, [uid(9), uid(3)]);
      expect(plan.merged.recent, [uid(1), uid(3), uid(2)]);
    });

    test('recent dibatasi lima', () {
      final s = ProfileImportSource.parse(
        file([for (var i = 10; i < 20; i++) entry(i)], recent: [for (var i = 10; i < 20; i++) uid(i)]),
      );
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.recent, hasLength(ProfileSnapshot.recentLimit));
      expect(plan.merged.recent.first, uid(1));
    });

    test('favorit profil yang dilewati tidak mengubah favorit di HP', () {
      final s = ProfileImportSource.parse(file([entry(1)], favorites: [uid(1)]));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.favorites, [uid(9)]);
    });

    test('jump host: sesama impor dipertahankan, mengikuti salinan, atau menunjuk profil di HP', () {
      final s = ProfileImportSource.parse(file([entry(2), entry(3, jump: uid(2)), entry(4, jump: uid(9))]));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.find(uid(3))!.jumpHostId, uid(2));
      expect(plan.merged.find(uid(4))!.jumpHostId, uid(9));
      expect(plan.warnings, isEmpty);

      final copyAll = ProfileImportSource.parse(file([entry(1), entry(3, jump: uid(1))]));
      final copied = copyAll.plan(existing, ImportConflictPolicy.copy);
      final copyOf1 = copied.merged.profiles.singleWhere((p) => p.name == 'srv-1 (salinan)');
      expect(copied.merged.find(uid(3))!.jumpHostId, copyOf1.id);
    });

    test('jump host yang tidak ada dikosongkan dengan peringatan', () {
      final s = ProfileImportSource.parse(file([entry(2, jump: uid(77))]));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.find(uid(2))!.jumpHostId, isNull);
      expect(plan.warnings.single.kind, ImportWarningKind.jumpHostMissing);
      expect(plan.warnings.single.profileName, 'srv-2');
    });

    test('profil KEY dengan path perangkat asal: path dibuang dengan peringatan', () {
      final s = ProfileImportSource.parse(file([entry(2, auth: 'KEY', keyPath: r'C:\Users\a\id_ed25519')]));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.find(uid(2))!.privateKeyPath, isNull);
      expect(plan.merged.find(uid(2))!.authMethod, AuthMethod.key);
      expect(plan.warnings.single.kind, ImportWarningKind.keyPathDropped);
    });

    test('profil AGENT diimpor apa adanya', () {
      final s = ProfileImportSource.parse(file([entry(2)]));
      final plan = s.plan(existing, ImportConflictPolicy.skip);
      expect(plan.merged.find(uid(2))!.authMethod, AuthMethod.agent);
    });

    test('plan tidak mengubah snapshot yang ada', () {
      final s = ProfileImportSource.parse(file([entry(2)]));
      s.plan(existing, ImportConflictPolicy.update);
      expect(existing.profiles, hasLength(2));
    });
  });

  test('berkas ekspor desktop berukuran besar tetap terbaca (22 profil)', () {
    final s = ProfileImportSource.parse(file([for (var i = 1; i <= 22; i++) entry(i, group: i.isEven ? 'A' : null)]));
    final plan = s.plan(ProfileSnapshot.empty(), ImportConflictPolicy.skip);
    expect(plan.added, 22);
    expect(plan.merged.allGroups, ['A']);
  });

  group('penulisan ke disk', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('termul_import_'));
    tearDown(() async => dir.delete(recursive: true));

    test('impor ditulis ke disk dan profil lama bertahan setelah dimuat ulang', () async {
      // update() menghitung dari keadaan terkini lalu menulis atomik.
      Future<JsonHostRepository> open() async {
        final r = JsonHostRepository(File('${dir.path}${Platform.pathSeparator}profiles.json'));
        await r.load();
        return r;
      }

      final repo = await open();
      await repo.save(local(1));
      final s = ProfileImportSource.parse(file([entry(2)], favorites: [uid(2)]));
      await repo.update((cur) => s.plan(cur, ImportConflictPolicy.skip).merged);

      final reloaded = await open();
      expect(reloaded.snapshot.profiles.map((p) => p.id), [uid(1), uid(2)]);
      expect(reloaded.snapshot.favorites, [uid(2)]);
    });
  });
}
