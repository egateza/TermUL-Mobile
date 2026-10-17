import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/update/manifest.dart';
import 'package:termul_mobile/core/update/release.dart';
import 'package:termul_mobile/core/update/update_keys.dart';

import 'test_keys.dart';

UpdateManifest sampleManifest({String version = '0.1.120', int code = 120, String notes = '- Perbaikan'}) =>
    UpdateManifest(
      version: version,
      versionCode: code,
      notes: notes,
      commit: 'abc123',
      apk: ManifestFile(name: 'termul-mobile-$version.apk', sha256: 'a' * 64, size: 1234),
    );

Map<String, Object?> _json(UpdateManifest m) => jsonDecode(utf8.decode(m.encode())) as Map<String, Object?>;

List<int> _bytes(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

void main() {
  test('encode lalu parse menghasilkan isi yang sama', () {
    final m = UpdateManifest.parse(sampleManifest().encode());
    expect(m.version, '0.1.120');
    expect(m.versionCode, 120);
    expect(m.notes, '- Perbaikan');
    expect(m.commit, 'abc123');
    expect(m.apk.name, 'termul-mobile-0.1.120.apk');
    expect(m.apk.sha256, 'a' * 64);
    expect(m.apk.size, 1234);
  });

  test('menolak format, app, versi, dan berkas yang tidak sesuai', () {
    final base = _json(sampleManifest());
    Map<String, Object?> withField(String k, Object? v) => {...base, k: v};
    Map<String, Object?> withFile(Map<String, Object?> f) => {
      ...base,
      'files': [f],
    };
    final file = (base['files']! as List).single as Map<String, Object?>;
    for (final bad in [
      withField('format', 2),
      withField('app', 'termul'),
      withField('version', 'v0.1.120'),
      withField('version', '0.1'),
      withField('versionCode', 0),
      withField('files', []),
      withField('files', [file, file]),
      withFile({...file, 'name': '../x.apk'}),
      withFile({...file, 'name': 'termul.jar'}),
      withFile({...file, 'sha256': 'A' * 64}),
      withFile({...file, 'size': 0}),
    ]) {
      expect(() => UpdateManifest.parse(_bytes(bad)), throwsFormatException, reason: '$bad');
    }
    expect(() => UpdateManifest.parse(utf8.encode('{bukan json')), throwsFormatException);
  });

  test('tanda tangan sah hanya untuk byte persis dan kunci yang sama', () {
    final bytes = sampleManifest().encode();
    final sig = signManifest(manifest: bytes, seed: testSeed);
    expect(verifyManifest(manifest: bytes, signature: sig, publicKey: testPublicKey), isTrue);

    final tampered = sampleManifest(notes: '- Perbaikan lain').encode();
    expect(verifyManifest(manifest: tampered, signature: sig, publicKey: testPublicKey), isFalse);

    final otherKey = publicKeyOf(List<int>.generate(32, (i) => 200 - i));
    expect(verifyManifest(manifest: bytes, signature: sig, publicKey: otherKey), isFalse);
    expect(verifyManifest(manifest: bytes, signature: 'bukan base64!', publicKey: testPublicKey), isFalse);
    expect(verifyManifest(manifest: bytes, signature: base64.encode([1, 2, 3]), publicKey: testPublicKey), isFalse);
  });

  test('kunci publik rilis tertanam dan berbentuk 32 byte', () {
    expect(base64.decode(updatePublicKey), hasLength(32));
  });

  test('rilis dari manifest: alamat per tag, lebih baru hanya bila versionCode lebih tinggi', () {
    final r = ReleaseInfo.fromManifest(
      sampleManifest(),
      base: Uri.parse('https://github.com/egateza/TermUL-Mobile/releases'),
    );
    expect(r.tag, 'v0.1.120');
    expect(r.page.toString(), 'https://github.com/egateza/TermUL-Mobile/releases/tag/v0.1.120');
    expect(
      r.apk.url.toString(),
      'https://github.com/egateza/TermUL-Mobile/releases/download/v0.1.120/termul-mobile-0.1.120.apk',
    );
    expect(r.isNewerThan(const AppVersion('0.1.119', 119)), isTrue);
    expect(r.isNewerThan(const AppVersion('0.1.120', 120)), isFalse);
    expect(r.isNewerThan(const AppVersion('0.1.121-dirty', 121)), isFalse);
  });
}
