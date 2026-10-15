import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/io/atomic_file.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';
import 'package:termul_mobile/core/models/known_host.dart';
import 'package:termul_mobile/core/storage/json/json_known_hosts_repository.dart';

const fpA = 'SHA256:c2FtcGxlLWZpbmdlcnByaW50LW5vdC1yZWFs';
const fpB = 'SHA256:bmV3LXNhbXBsZS1maW5nZXJwcmludC1ub3QtcmVhbA';

KnownHost k(
  String type,
  String fp, {
  String host = 'host.contoh',
  int port = 22,
}) => KnownHost(
  host: host,
  port: port,
  type: type,
  fingerprint: fp,
  addedAt: DateTime.utc(2026, 10, 15),
);

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_known_');
    file = File('${dir.path}${Platform.pathSeparator}known_hosts.json');
  });
  tearDown(() async => dir.delete(recursive: true));

  JsonKnownHostsRepository repo({AtomicWriter? writer}) => writer == null
      ? JsonKnownHostsRepository(file)
      : JsonKnownHostsRepository(file, writer: writer);

  test(
    'add menulis ke disk sebelum selesai dan bertahan antar instans',
    () async {
      final a = repo();
      await a.load();
      await a.add(k('ssh-ed25519', fpA));
      expect(await file.exists(), isTrue); // sudah ada di disk saat add selesai
      final b = repo();
      await b.load();
      expect(b.entriesFor('HOST.contoh', 22), [k('ssh-ed25519', fpA)]);
    },
  );

  test('format berkas: version dan hosts', () async {
    final r = repo();
    await r.load();
    await r.add(k('ssh-ed25519', fpA));
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    expect(json['version'], 1);
    expect(
      (json['hosts']! as List<Object?>).single,
      containsPair('fingerprint', fpA),
    );
  });

  test('add identik tidak menggandakan; sidik jari beda untuk tipe sama menolak (harus lewat replace)', () async {
    final r = repo();
    await r.load();
    await r.add(k('ssh-ed25519', fpA));
    await r.add(k('ssh-ed25519', fpA));
    expect(r.all, hasLength(1));
    await expectLater(r.add(k('ssh-ed25519', fpB)), throwsStateError);
    expect(r.all.single.fingerprint, fpA);
  });

  test('tipe berbeda untuk host yang sama boleh ditambah', () async {
    final r = repo();
    await r.load();
    await r.add(k('ssh-ed25519', fpA));
    await r.add(k('ssh-rsa', fpB));
    expect(r.entriesFor('host.contoh', 22), hasLength(2));
  });

  test('replace mengganti hanya tipe yang sama untuk host:port itu', () async {
    final r = repo();
    await r.load();
    await r.add(k('ssh-ed25519', fpA));
    await r.add(k('ssh-rsa', fpA));
    await r.add(k('ssh-ed25519', fpA, port: 2211));
    await r.replace(k('ssh-ed25519', fpB));
    expect(
      r.entriesFor('host.contoh', 22).map((e) => (e.type, e.fingerprint)),
      [('ssh-rsa', fpA), ('ssh-ed25519', fpB)],
    );
    expect(r.entriesFor('host.contoh', 2211).single.fingerprint, fpA);
  });

  test('port berbeda dihitung host berbeda; removeFor hanya menghapus host:port itu', () async {
    final r = repo();
    await r.load();
    await r.add(k('ssh-ed25519', fpA));
    await r.add(k('ssh-ed25519', fpB, port: 2211));
    expect(await r.removeFor('Host.Contoh', 22), 1);
    expect(await r.removeFor('host.contoh', 22), 0);
    expect(r.all.single.port, 2211);
  });

  test(
    'penulisan gagal: StorageException dan entri tidak tercatat di memori',
    () async {
      final r = repo(
        writer: (f, b) async => throw const StorageException('disk penuh'),
      );
      await r.load();
      await expectLater(
        r.add(k('ssh-ed25519', fpA)),
        throwsA(isA<StorageException>()),
      );
      expect(r.all, isEmpty);
    },
  );

  test(
    'berkas rusak: dikarantina, dilaporkan, dan semua host kembali baru',
    () async {
      await file.writeAsString(
        '{"version": 1, "hosts": [{"host": "h", "port": 22, "type": "t", "fingerprint": "MD5:salah"}]}',
      );
      final r = repo();
      final result = await r.load();
      expect(result.hadCorruptFile, isTrue);
      expect(r.all, isEmpty);
      expect(await File(result.quarantinedPath!).exists(), isTrue);
    },
  );

  test('properti tak dikenal diabaikan', () async {
    await file.writeAsString(
      jsonEncode({
        'version': 2,
        'masa_depan': true,
        'hosts': [k('ssh-ed25519', fpA).toJson()],
      }),
    );
    final r = repo();
    expect((await r.load()).hadCorruptFile, isFalse);
    expect(r.all, hasLength(1));
  });

  test('keputusan end-to-end: host baru, dipercaya, lalu berubah', () async {
    final r = repo();
    await r.load();
    expect(
      evaluateHostKey(
        r.entriesFor('h', 22),
        type: 'ssh-ed25519',
        fingerprint: fpA,
      ),
      HostKeyVerdict.newHost,
    );
    await r.add(
      KnownHost(host: 'h', port: 22, type: 'ssh-ed25519', fingerprint: fpA),
    );
    expect(
      evaluateHostKey(
        r.entriesFor('h', 22),
        type: 'ssh-ed25519',
        fingerprint: fpA,
      ),
      HostKeyVerdict.trusted,
    );
    expect(
      evaluateHostKey(
        r.entriesFor('h', 22),
        type: 'ssh-ed25519',
        fingerprint: fpB,
      ),
      HostKeyVerdict.changed,
    );
  });
}
