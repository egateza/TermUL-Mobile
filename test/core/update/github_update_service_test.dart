import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/update/manifest.dart';
import 'package:termul_mobile/core/update/update_service.dart';

import 'test_keys.dart';

const _repo = 'egateza/TermUL-Mobile';

/// Server HTTP lokal yang meniru alamat unduhan GitHub Releases: `latest/download/manifest.json` dialihkan ke tag
/// terbaru, lalu `download/v<versi>/...`.
class _FakeGitHub {
  late HttpServer server;
  String version = '0.1.120';
  int code = 120;
  List<int> apk = List.generate(200 * 1024, (i) => i % 251);
  bool hasRelease = true;
  bool hasSignature = true;

  /// Mengganti isi manifest setelah ditandatangani (manifest palsu).
  List<int>? manifestOverride;

  /// Mengganti isi APK yang dilayani (manifest tetap menyebut APK asli).
  List<int>? apkOverride;
  int apkStatus = 200;

  /// Dipanggil sebelum mengirim tiap potongan APK (untuk membatalkan di tengah).
  void Function(int sent)? onApkChunk;

  Uri get base => Uri.parse('http://${server.address.host}:${server.port}');

  String get apkName => 'termul-mobile-$version.apk';

  List<int> get manifestBytes => UpdateManifest(
    version: version,
    versionCode: code,
    notes: '## Perbaikan\n- Sambung ulang lebih cepat',
    apk: ManifestFile(name: apkName, sha256: sha256.convert(apk).toString(), size: apk.length),
  ).encode();

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      final dl = '/$_repo/releases/download/v$version/';
      final path = req.uri.path;
      if (!hasRelease) {
        res.statusCode = 404;
      } else if (path == '/$_repo/releases/latest/download/manifest.json') {
        res.redirect(base.resolve('${dl}manifest.json'));
        return;
      } else if (path == '${dl}manifest.json') {
        res.add(manifestOverride ?? manifestBytes);
      } else if (path == '${dl}manifest.json.sig' && hasSignature) {
        res.write(signManifest(manifest: manifestBytes, seed: testSeed));
      } else if (path == '$dl$apkName') {
        final body = apkOverride ?? apk;
        res.statusCode = apkStatus;
        if (apkStatus == 200) {
          res.contentLength = body.length;
          for (var i = 0; i < body.length; i += 16 * 1024) {
            onApkChunk?.call(i);
            res.add(body.sublist(i, i + 16 * 1024 > body.length ? body.length : i + 16 * 1024));
            await res.flush();
          }
        }
      } else {
        res.statusCode = 404;
      }
      await res.close();
    });
  }
}

void main() {
  late _FakeGitHub gh;
  late Directory temp;
  late GitHubUpdateService service;

  setUp(() async {
    gh = _FakeGitHub();
    await gh.start();
    temp = await Directory.systemTemp.createTemp('termul_update_test');
    service = GitHubUpdateService(
      repo: _repo,
      tempDir: () async => temp,
      webBase: gh.base,
      publicKey: testPublicKey,
      timeout: const Duration(seconds: 5),
    );
  });

  tearDown(() async {
    await gh.server.close(force: true);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  List<FileSystemEntity> updateDir() {
    final d = Directory('${temp.path}${Platform.pathSeparator}update');
    return d.existsSync() ? d.listSync() : const [];
  }

  Matcher fails(UpdateFailure f) => throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', f));

  group('latest', () {
    test('manifest bertanda tangan sah: rilis dengan alamat per tag', () async {
      final r = await service.latest();
      expect(r!.version, '0.1.120');
      expect(r.versionCode, 120);
      expect(r.notes, contains('Sambung ulang'));
      expect(r.apk.url.path, '/$_repo/releases/download/v0.1.120/termul-mobile-0.1.120.apk');
      expect(r.apk.size, gh.apk.length);
    });

    test('belum ada rilis (404): null', () async {
      gh.hasRelease = false;
      expect(await service.latest(), isNull);
    });

    test('manifest diubah setelah ditandatangani: signature', () async {
      gh.manifestOverride = UpdateManifest(
        version: '0.1.120',
        versionCode: 120,
        notes: 'palsu',
        apk: ManifestFile(name: gh.apkName, sha256: 'b' * 64, size: 10),
      ).encode();
      await expectLater(service.latest(), fails(UpdateFailure.signature));
    });

    test('tanpa berkas .sig: signature', () async {
      gh.hasSignature = false;
      await expectLater(service.latest(), fails(UpdateFailure.signature));
    });

    test('kunci publik lain: signature', () async {
      final other = GitHubUpdateService(
        repo: _repo,
        tempDir: () async => temp,
        webBase: gh.base,
        publicKey: publicKeyOf(List<int>.generate(32, (i) => 99)),
      );
      await expectLater(other.latest(), fails(UpdateFailure.signature));
    });

    test('manifest rusak: badRelease', () async {
      gh.manifestOverride = [123, 1, 2];
      await expectLater(service.latest(), fails(UpdateFailure.badRelease));
    });

    test('server tidak terjangkau: network', () async {
      await gh.server.close(force: true);
      await expectLater(service.latest(), fails(UpdateFailure.network));
    });

    test('rilis versi tertentu untuk Yang baru', () async {
      expect((await service.release('0.1.120'))!.versionCode, 120);
      expect(await service.release('0.1.99'), isNull);
    });
  });

  group('download', () {
    test('cocok dengan manifest: berkas siap dengan kemajuan sampai 100%', () async {
      final release = (await service.latest())!;
      final progress = <int>[];
      final path = await service.download(release, onProgress: (r, t) => progress.add(r * 100 ~/ t));
      expect(await File(path).readAsBytes(), gh.apk);
      expect(progress.first, 0);
      expect(progress.last, 100);
      expect(updateDir(), hasLength(1));
    });

    test('isi APK berbeda dari manifest: checksum, berkas dihapus', () async {
      final release = (await service.latest())!;
      gh.apkOverride = List.generate(gh.apk.length, (i) => 7);
      await expectLater(service.download(release), fails(UpdateFailure.checksum));
      expect(updateDir(), isEmpty);
    });

    test('APK lebih besar dari manifest: checksum', () async {
      final release = (await service.latest())!;
      gh.apkOverride = [...gh.apk, 1, 2, 3];
      await expectLater(service.download(release), fails(UpdateFailure.checksum));
      expect(updateDir(), isEmpty);
    });

    test('APK 500: server, tanpa sisa berkas', () async {
      final release = (await service.latest())!;
      gh.apkStatus = 500;
      await expectLater(service.download(release), fails(UpdateFailure.server));
      expect(updateDir(), isEmpty);
    });

    test('dibatalkan di tengah: UpdateCancelled, tanpa sisa berkas', () async {
      final release = (await service.latest())!;
      final cancel = UpdateCancelToken();
      gh.onApkChunk = (sent) {
        if (sent >= 64 * 1024) cancel.cancel();
      };
      await expectLater(service.download(release, cancel: cancel), throwsA(isA<UpdateCancelled>()));
      expect(updateDir(), isEmpty);
    });

    test('APK melebihi batas ukuran ditolak sebelum diunduh', () async {
      final small = GitHubUpdateService(
        repo: _repo,
        tempDir: () async => temp,
        webBase: gh.base,
        publicKey: testPublicKey,
        maxApkBytes: 1024,
      );
      final release = (await small.latest())!;
      await expectLater(small.download(release), fails(UpdateFailure.badRelease));
    });
  });
}
