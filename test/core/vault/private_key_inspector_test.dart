import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/keys/private_key_inspector.dart';

/// Kunci uji dibuat saat tes berjalan dengan `ssh-keygen` ke folder sementara dan dihapus sesudahnya;
/// tidak ada kunci privat di repo (CLAUDE.md). Tanpa `ssh-keygen`, tes ini dilewati.
const passphrase = 'frasa-uji-bukan-kredensial';

Future<bool> hasKeygen() async {
  try {
    final r = await Process.run('ssh-keygen', ['-?']);
    return r.exitCode != 255 || r.stderr.toString().contains('usage');
  } on ProcessException {
    return false;
  }
}

Future<Uint8List> generate(Directory dir, String name, List<String> args, {String pass = ''}) async {
  final path = '${dir.path}${Platform.pathSeparator}$name';
  final r = await Process.run('ssh-keygen', [...args, '-N', pass, '-q', '-C', 'uji', '-f', path]);
  if (r.exitCode != 0) fail('ssh-keygen gagal: ${r.stderr}');
  return File(path).readAsBytes();
}

void main() {
  late Directory dir;
  late bool keygen;

  setUpAll(() async => keygen = await hasKeygen());
  setUp(() async => dir = await Directory.systemTemp.createTemp('termul_keys_'));
  tearDown(() async => dir.delete(recursive: true));

  void keyTest(String name, Future<void> Function() body) {
    test(name, () async {
      if (!keygen) {
        markTestSkipped('ssh-keygen tidak tersedia');
        return;
      }
      await body();
    });
  }

  group('format yang didukung (terbukti di spike)', () {
    keyTest('ed25519 OpenSSH tanpa passphrase', () async {
      final k = PrivateKeyInspector.inspect(await generate(dir, 'a', ['-t', 'ed25519']));
      expect((k.type, k.encrypted), ('OPENSSH PRIVATE KEY', false));
      PrivateKeyInspector.verifyPassphrase(k.pem, null);
      PrivateKeyInspector.verifyPassphrase(k.pem, '');
    });

    keyTest('ed25519 OpenSSH dengan passphrase: benar lolos, salah atau kosong ditolak', () async {
      final k = PrivateKeyInspector.inspect(await generate(dir, 'b', ['-t', 'ed25519'], pass: passphrase));
      expect(k.encrypted, isTrue);
      PrivateKeyInspector.verifyPassphrase(k.pem, passphrase);
      for (final wrong in ['salah', '', null]) {
        expect(
          () => PrivateKeyInspector.verifyPassphrase(k.pem, wrong),
          throwsA(isA<KeyImportException>().having((e) => e.problem, 'problem', KeyProblem.wrongPassphrase)),
          reason: 'passphrase $wrong',
        );
      }
    });

    keyTest('RSA PKCS#1 (-m PEM)', () async {
      final k = PrivateKeyInspector.inspect(await generate(dir, 'c', ['-t', 'rsa', '-b', '2048', '-m', 'PEM']));
      expect((k.type, k.encrypted), ('RSA PRIVATE KEY', false));
      PrivateKeyInspector.verifyPassphrase(k.pem, null);
    });

    keyTest('ECDSA P-256 SEC1 (-m PEM)', () async {
      final k = PrivateKeyInspector.inspect(await generate(dir, 'd', ['-t', 'ecdsa', '-b', '256', '-m', 'PEM']));
      expect((k.type, k.encrypted), ('EC PRIVATE KEY', false));
      PrivateKeyInspector.verifyPassphrase(k.pem, null);
    });
  });

  group('format yang ditolak dengan pesan khusus', () {
    keyTest('PKCS#8 ditandai jelas, tanpa memuat isi kunci', () async {
      final bytes = await generate(dir, 'e', ['-t', 'rsa', '-b', '2048', '-m', 'PKCS8']);
      try {
        PrivateKeyInspector.inspect(bytes);
        fail('seharusnya ditolak');
      } on KeyImportException catch (e) {
        expect(e.problem, KeyProblem.pkcs8Unsupported);
        expect(e.toString(), isNot(contains('MII')));
      }
    });

    test('bukan PEM, bukan teks, kosong, dan terlalu besar', () {
      expect(
        () => PrivateKeyInspector.inspect(Uint8List.fromList(utf8.encode('halo dunia'))),
        throwsA(isA<KeyImportException>().having((e) => e.problem, 'problem', KeyProblem.notPem)),
      );
      expect(
        () => PrivateKeyInspector.inspect(Uint8List.fromList([0xff, 0xfe, 0x00])),
        throwsA(isA<KeyImportException>().having((e) => e.problem, 'problem', KeyProblem.notAKey)),
      );
      expect(
        () => PrivateKeyInspector.inspect(Uint8List(0)),
        throwsA(isA<KeyImportException>().having((e) => e.problem, 'problem', KeyProblem.notAKey)),
      );
      expect(
        () => PrivateKeyInspector.inspect(Uint8List(PrivateKeyInspector.maxBytes + 1)),
        throwsA(isA<KeyImportException>().having((e) => e.problem, 'problem', KeyProblem.notAKey)),
      );
    });

    test('jenis PEM lain dan PEM rusak', () {
      Uint8List pem(String type, String body) =>
          Uint8List.fromList(utf8.encode('-----BEGIN $type-----\n$body\n-----END $type-----\n'));
      expect(
        () => PrivateKeyInspector.inspect(pem('PUBLIC KEY', 'AAAA')),
        throwsA(isA<KeyImportException>().having((e) => e.problem, 'problem', KeyProblem.unsupportedType)),
      );
      expect(
        () => PrivateKeyInspector.inspect(pem('RSA PRIVATE KEY', 'bukan-base64-valid!!')),
        throwsA(isA<KeyImportException>().having((e) => e.problem, 'problem', KeyProblem.malformed)),
      );
    });

    test('pesan galat tidak memuat isi berkas', () {
      const secretBody = 'RAHASIA-SANGAT-PENTING';
      try {
        PrivateKeyInspector.inspect(
          Uint8List.fromList(
            utf8.encode('-----BEGIN RSA PRIVATE KEY-----\n$secretBody\n-----END RSA PRIVATE KEY-----\n'),
          ),
        );
      } on KeyImportException catch (e) {
        expect(e.toString(), isNot(contains(secretBody)));
      }
    });
  });
}
