import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/environment_tag.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/os_info.dart';

const id1 = '11111111-1111-4111-8111-111111111111';
const id2 = '22222222-2222-4222-8222-222222222222';

HostProfile profile({
  String id = id1,
  String name = 'app-01',
  String? group,
  int port = 22,
  AuthMethod? auth,
  String? jump,
}) => HostProfile(
  id: id,
  name: name,
  group: group,
  host: '192.0.2.1',
  port: port,
  username: 'pengguna',
  authMethod: auth,
  jumpHostId: jump,
);

void main() {
  group('validasi (meniru HostProfile desktop)', () {
    test('nama, host, dan username wajib; di-trim', () {
      expect(() => HostProfile(id: id1, name: ' ', host: 'h', username: 'u'), throwsArgumentError);
      expect(() => HostProfile(id: id1, name: 'n', host: '', username: 'u'), throwsArgumentError);
      expect(() => HostProfile(id: id1, name: 'n', host: 'h', username: '  '), throwsArgumentError);
      final p = HostProfile(id: id1, name: ' n ', host: ' h ', username: ' u ');
      expect((p.name, p.host, p.username), ('n', 'h', 'u'));
    });

    test('port 1..65535', () {
      expect(() => profile(port: 0), throwsArgumentError);
      expect(() => profile(port: 65536), throwsArgumentError);
      expect(profile(port: 65535).port, 65535);
    });

    test('id harus UUID dan disimpan huruf kecil', () {
      expect(() => profile(id: 'bukan-uuid'), throwsArgumentError);
      expect(profile(id: id1.toUpperCase()).id, id1);
    });

    test('jump host tidak boleh diri sendiri', () {
      expect(() => profile(jump: id1), throwsArgumentError);
      expect(profile(jump: id2).jumpHostId, id2);
    });

    test('bawaan: AGENT dan NONE, teks kosong menjadi null', () {
      final p = HostProfile(
        id: id1,
        name: 'n',
        host: 'h',
        username: 'u',
        notes: '  ',
        privateKeyPath: '',
        wslDistro: ' ',
      );
      expect(p.authMethod, AuthMethod.agent);
      expect(p.environment, EnvironmentTag.none);
      expect((p.notes, p.privateKeyPath, p.wslDistro), (null, null, null));
    });

    test('KEY tanpa privateKeyPath diizinkan di mobile (beda dengan desktop)', () {
      expect(profile(auth: AuthMethod.key).privateKeyPath, isNull);
    });
  });

  group('normalizeGroup', () {
    test('segmen di-trim, kosong dibuang, backslash menjadi slash', () {
      expect(HostProfile.normalizeGroup(' Produksi \\ Backend / '), 'Produksi/Backend');
      expect(HostProfile.normalizeGroup('//a//b//'), 'a/b');
      expect(HostProfile.normalizeGroup('   '), '');
      expect(HostProfile.normalizeGroup(null), '');
    });
  });

  group('JSON', () {
    test('toJson menulis semua 16 field dengan urutan desktop, termasuk null', () {
      final json = profile().toJson();
      expect(json.keys.toList(), [
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
        'wslDistro', //
      ]);
      expect(json['authMethod'], 'AGENT');
      expect(json['environment'], 'NONE');
      expect(json['os'], isNull);
    });

    test('bolak-balik tidak menghilangkan field', () {
      final p = HostProfile(
        id: id1,
        name: 'n',
        group: 'A/B',
        host: 'h',
        port: 2211,
        username: 'u',
        authMethod: AuthMethod.password,
        jumpHostId: id2,
        environment: EnvironmentTag.dev,
        initialDirectory: '/srv',
        notes: 'catatan',
        autoSudo: true,
        os: OsInfo(id: 'ubuntu', versionId: '24.04', prettyName: 'Ubuntu 24.04 LTS'),
        terminalTheme: 'tema',
        wslDistro: 'Ubuntu-22.04',
      );
      expect(HostProfile.fromJson(p.toJson()), p);
    });

    test('properti tak dikenal diabaikan dan field hilang memakai bawaan', () {
      final p = HostProfile.fromJson({
        'id': id1,
        'name': 'n',
        'host': 'h',
        'username': 'u',
        'masa_depan': {'x': 1},
      });
      expect((p.port, p.authMethod, p.autoSudo, p.os), (22, AuthMethod.agent, false, null));
    });

    test('tipe salah dan nilai enum asing ditolak sebagai FormatException', () {
      Map<String, Object?> base() => {'id': id1, 'name': 'n', 'host': 'h', 'username': 'u'};
      expect(() => HostProfile.fromJson({...base(), 'port': '22'}), throwsFormatException);
      expect(() => HostProfile.fromJson({...base(), 'authMethod': 'CERT'}), throwsFormatException);
      expect(() => HostProfile.fromJson({...base(), 'environment': 'QA'}), throwsFormatException);
      expect(() => HostProfile.fromJson({...base(), 'autoSudo': 'ya'}), throwsFormatException);
      expect(() => HostProfile.fromJson({'name': 'n', 'host': 'h', 'username': 'u'}), throwsFormatException);
    });
  });

  group('OsInfo', () {
    test('id harus [a-z0-9._-], huruf kecil; teks dibersihkan dan dipotong 80', () {
      expect(OsInfo(id: ' Ubuntu ').id, 'ubuntu');
      expect(() => OsInfo(id: 'ubu ntu'), throwsArgumentError);
      expect(() => OsInfo(id: null), throwsArgumentError);
      expect(OsInfo(id: 'a', prettyName: 'x\u0007y').prettyName, 'xy');
      expect(OsInfo(id: 'a', prettyName: 'z' * 200).prettyName, hasLength(80));
      expect(OsInfo(id: 'a', versionId: '  ').versionId, isNull);
    });
  });

  test('duplicate: id baru, nama "(salinan)"', () {
    final d = profile().duplicate();
    expect(d.id, isNot(id1));
    expect(d.name, 'app-01 (salinan)');
  });

  test('address menyembunyikan port 22', () {
    expect(profile().address, 'pengguna@192.0.2.1');
    expect(profile(port: 2211).address, 'pengguna@192.0.2.1:2211');
  });
}
