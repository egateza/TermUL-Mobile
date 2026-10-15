import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:termul_mobile/core/io/atomic_file.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/known_host.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';
import 'package:termul_mobile/core/storage/json/json_known_hosts_repository.dart';

/// Memeriksa lapisan penyimpanan di sistem berkas Android sungguhan (folder pribadi aplikasi).
/// Jalankan: `flutter test integration_test -d <perangkat>`.
/// Tidak menguji mati daya atau proses dimatikan paksa.
String uid(int n) => '${n.toString().padLeft(8, '0')}-0000-4000-8000-000000000000';

HostProfile p(int n) => HostProfile(id: uid(n), name: 'host-$n', host: 'h$n', username: 'u');

const fp = 'SHA256:c2FtcGxlLWZpbmdlcnByaW50LW5vdC1yZWFs';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    final base = await getApplicationSupportDirectory();
    dir = await Directory('${base.path}${Platform.pathSeparator}uji_${DateTime.now().microsecondsSinceEpoch}')
        .create(recursive: true);
  });
  tearDown(() async => dir.delete(recursive: true));

  File file(String n) => File('${dir.path}${Platform.pathSeparator}$n');

  testWidgets('folder pribadi aplikasi ada dan bisa ditulis', (tester) async {
    final base = await getApplicationSupportDirectory();
    expect(base.path, contains('io.github.egateza.termul'));
    expect(await dir.exists(), isTrue);
  });

  testWidgets('tulis atomik: berkas baru, timpa, dan tidak ada sisa sementara', (tester) async {
    final f = file('x.json');
    await writeAtomic(f, utf8.encode('{"a":1}'));
    await writeAtomic(f, utf8.encode('{"a":22}'));
    expect(await f.readAsString(), '{"a":22}');
    expect(dir.listSync().map((e) => e.path.split(Platform.pathSeparator).last), ['x.json']);
  });

  testWidgets('galat sebelum rename: berkas lama utuh', (tester) async {
    final f = file('x.json');
    await writeAtomic(f, utf8.encode('lama'));
    await expectLater(
      writeAtomic(f, utf8.encode('baru'), beforeRename: () async => throw StateError('x')),
      throwsStateError,
    );
    expect(await f.readAsString(), 'lama');
    expect(dir.listSync(), hasLength(1));
  });

  testWidgets('HostRepository: simpan, muat ulang, 50 simpanan serentak', (tester) async {
    final a = JsonHostRepository(file('profiles.json'));
    await a.load();
    await Future.wait([for (var i = 1; i <= 50; i++) a.save(p(i))]);
    await a.setFavorite(uid(3), favorite: true);
    await a.markUsed(uid(4));
    final b = JsonHostRepository(file('profiles.json'));
    final result = await b.load();
    expect(result.hadCorruptFile, isFalse);
    expect(b.snapshot.profiles, hasLength(50));
    expect(b.snapshot.favorites, [uid(3)]);
    expect(b.snapshot.recent, [uid(4)]);
  });

  testWidgets('berkas rusak dikarantina dan simpan berikutnya tidak menimpanya', (tester) async {
    await file('profiles.json').writeAsString('{rusak');
    final r = JsonHostRepository(file('profiles.json'));
    final result = await r.load();
    expect(result.hadCorruptFile, isTrue);
    await r.save(p(1));
    expect(await File(result.quarantinedPath!).readAsString(), '{rusak');
    final again = JsonHostRepository(file('profiles.json'));
    await again.load();
    expect(again.snapshot.profiles, hasLength(1));
  });

  testWidgets('penulisan gagal tidak mengubah snapshot', (tester) async {
    var fail = false;
    final r = JsonHostRepository(
      file('profiles.json'),
      writer: (f, b) async {
        if (fail) throw const StorageException('uji');
        await writeAtomic(f, b);
      },
    );
    await r.load();
    await r.save(p(1));
    fail = true;
    await expectLater(r.save(p(2)), throwsA(isA<StorageException>()));
    expect(r.snapshot.profiles, hasLength(1));
  });

  testWidgets('KnownHosts: add selesai berarti sudah di disk; replace dan removeFor', (tester) async {
    final a = JsonKnownHostsRepository(file('known_hosts.json'));
    await a.load();
    await a.add(KnownHost(host: 'Server.Uji', port: 22, type: 'ssh-ed25519', fingerprint: fp));
    final b = JsonKnownHostsRepository(file('known_hosts.json'));
    await b.load();
    expect(b.entriesFor('server.uji', 22), hasLength(1));
    expect(await b.removeFor('server.uji', 22), 1);
    final c = JsonKnownHostsRepository(file('known_hosts.json'));
    await c.load();
    expect(c.all, isEmpty);
  });
}
