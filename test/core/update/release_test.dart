import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/update/release.dart';

Map<String, Object?> releaseJson({
  String tag = 'v0.2.0',
  List<Map<String, Object?>>? assets,
  String? body = 'Perbaikan sambung ulang.',
}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/egateza/TermUL-Mobile/releases/tag/$tag',
  'body': body,
  'assets':
      assets ??
      [
        {
          'name': 'termul-mobile-0.2.0.apk',
          'browser_download_url': 'https://github.com/x/termul-mobile-0.2.0.apk',
          'size': 1234,
        },
        {
          'name': 'termul-mobile-0.2.0.apk.sha256',
          'browser_download_url': 'https://github.com/x/termul-mobile-0.2.0.apk.sha256',
          'size': 90,
        },
      ],
};

void main() {
  group('ReleaseVersion', () {
    test('membaca tag dengan atau tanpa v dan +build', () {
      expect(ReleaseVersion.tryParse('v0.2.0')!.parts, [0, 2, 0]);
      expect(ReleaseVersion.tryParse('1.4')!.name, '1.4.0');
      expect(ReleaseVersion.tryParse('v0.2.0+7')!.build, 7);
      expect(ReleaseVersion.tryParse('nightly'), isNull);
      expect(ReleaseVersion.tryParse('v0.2.0-beta'), isNull);
    });

    test('lebih baru bila nomor versi lebih tinggi', () {
      const installed = AppVersion('0.1.0', 1);
      expect(ReleaseVersion.tryParse('v0.2.0')!.isNewerThan(installed), isTrue);
      expect(ReleaseVersion.tryParse('v0.1.1')!.isNewerThan(installed), isTrue);
      expect(ReleaseVersion.tryParse('v0.1.0')!.isNewerThan(installed), isFalse);
      expect(ReleaseVersion.tryParse('v0.0.9')!.isNewerThan(installed), isFalse);
      expect(ReleaseVersion.tryParse('v0.10.0')!.isNewerThan(const AppVersion('0.9.0', 9)), isTrue);
    });

    test('nomor versi sama: +build dibandingkan dengan versionCode', () {
      const installed = AppVersion('0.2.0', 3);
      expect(ReleaseVersion.tryParse('v0.2.0+4')!.isNewerThan(installed), isTrue);
      expect(ReleaseVersion.tryParse('v0.2.0+3')!.isNewerThan(installed), isFalse);
    });
  });

  group('parseRelease', () {
    test('rilis lengkap', () {
      final r = parseRelease(releaseJson());
      expect(r.version.name, '0.2.0');
      expect(r.apk.name, 'termul-mobile-0.2.0.apk');
      expect(r.apk.size, 1234);
      expect(r.checksum.name, 'termul-mobile-0.2.0.apk.sha256');
      expect(r.notes, 'Perbaikan sambung ulang.');
    });

    test('ditolak tanpa APK, dengan dua APK, tanpa checksum, atau tag bukan versi', () {
      expect(() => parseRelease(releaseJson(assets: [])), throwsA(isA<BadReleaseException>()));
      final apk = {'name': 'a.apk', 'browser_download_url': 'https://x/a.apk', 'size': 1};
      final apk2 = {'name': 'b.apk', 'browser_download_url': 'https://x/b.apk', 'size': 1};
      final sum = {'name': 'a.apk.sha256', 'browser_download_url': 'https://x/a.apk.sha256', 'size': 1};
      expect(() => parseRelease(releaseJson(assets: [apk, apk2, sum])), throwsA(isA<BadReleaseException>()));
      expect(() => parseRelease(releaseJson(assets: [apk])), throwsA(isA<BadReleaseException>()));
      expect(() => parseRelease(releaseJson(tag: 'terbaru')), throwsA(isA<BadReleaseException>()));
      expect(() => parseRelease('bukan objek'), throwsA(isA<BadReleaseException>()));
    });

    test('URL selain https diabaikan', () {
      final apk = {'name': 'a.apk', 'browser_download_url': 'http://x/a.apk', 'size': 1};
      final sum = {'name': 'a.apk.sha256', 'browser_download_url': 'https://x/a.apk.sha256', 'size': 1};
      expect(() => parseRelease(releaseJson(assets: [apk, sum])), throwsA(isA<BadReleaseException>()));
    });
  });

  test('parseChecksum: keluaran sha256sum atau hex saja', () {
    final hex = 'A' * 64;
    expect(parseChecksum('$hex  termul.apk\n'), 'a' * 64);
    expect(parseChecksum(hex), 'a' * 64);
    expect(parseChecksum('bukan checksum'), isNull);
    expect(parseChecksum('${'a' * 63}  x'), isNull);
  });
}
