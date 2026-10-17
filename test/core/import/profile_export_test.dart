import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/import/profile_export.dart';
import 'package:termul_mobile/core/import/profile_import.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/profile_snapshot.dart';

String uid(int n) => '${n.toString().padLeft(8, '0')}-0000-4000-8000-000000000000';

HostProfile p(int n, {AuthMethod auth = AuthMethod.password, String? group, String? jump, String? keyPath}) =>
    HostProfile(
      id: uid(n),
      name: 'host-$n',
      group: group,
      host: 'h$n.contoh',
      port: 2200 + n,
      username: 'u',
      authMethod: auth,
      jumpHostId: jump,
      privateKeyPath: keyPath,
      notes: 'catatan $n',
      autoSudo: n.isEven,
    );

void main() {
  const exporter = ProfileExporter();

  test('ekspor memuat semua profil, grup, favorit, dan recent dengan skema desktop', () {
    final snap = ProfileSnapshot(
      groups: ['Kosong'],
      profiles: [
        p(1, group: 'Prod'),
        p(2, jump: uid(1)),
      ],
      favorites: [uid(2)],
      recent: [uid(1), uid(2)],
    );
    final r = exporter.export(snap);
    expect(r.count, 2);
    final json = jsonDecode(r.text) as Map<String, Object?>;
    expect(json.keys, ['version', 'groups', 'profiles', 'favorites', 'recent']);
    expect(json['groups'], ['Kosong']);
    expect((json['profiles']! as List).first, containsPair('port', 2201));
    expect(json['favorites'], [uid(2)]);
    expect(json['recent'], [uid(1), uid(2)]);
  });

  test('tidak ada rahasia: hanya kunci profil yang dikenal desktop', () {
    final r = exporter.export(ProfileSnapshot(profiles: [p(1)]));
    final profile =
        ((jsonDecode(r.text) as Map<String, Object?>)['profiles']! as List<Object?>).single! as Map<String, Object?>;
    expect(profile.keys.toSet(), {
      'id',
      'name',
      'group',
      'host',
      'port',
      'username',
      'authMethod',
      'privateKeyPath',
      'jumpHostId',
      'environment',
      'initialDirectory',
      'notes',
      'autoSudo',
      'os',
      'terminalTheme',
      'wslDistro',
    });
  });

  test('profil KEY ditulis sebagai AGENT tanpa path, dihitung, dan snapshot asli tidak berubah', () {
    final snap = ProfileSnapshot(
      profiles: [
        p(1, auth: AuthMethod.key),
        p(2, auth: AuthMethod.key, keyPath: r'C:\k'),
        p(3),
        p(4, auth: AuthMethod.agent),
      ],
    );
    final r = exporter.export(snap);
    expect(r.keyConverted, 2);
    final list = ((jsonDecode(r.text) as Map<String, Object?>)['profiles']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(list.map((e) => e['authMethod']), ['AGENT', 'AGENT', 'PASSWORD', 'AGENT']);
    expect(list.every((e) => e['privateKeyPath'] == null), isTrue);
    expect(snap.profiles.first.authMethod, AuthMethod.key);
  });

  test('daftar kosong: nol profil', () {
    expect(exporter.export(ProfileSnapshot.empty()).count, 0);
  });

  test('ekspor lalu impor ke HP kosong mengembalikan profil yang sama (selain KEY menjadi AGENT)', () {
    final snap = ProfileSnapshot(
      groups: ['Kosong'],
      profiles: [
        p(1, group: 'Prod/Backend'),
        p(2, jump: uid(1)),
        p(3, auth: AuthMethod.agent),
      ],
      favorites: [uid(3)],
      recent: [uid(2)],
    );
    final r = exporter.export(snap);
    final back = ProfileImportSource.parse(r.text).plan(ProfileSnapshot.empty(), ImportConflictPolicy.skip);
    expect(back.merged.profiles, snap.profiles);
    expect(back.merged.groups, snap.groups);
    expect(back.merged.favorites, snap.favorites);
    expect(back.merged.recent, snap.recent);
    expect(back.warnings, isEmpty);
    expect(back.rejections, isEmpty);
  });
}
