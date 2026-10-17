import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/update/release.dart';
import 'package:termul_mobile/core/update/update_service.dart';

/// Server HTTP lokal yang meniru GitHub: `/repos/.../releases/latest` dan berkas aset.
class _FakeGitHub {
  late HttpServer server;
  int latestStatus = 200;
  String? latestBody;
  List<int> apk = List.generate(200 * 1024, (i) => i % 251);
  String? checksumOverride;
  int apkStatus = 200;

  /// Dipanggil sebelum mengirim tiap potongan APK (untuk membatalkan di tengah).
  void Function(int sent)? onApkChunk;

  Uri get base => Uri.parse('http://${server.address.host}:${server.port}');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      switch (req.uri.path) {
        case '/repos/egateza/TermUL-Mobile/releases/latest':
          res.statusCode = latestStatus;
          res.write(latestBody ?? jsonEncode(releaseJson()));
        case '/dl/termul.apk':
          res.statusCode = apkStatus;
          if (apkStatus == 200) {
            res.contentLength = apk.length;
            for (var i = 0; i < apk.length; i += 16 * 1024) {
              onApkChunk?.call(i);
              res.add(apk.sublist(i, i + 16 * 1024 > apk.length ? apk.length : i + 16 * 1024));
              await res.flush();
            }
          }
        case '/dl/termul.apk.sha256':
          res.write(checksumOverride ?? '${sha256.convert(apk)}  termul.apk\n');
        case '/redirect/termul.apk':
          res.redirect(base.resolve('/dl/termul.apk'));
          return;
        default:
          res.statusCode = 404;
      }
      await res.close();
    });
  }

  Map<String, Object?> releaseJson() => {
    'tag_name': 'v0.2.0',
    'body': 'Catatan',
    'assets': [
      // parseRelease menolak selain https; tes memakai URL lokal lewat [localRelease].
      {'name': 'termul.apk', 'browser_download_url': 'https://example.invalid/termul.apk', 'size': apk.length},
      {'name': 'termul.apk.sha256', 'browser_download_url': 'https://example.invalid/termul.apk.sha256', 'size': 80},
    ],
  };

  ReleaseInfo localRelease({String apkPath = '/dl/termul.apk'}) => ReleaseInfo(
    tag: 'v0.2.0',
    version: ReleaseVersion.tryParse('v0.2.0')!,
    notes: '',
    page: null,
    apk: ReleaseAsset(name: 'termul.apk', url: base.resolve(apkPath), size: apk.length),
    checksum: ReleaseAsset(name: 'termul.apk.sha256', url: base.resolve('/dl/termul.apk.sha256'), size: 80),
  );
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
      repo: 'egateza/TermUL-Mobile',
      tempDir: () async => temp,
      apiBase: gh.base,
      timeout: const Duration(seconds: 5),
    );
  });

  tearDown(() async {
    await gh.server.close(force: true);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  File? readyFile() {
    final f = File('${temp.path}${Platform.pathSeparator}update${Platform.pathSeparator}termul-update.apk');
    return f.existsSync() ? f : null;
  }

  List<FileSystemEntity> updateDir() {
    final d = Directory('${temp.path}${Platform.pathSeparator}update');
    return d.existsSync() ? d.listSync() : const [];
  }

  group('latest', () {
    test('rilis terbaru dibaca', () async {
      final r = await service.latest();
      expect(r!.version.name, '0.2.0');
      expect(r.notes, 'Catatan');
    });

    test('404: belum ada rilis', () async {
      gh.latestStatus = 404;
      expect(await service.latest(), isNull);
    });

    test('403 (batas permintaan): server', () async {
      gh.latestStatus = 403;
      await expectLater(
        service.latest(),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.server)),
      );
    });

    test('JSON rusak atau rilis tanpa APK: badRelease', () async {
      gh.latestBody = '{tidak json';
      await expectLater(
        service.latest(),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.badRelease)),
      );
      gh.latestBody = jsonEncode({'tag_name': 'v0.2.0', 'assets': []});
      await expectLater(
        service.latest(),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.badRelease)),
      );
    });

    test('server tidak terjangkau: network', () async {
      await gh.server.close(force: true);
      await expectLater(
        service.latest(),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.network)),
      );
    });
  });

  group('download', () {
    test('checksum cocok: berkas siap pasang dengan kemajuan sampai 100%', () async {
      final progress = <int>[];
      final path = await service.download(gh.localRelease(), onProgress: (r, t) => progress.add(r * 100 ~/ t));
      expect(path, readyFile()!.path);
      expect(await File(path).readAsBytes(), gh.apk);
      expect(progress.first, 0);
      expect(progress.last, 100);
      expect(updateDir(), hasLength(1));
    });

    test('mengikuti pengalihan (aset GitHub dialihkan ke penyimpanan)', () async {
      final path = await service.download(gh.localRelease(apkPath: '/redirect/termul.apk'));
      expect(await File(path).readAsBytes(), gh.apk);
    });

    test('checksum tidak cocok: ditolak dan berkas dihapus', () async {
      gh.checksumOverride = '${'0' * 64}  termul.apk';
      await expectLater(
        service.download(gh.localRelease()),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.checksum)),
      );
      expect(readyFile(), isNull);
      expect(updateDir(), isEmpty);
    });

    test('berkas checksum tanpa hex: badRelease', () async {
      gh.checksumOverride = 'kosong';
      await expectLater(
        service.download(gh.localRelease()),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.badRelease)),
      );
    });

    test('APK 500: server, tanpa sisa berkas', () async {
      gh.apkStatus = 500;
      await expectLater(
        service.download(gh.localRelease()),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.server)),
      );
      expect(updateDir(), isEmpty);
    });

    test('dibatalkan di tengah: UpdateCancelled, tanpa sisa berkas', () async {
      final cancel = UpdateCancelToken();
      gh.onApkChunk = (sent) {
        if (sent >= 64 * 1024) cancel.cancel();
      };
      await expectLater(service.download(gh.localRelease(), cancel: cancel), throwsA(isA<UpdateCancelled>()));
      expect(updateDir(), isEmpty);
    });

    test('APK melebihi batas ukuran ditolak sebelum diunduh', () async {
      final small = GitHubUpdateService(
        repo: 'egateza/TermUL-Mobile',
        tempDir: () async => temp,
        apiBase: gh.base,
        maxApkBytes: 1024,
      );
      await expectLater(
        small.download(gh.localRelease()),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.badRelease)),
      );
    });

    test('unduhan baru menggantikan berkas lama', () async {
      await service.download(gh.localRelease());
      gh.apk = List.generate(1000, (i) => 7);
      final path = await service.download(gh.localRelease());
      expect(await File(path).readAsBytes(), gh.apk);
      expect(updateDir(), hasLength(1));
    });
  });
}
