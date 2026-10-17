import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/sftp/sftp_service.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/storage/json/json_known_hosts_repository.dart';

/// Server SSH sungguhan: `--dart-define=SSH_TEST_CONFIG=<config.json>` (sama dengan `ssh_connector_test.dart`).
/// Tanpa itu, bagian server dilewati. Kredensial tidak dicetak dan tidak ada di repo.
const configPath = String.fromEnvironment('SSH_TEST_CONFIG');

void main() {
  group('jalur jarak jauh', () {
    test('joinRemote', () {
      expect(joinRemote('/home/u', 'a.txt'), '/home/u/a.txt');
      expect(joinRemote('/', 'etc'), '/etc');
      expect(joinRemote('/home/u/', 'a'), '/home/u/a');
      expect(joinRemote('', 'a'), 'a');
    });

    test('parentRemote', () {
      expect(parentRemote('/home/u/a'), '/home/u');
      expect(parentRemote('/home/u/'), '/home');
      expect(parentRemote('/home'), '/');
      expect(parentRemote('/'), '/');
      expect(parentRemote('rel'), '.');
    });

    test('compareEntries: folder dulu, lalu nama tanpa membedakan huruf besar kecil', () {
      SftpEntry e(String n, SftpEntryKind k) => SftpEntry(name: n, path: '/$n', kind: k);
      final list = [
        e('b.txt', SftpEntryKind.file),
        e('Zeta', SftpEntryKind.directory),
        e('A.txt', SftpEntryKind.file),
        e('alpha', SftpEntryKind.directory),
      ]..sort(compareEntries);
      expect([for (final x in list) x.name], ['alpha', 'Zeta', 'A.txt', 'b.txt']);
    });
  });

  final cfgFile = configPath.isEmpty ? null : File(configPath);
  if (cfgFile == null || !cfgFile.existsSync()) {
    test('SFTP sungguhan', () {}, skip: 'SSH_TEST_CONFIG tidak diisi');
    return;
  }
  final cfg = jsonDecode(cfgFile.readAsStringSync()) as Map<String, Object?>;

  group('server sungguhan', () {
    late Directory tmp;
    late SshConnection conn;
    late SftpService sftp;
    late String base;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('termul_sftp_');
      final known = JsonKnownHostsRepository(File('${tmp.path}${Platform.pathSeparator}known_hosts.json'));
      await known.load();
      conn = await SshConnector(knownHosts: known).connect(
        profile: HostProfile(
          id: '11111111-1111-4111-8111-111111111111',
          name: 'uji',
          host: cfg['host']! as String,
          port: cfg['port']! as int,
          username: cfg['user']! as String,
        ),
        credentials: PasswordCredentials(cfg['password']! as String),
        decideHostKey: (_) async => HostKeyChoice.trustAndSave,
      );
      sftp = SftpService(await conn.client.sftp());
      base = joinRemote(await sftp.home(), 'termul_sftp_uji_${DateTime.now().microsecondsSinceEpoch}');
      await sftp.mkdir(base);
    });

    tearDown(() async {
      try {
        await sftp.deleteTree(base);
      } on Object {
        // pembersihan terbaik-usaha
      }
      sftp.close();
      conn.close();
      await tmp.delete(recursive: true);
    });

    Stream<Uint8List> bytes(int n, {int chunk = 32 * 1024}) async* {
      var left = n;
      while (left > 0) {
        final c = left < chunk ? left : chunk;
        yield Uint8List.fromList(List.filled(c, 0x41));
        left -= c;
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('unggah, daftar, unduh, ganti nama, hapus', () async {
      final path = joinRemote(base, 'a.bin');
      var last = 0;
      await sftp.upload(path, bytes(300 * 1024), onProgress: (b) => last = b);
      expect(last, 300 * 1024);

      await sftp.mkdir(joinRemote(base, 'sub'));
      final list = await sftp.list(base);
      expect([for (final e in list) e.name], ['sub', 'a.bin']);
      expect(list.first.isDirectory, isTrue);
      expect(list.last.size, 300 * 1024);

      final out = File('${tmp.path}${Platform.pathSeparator}a.bin');
      final sink = out.openWrite();
      final got = await sftp.download(path, sink);
      await sink.close();
      expect(got, 300 * 1024);
      expect(out.lengthSync(), 300 * 1024);

      await sftp.rename(path, joinRemote(base, 'b.bin'));
      expect([for (final e in await sftp.list(base)) e.name], ['sub', 'b.bin']);
      await sftp.deleteFile(joinRemote(base, 'b.bin'));
      expect([for (final e in await sftp.list(base)) e.name], ['sub']);
    });

    test('berkas tidak ada dan izin ditolak dipetakan', () async {
      await expectLater(
        sftp.list(joinRemote(base, 'tidak-ada')),
        throwsA(isA<SftpFailure>().having((f) => f.kind, 'kind', SftpFailureKind.notFound)),
      );
      await expectLater(
        sftp.upload('/proc/termul_tidak_boleh', bytes(10)),
        throwsA(isA<SftpFailure>().having((f) => f.kind, 'kind', isNot(SftpFailureKind.cancelled))),
      );
    });

    test('batal unggah: melempar cancelled dan berkas parsial dihapus', () async {
      final path = joinRemote(base, 'besar.bin');
      final token = SftpCancelToken();
      await expectLater(
        sftp.upload(
          path,
          bytes(20 * 1024 * 1024),
          onProgress: (b) {
            if (b > 512 * 1024) token.cancel();
          },
          cancel: token,
        ),
        throwsA(isA<SftpFailure>().having((f) => f.kind, 'kind', SftpFailureKind.cancelled)),
      );
      expect([for (final e in await sftp.list(base)) e.name], isNot(contains('besar.bin')));
    });

    test('batal unduh: melempar cancelled', () async {
      final path = joinRemote(base, 'd.bin');
      await sftp.upload(path, bytes(8 * 1024 * 1024));
      final token = SftpCancelToken();
      final sink = File('${tmp.path}${Platform.pathSeparator}d.bin').openWrite();
      await expectLater(
        sftp.download(
          path,
          sink,
          onProgress: (b) {
            if (b > 256 * 1024) token.cancel();
          },
          cancel: token,
        ),
        throwsA(isA<SftpFailure>().having((f) => f.kind, 'kind', SftpFailureKind.cancelled)),
      );
      try {
        await sink.close();
      } on Object {
        // sink bisa sudah rusak setelah pembatalan; pemanggil nyata menghapus berkas parsial lokalnya
      }
    });

    test('deleteTree menghapus folder berisi', () async {
      final d = joinRemote(base, 'pohon');
      await sftp.mkdir(d);
      await sftp.mkdir(joinRemote(d, 'dalam'));
      await sftp.upload(joinRemote(d, 'dalam/x.txt'), bytes(100));
      await sftp.deleteTree(d);
      expect([for (final e in await sftp.list(base)) e.name], isNot(contains('pohon')));
    });
  });
}
