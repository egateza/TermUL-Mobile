import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/keys/private_key_inspector.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';

import 'hosts_ui_harness.dart';

/// Kunci uji dibuat dengan ssh-keygen saat tes berjalan (tidak ada kunci privat di repo).
late Uint8List plainKey;
late Uint8List protectedKey;
late Uint8List pkcs8Key;
bool keygen = false;
const frasa = 'frasa-uji-bukan-kredensial';

/// Layar tinggi supaya semua bidang form terbangun (ListView membangun hanya yang terlihat).
const tall = Size(390, 1800);

Future<Uint8List> generate(Directory dir, String name, List<String> args, {String pass = ''}) async {
  final path = '${dir.path}${Platform.pathSeparator}$name';
  final r = await Process.run('ssh-keygen', [...args, '-N', pass, '-q', '-C', 'uji', '-f', path]);
  if (r.exitCode != 0) throw StateError('ssh-keygen gagal: ${r.stderr}');
  return File(path).readAsBytes();
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.text('Tambah host'));
  await tester.pumpAndSettle();
}

Future<void> fillBasics(
  WidgetTester tester, {
  String name = 'app-01',
  String host = '192.0.2.11',
  String user = 'deploy',
}) async {
  await tester.enterText(inputByLabel('Nama'), name);
  await tester.enterText(inputByLabel('Host'), host);
  await tester.enterText(inputByLabel('User'), user);
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Simpan'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    try {
      final r = await Process.run('ssh-keygen', ['-?']);
      keygen = r.exitCode != 127;
    } on ProcessException {
      keygen = false;
    }
    if (!keygen) return;
    final dir = await Directory.systemTemp.createTemp('termul_formkeys_');
    plainKey = await generate(dir, 'plain', ['-t', 'ed25519']);
    protectedKey = await generate(dir, 'prot', ['-t', 'ed25519'], pass: frasa);
    pkcs8Key = await generate(dir, 'p8', ['-t', 'rsa', '-b', '2048', '-m', 'PKCS8']);
    await dir.delete(recursive: true);
  });

  void keyTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      if (!keygen) {
        markTestSkipped('ssh-keygen tidak tersedia');
        return;
      }
      await body(tester);
    });
  }

  group('validasi', () {
    testWidgets('semua kolom wajib kosong: setiap galat tampil dan tidak ada yang tersimpan', (tester) async {
      final h = Harness();
      await h.pump(tester, size: tall);
      await openForm(tester);
      await tester.enterText(inputByLabel('Port'), '');
      await save(tester);
      expect(find.text('Nama wajib diisi'), findsOneWidget);
      expect(find.text('Host wajib diisi'), findsOneWidget);
      expect(find.text('User wajib diisi'), findsOneWidget);
      expect(find.text('Port harus 1 sampai 65535'), findsOneWidget);
      expect(find.text('Password wajib diisi'), findsOneWidget);
      expect(h.hosts.snapshot.profiles, isEmpty);
    });

    testWidgets('port di luar 1..65535 ditolak', (tester) async {
      final h = Harness();
      await h.pump(tester, size: tall);
      await openForm(tester);
      await fillBasics(tester);
      await tester.enterText(inputByLabel('Password'), 'pw');
      for (final bad in ['0', '65536', 'abc']) {
        await tester.enterText(inputByLabel('Port'), bad);
        await save(tester);
        expect(find.text('Port harus 1 sampai 65535'), findsOneWidget, reason: bad);
      }
      expect(h.hosts.snapshot.profiles, isEmpty);
    });
  });

  group('tambah host dengan password', () {
    testWidgets('tersimpan: muncul di daftar, rahasia di vault, tidak di profil', (tester) async {
      final h = Harness();
      await h.pump(tester, size: tall);
      await openForm(tester);
      await fillBasics(tester);
      await tester.enterText(inputByLabel('Grup (opsional)'), ' Produksi / Backend ');
      await tester.enterText(inputByLabel('Password'), 'pw-uji-bukan-kredensial');
      await save(tester);
      expect(find.text('Host baru'), findsNothing); // kembali ke daftar
      final p = h.hosts.snapshot.profiles.single;
      expect(
        (p.name, p.host, p.port, p.username, p.group, p.authMethod),
        ('app-01', '192.0.2.11', 22, 'deploy', 'Produksi/Backend', AuthMethod.password),
      );
      expect(jsonEncode(p.toJson()), isNot(contains('pw-uji-bukan-kredensial')));
      expect(await h.vault.has(p.id, SecretType.loginPassword), isTrue);
      expect(find.text('PRODUKSI/BACKEND'), findsOneWidget);
      expect(find.widgetWithText(HostRow, 'app-01'), findsOneWidget);
    });

    testWidgets('kolom password tersamarkan', (tester) async {
      final h = Harness();
      await h.pump(tester, size: tall);
      await openForm(tester);
      final field = tester.widget<TextField>(inputByLabel('Password'));
      expect(field.obscureText, isTrue);
    });

    testWidgets('penyimpanan gagal: banner galat, formulir tetap terbuka, dan tidak ada baris', (tester) async {
      final h = Harness();
      h.store.failWrites = true;
      await h.pump(tester, size: tall);
      await openForm(tester);
      await fillBasics(tester);
      await tester.enterText(inputByLabel('Password'), 'pw');
      await save(tester);
      expect(find.text('Belum tersimpan. Penyimpanan perangkat bermasalah; coba lagi.'), findsOneWidget);
      expect(find.text('Host baru'), findsOneWidget);
      expect(h.hosts.snapshot.profiles, isEmpty);
      h.store.failWrites = false;
      await save(tester); // bisa dicoba lagi
      expect(h.hosts.snapshot.profiles, hasLength(1));
    });
  });

  group('peringatan penguncian layar', () {
    testWidgets('HP tanpa kunci layar: peringatan tampil tetapi menyimpan tetap berhasil', (tester) async {
      final h = Harness(level: AuthLevel.none);
      await h.pump(tester, size: tall);
      await openForm(tester);
      expect(find.text('HP ini tidak punya kunci layar'), findsOneWidget);
      await fillBasics(tester);
      await tester.enterText(inputByLabel('Password'), 'pw');
      await save(tester);
      expect(h.hosts.snapshot.profiles, hasLength(1));
      expect(await h.vault.has(h.hosts.snapshot.profiles.single.id, SecretType.loginPassword), isTrue);
    });

    for (final level in [AuthLevel.biometric, AuthLevel.deviceCredential]) {
      testWidgets('${level.name}: tidak ada peringatan', (tester) async {
        final h = Harness(level: level);
        await h.pump(tester, size: tall);
        await openForm(tester);
        expect(find.text('HP ini tidak punya kunci layar'), findsNothing);
      });
    }
  });

  group('ubah host', () {
    testWidgets('kolom terisi; password tersimpan dipertahankan bila dikosongkan', (tester) async {
      final h = Harness();
      await h.seed([host(id1, group: 'Produksi')]);
      await h.vault.put(id1, SecretType.loginPassword, 'pw-lama');
      await h.pump(tester, size: tall);
      await tester.longPress(find.widgetWithText(HostRow, 'app-01'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah host'), findsOneWidget);
      expect(tester.widget<TextField>(inputByLabel('Nama')).controller!.text, 'app-01');
      expect(tester.widget<TextField>(inputByLabel('Grup (opsional)')).controller!.text, 'Produksi');
      expect(find.text('Kosongkan untuk tetap memakai password yang tersimpan'), findsOneWidget);
      await tester.enterText(inputByLabel('Nama'), 'app-baru');
      await save(tester);
      expect(h.hosts.snapshot.find(id1)!.name, 'app-baru');
      expect(await h.vault.get(id1, SecretType.loginPassword, reason: 'uji'), 'pw-lama');
    });

    testWidgets('melengkapi profil agen: pilih password dan simpan', (tester) async {
      final h = Harness();
      await h.seed([host(id1, auth: AuthMethod.agent)]);
      await h.pump(tester, size: tall);
      await tester.tap(find.widgetWithText(HostRow, 'app-01'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lengkapi'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Password'), 'pw-baru');
      await save(tester);
      expect(h.hosts.snapshot.find(id1)!.authMethod, AuthMethod.password);
      expect(await h.vault.has(id1, SecretType.loginPassword), isTrue);
    });
  });

  group('kunci privat', () {
    keyTest('impor kunci tanpa passphrase: status siap, tersimpan di vault', (tester) async {
      final h = Harness();
      h.picker.next = plainKey;
      await h.pump(tester, size: tall);
      await openForm(tester);
      await fillBasics(tester);
      await tester.tap(find.text('Kunci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impor kunci dari berkas'));
      await tester.pumpAndSettle();
      expect(find.text('Kunci OpenSSH siap disimpan'), findsOneWidget);
      expect(find.text('Passphrase kunci'), findsNothing);
      await save(tester);
      final p = h.hosts.snapshot.profiles.single;
      expect(p.authMethod, AuthMethod.key);
      expect(p.privateKeyPath, isNull);
      expect(await h.vault.has(p.id, SecretType.privateKeyPem), isTrue);
      expect(jsonEncode(p.toJson()), isNot(contains('BEGIN')));
    });

    keyTest('kunci berpassphrase: kolom passphrase muncul; salah ditolak, benar tersimpan', (tester) async {
      final h = Harness();
      h.picker.next = protectedKey;
      await h.pump(tester, size: tall);
      await openForm(tester);
      await fillBasics(tester);
      await tester.tap(find.text('Kunci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impor kunci dari berkas'));
      await tester.pumpAndSettle();
      expect(find.text('Kunci ini dilindungi passphrase.'), findsOneWidget);
      await tester.enterText(inputByLabel('Passphrase kunci'), 'salah');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Passphrase salah atau kosong'), findsOneWidget);
      expect(h.hosts.snapshot.profiles, isEmpty);
      await tester.enterText(inputByLabel('Passphrase kunci'), frasa);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      final p = h.hosts.snapshot.profiles.single;
      expect(await h.vault.get(p.id, SecretType.keyPassphrase, reason: 'uji'), frasa);
      expect(await h.vault.has(p.id, SecretType.privateKeyPem), isTrue);
    });

    keyTest('PKCS#8 ditolak dengan pesan yang menyebut cara mengubahnya', (tester) async {
      final h = Harness();
      h.picker.next = pkcs8Key;
      await h.pump(tester, size: tall);
      await openForm(tester);
      await tester.tap(find.text('Kunci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impor kunci dari berkas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PKCS#8'), findsOneWidget);
      expect(find.textContaining('ssh-keygen -p -m PEM'), findsOneWidget);
      expect(find.textContaining('Kunci RSA siap'), findsNothing);
    });

    testWidgets('berkas bukan kunci dan berkas terlalu besar: pesan jelas', (tester) async {
      final h = Harness();
      h.picker.next = Uint8List.fromList(utf8.encode('halo dunia'));
      await h.pump(tester, size: tall);
      await openForm(tester);
      await tester.tap(find.text('Kunci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impor kunci dari berkas'));
      await tester.pumpAndSettle();
      expect(find.text('Berkas ini bukan kunci dalam format PEM.'), findsOneWidget);
      h.picker
        ..next = null
        ..error = const KeyImportException(KeyProblem.notAKey);
      await tester.tap(find.text('Impor kunci dari berkas'));
      await tester.pumpAndSettle();
      expect(find.text('Berkas ini bukan kunci privat (terlalu besar atau bukan teks).'), findsOneWidget);
    });

    testWidgets('simpan tanpa memilih kunci: galat "Pilih berkas kunci privat"', (tester) async {
      final h = Harness();
      await h.pump(tester, size: tall);
      await openForm(tester);
      await fillBasics(tester);
      await tester.tap(find.text('Kunci'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(find.text('Pilih berkas kunci privat'), findsOneWidget);
      expect(h.hosts.snapshot.profiles, isEmpty);
    });

    testWidgets('pemilih dibatalkan: tidak ada perubahan', (tester) async {
      final h = Harness();
      await h.pump(tester, size: tall);
      await openForm(tester);
      await tester.tap(find.text('Kunci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impor kunci dari berkas'));
      await tester.pumpAndSettle();
      expect(h.picker.calls, 1);
      expect(find.textContaining('siap disimpan'), findsNothing);
    });
  });
}
