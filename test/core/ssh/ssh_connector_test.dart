import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/known_host.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/ssh/ssh_failure.dart';
import 'package:termul_mobile/core/storage/json/json_known_hosts_repository.dart';

/// Uji terhadap server SSH sungguhan. Konfigurasi (alamat, user, password, jalur kunci) dibaca dari berkas JSON
/// di luar repo: `--dart-define=SSH_TEST_CONFIG=<jalur config.json>`. Tanpa itu, tes dilewati. Kredensial tidak
/// pernah dicetak dan tidak ada di repo.
const configPath = String.fromEnvironment('SSH_TEST_CONFIG');

class Cfg {
  Cfg(this.json, this.dir);

  final Map<String, Object?> json;
  final String dir;

  String s(String k) => json[k]! as String;
  int get port => json['port']! as int;
  int get portAlt => json['portAlt']! as int;
  String key(String name) => File('$dir${Platform.pathSeparator}$name').readAsStringSync();
}

Cfg? loadCfg() {
  if (configPath.isEmpty || !File(configPath).existsSync()) return null;
  final json = jsonDecode(File(configPath).readAsStringSync()) as Map<String, Object?>;
  return Cfg(json, File(configPath).parent.path);
}

HostProfile profileFor(Cfg c, {int? port}) => HostProfile(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'uji',
  host: c.s('host'),
  port: port ?? c.port,
  username: c.s('user'),
);

void main() {
  final cfg = loadCfg();
  if (cfg == null) {
    test('SSH sungguhan', () {}, skip: 'SSH_TEST_CONFIG tidak diisi');
    return;
  }

  late Directory dir;
  late JsonKnownHostsRepository known;
  late SshConnector connector;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_ssh_');
    known = JsonKnownHostsRepository(File('${dir.path}${Platform.pathSeparator}known_hosts.json'));
    await known.load();
    connector = SshConnector(knownHosts: known);
  });
  tearDown(() async => dir.delete(recursive: true));

  Future<HostKeyChoice> trust(HostKeyChallenge c) async => HostKeyChoice.trustAndSave;
  Future<HostKeyChoice> reject(HostKeyChallenge c) async => HostKeyChoice.reject;

  Future<String> run(SshConnection conn, String cmd) async {
    final result = await conn.client.run(cmd);
    return utf8.decode(result).trim();
  }

  group('login', () {
    test('password: lolos, menjalankan perintah, lalu ditutup pengguna', () async {
      final conn = await connector.connect(
        profile: profileFor(cfg),
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: trust,
      );
      expect(await run(conn, 'echo halo-uji'), 'halo-uji');
      expect(await run(conn, 'whoami'), cfg.s('user'));
      conn.close();
      expect(await conn.closed, CloseReason.userClosed);
      expect(conn.isClosed, isTrue);
    });

    for (final k in ['key_ed', 'key_rsa', 'key_ec']) {
      test('kunci $k tanpa passphrase', () async {
        final conn = await connector.connect(
          profile: profileFor(cfg),
          credentials: KeyCredentials(cfg.key(k)),
          decideHostKey: trust,
        );
        expect(await run(conn, 'echo ok'), 'ok');
        conn.close();
      });
    }

    test('kunci ed25519 dengan passphrase benar', () async {
      final conn = await connector.connect(
        profile: profileFor(cfg),
        credentials: KeyCredentials(cfg.key('key_ed_pass'), passphrase: cfg.s('passphrase')),
        decideHostKey: trust,
      );
      expect(await run(conn, 'echo ok'), 'ok');
      conn.close();
    });

    test('passphrase salah atau kosong: SshKeyUnusable(wrongPassphrase) sebelum menyentuh jaringan', () async {
      for (final pass in ['salah', '', null]) {
        await expectLater(
          connector.connect(
            profile: profileFor(cfg),
            credentials: KeyCredentials(cfg.key('key_ed_pass'), passphrase: pass),
            decideHostKey: trust,
          ),
          throwsA(isA<SshKeyUnusable>().having((e) => e.wrongPassphrase, 'wrongPassphrase', isTrue)),
          reason: 'passphrase $pass',
        );
      }
      expect(known.all, isEmpty); // tidak sempat menghubungi server
    });

    test('kunci PKCS#8 ditolak sebagai tidak bisa dipakai', () async {
      if (!cfg.key('key_pkcs8').contains('BEGIN PRIVATE KEY')) {
        markTestSkipped('ssh-keygen server ini tidak menghasilkan PKCS#8 (OpenSSH lama)');
        return;
      }
      await expectLater(
        connector.connect(
          profile: profileFor(cfg),
          credentials: KeyCredentials(cfg.key('key_pkcs8')),
          decideHostKey: trust,
        ),
        throwsA(isA<SshKeyUnusable>()),
      );
    });

    test('password salah: SshAuthFailure', () async {
      await expectLater(
        connector.connect(
          profile: profileFor(cfg),
          credentials: const PasswordCredentials('salah-sekali'),
          decideHostKey: trust,
        ),
        throwsA(isA<SshAuthFailure>()),
      );
    });

    test('user tidak dikenal: SshAuthFailure', () async {
      final p = HostProfile(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'uji',
        host: cfg.s('host'),
        port: cfg.port,
        username: 'tidak_ada_user',
      );
      await expectLater(
        connector.connect(profile: p, credentials: PasswordCredentials(cfg.s('password')), decideHostKey: trust),
        throwsA(isA<SshAuthFailure>()),
      );
    });
  });

  group('verifikasi host key', () {
    test(
      'host baru: sidik jari sama dengan ssh-keygen -lf, tipe keluarga ed25519, ditulis permanen sebelum login',
      () async {
        HostKeyChallenge? seen;
        var storedWhenAsked = -1;
        final conn = await connector.connect(
          profile: profileFor(cfg),
          credentials: PasswordCredentials(cfg.s('password')),
          decideHostKey: (c) async {
            seen = c;
            storedWhenAsked = known.all.length;
            return HostKeyChoice.trustAndSave;
          },
        );
        expect(seen!.verdict, HostKeyVerdict.newHost);
        expect(seen!.type, 'ssh-ed25519');
        expect(seen!.fingerprint, cfg.s('fpEd25519'));
        expect(seen!.fingerprint, startsWith('SHA256:'));
        expect(storedWhenAsked, 0);
        // Ada di disk (instans baru), padahal login baru saja selesai.
        final reloaded = JsonKnownHostsRepository(File('${dir.path}${Platform.pathSeparator}known_hosts.json'));
        await reloaded.load();
        expect(reloaded.entriesFor(cfg.s('host'), cfg.port).single.fingerprint, cfg.s('fpEd25519'));
        conn.close();
      },
    );

    test('sambungan kedua ke host yang sama tidak bertanya lagi', () async {
      (await connector.connect(
        profile: profileFor(cfg),
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: trust,
      )).close();
      var asked = 0;
      final conn = await connector.connect(
        profile: profileFor(cfg),
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: (c) async {
          asked++;
          return HostKeyChoice.reject;
        },
      );
      expect(asked, 0);
      conn.close();
    });

    test('ditolak: SshHostKeyRejected(changed: false), tidak ada yang disimpan', () async {
      await expectLater(
        connector.connect(
          profile: profileFor(cfg),
          credentials: PasswordCredentials(cfg.s('password')),
          decideHostKey: reject,
        ),
        throwsA(isA<SshHostKeyRejected>().having((e) => e.changed, 'changed', isFalse)),
      );
      expect(known.all, isEmpty);
    });

    test('sambung sekali saja: berhasil tetapi tidak disimpan', () async {
      final conn = await connector.connect(
        profile: profileFor(cfg),
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: (c) async => HostKeyChoice.connectOnce,
      );
      expect(known.all, isEmpty);
      conn.close();
    });

    test('host key berubah: login diblokir dan sidik jari lama tidak diganti', () async {
      // Server di port alternatif memakai host key lain; anggap alamat itu pernah kita percayai dengan kunci lama.
      await known.add(
        KnownHost(host: cfg.s('host'), port: cfg.portAlt, type: 'ssh-ed25519', fingerprint: cfg.s('fpEd25519')),
      );
      HostKeyChallenge? seen;
      await expectLater(
        connector.connect(
          profile: profileFor(cfg, port: cfg.portAlt),
          credentials: PasswordCredentials(cfg.s('password')),
          decideHostKey: (c) async {
            seen = c;
            return HostKeyChoice.reject;
          },
        ),
        throwsA(isA<SshHostKeyRejected>().having((e) => e.changed, 'changed', isTrue)),
      );
      expect(seen!.verdict, HostKeyVerdict.changed);
      expect(seen!.fingerprint, cfg.s('fpAltEd25519'));
      expect(seen!.storedFingerprints, [cfg.s('fpEd25519')]);
      expect(known.entriesFor(cfg.s('host'), cfg.portAlt).single.fingerprint, cfg.s('fpEd25519'));
    });

    test('host key berubah: pilihan "sambung sekali saja" tidak diizinkan (tetap diblokir)', () async {
      await known.add(
        KnownHost(host: cfg.s('host'), port: cfg.portAlt, type: 'ssh-ed25519', fingerprint: cfg.s('fpEd25519')),
      );
      await expectLater(
        connector.connect(
          profile: profileFor(cfg, port: cfg.portAlt),
          credentials: PasswordCredentials(cfg.s('password')),
          decideHostKey: (c) async => HostKeyChoice.connectOnce,
        ),
        throwsA(isA<SshHostKeyRejected>().having((e) => e.changed, 'changed', isTrue)),
      );
    });

    test('host key berubah: "ganti dan sambung" mengganti sidik jari tersimpan', () async {
      await known.add(
        KnownHost(host: cfg.s('host'), port: cfg.portAlt, type: 'ssh-ed25519', fingerprint: cfg.s('fpEd25519')),
      );
      final conn = await connector.connect(
        profile: profileFor(cfg, port: cfg.portAlt),
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: (c) async => HostKeyChoice.replaceAndTrust,
      );
      expect(known.entriesFor(cfg.s('host'), cfg.portAlt).single.fingerprint, cfg.s('fpAltEd25519'));
      expect(await run(conn, 'echo ok'), 'ok');
      conn.close();
    });

    test('sidik jari tidak bisa disimpan: koneksi dibatalkan (SshHostKeyStoreFailure)', () async {
      final failing = JsonKnownHostsRepository(
        File('${dir.path}${Platform.pathSeparator}x.json'),
        writer: (f, b) async => throw FileSystemException('disk penuh'),
      );
      final c = SshConnector(knownHosts: failing);
      await expectLater(
        c.connect(profile: profileFor(cfg), credentials: PasswordCredentials(cfg.s('password')), decideHostKey: trust),
        throwsA(isA<SshHostKeyStoreFailure>()),
      );
    });

    test('host yang sudah dikenal dibatasi ke tipe tersimpan (negosiasi tidak menyodorkan tipe lain)', () async {
      // Simpan sidik jari RSA server; sambungan harus memakai RSA dan dianggap dipercaya.
      await known.add(KnownHost(host: cfg.s('host'), port: cfg.port, type: 'ssh-rsa', fingerprint: cfg.s('fpRsa')));
      var asked = 0;
      final conn = await connector.connect(
        profile: profileFor(cfg),
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: (c) async {
          asked++;
          return HostKeyChoice.reject;
        },
      );
      expect(asked, 0);
      conn.close();
    });
  });

  group('jaringan', () {
    test('port tertutup: SshNetworkFailure', () async {
      final p = HostProfile(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'uji',
        host: cfg.s('host'),
        port: 1,
        username: 'x',
      );
      await expectLater(
        connector.connect(profile: p, credentials: const PasswordCredentials('x'), decideHostKey: trust),
        throwsA(isA<SshNetworkFailure>()),
      );
    });

    test('pemeriksaan hidup: hidup lalu mati setelah ditutup', () async {
      final conn = await connector.connect(
        profile: profileFor(cfg),
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: trust,
      );
      expect(await conn.checkAlive(), isTrue);
      conn.close();
      await conn.closed;
      expect(await conn.checkAlive(), isFalse);
    });
  });

  group('keepalive', () {
    test('proxy yang berhenti meneruskan data tanpa menutup soket terdeteksi mati dalam beberapa detik', () async {
      // Proxy TCP lokal ke server uji yang bisa "membisu" (meniru sinyal hilang tanpa FIN).
      final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      var mute = false;
      final sockets = <Socket>[];
      proxy.listen((client) async {
        final server = await Socket.connect(cfg.s('host'), cfg.port);
        sockets
          ..add(client)
          ..add(server);
        client.listen((d) {
          if (!mute) server.add(d);
        }, onError: (_) {});
        server.listen((d) {
          if (!mute) client.add(d);
        }, onError: (_) {});
      });
      final fast = SshConnector(
        knownHosts: known,
        keepAliveInterval: const Duration(seconds: 1),
        keepAliveTimeout: const Duration(seconds: 2),
      );
      final p = HostProfile(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'uji',
        host: '127.0.0.1',
        port: proxy.port,
        username: cfg.s('user'),
      );
      final conn = await fast.connect(
        profile: p,
        credentials: PasswordCredentials(cfg.s('password')),
        decideHostKey: trust,
      );
      expect(await run(conn, 'echo hidup'), 'hidup');
      mute = true;
      final reason = await conn.closed.timeout(const Duration(seconds: 15));
      expect(reason, CloseReason.keepAliveTimeout);
      for (final s in sockets) {
        s.destroy();
      }
      await proxy.close();
    });
  });
}
