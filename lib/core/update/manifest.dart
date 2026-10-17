import 'dart:convert';
import 'dart:typed_data';

import 'package:pinenacl/ed25519.dart' as ed;

/// `manifest.json` rilis (seperti TermUL desktop, ADR 0003 di repo desktop): daftar berkas rilis beserta SHA-256 dan
/// ukurannya, versi, dan catatan rilis. Ditandatangani Ed25519 atas byte persis berkasnya (`manifest.json.sig`, Base64
/// 64 byte). Dart murni: dipakai aplikasi untuk memverifikasi dan `tool/release_manifest.dart` untuk menandatangani.
///
/// ```json
/// {"format": 1, "app": "termul-mobile", "version": "0.1.120", "versionCode": 120, "commit": "<hash>",
///  "notes": "- Perbaikan ...", "files": [{"name": "termul-mobile-0.1.120.apk", "sha256": "<hex>", "size": 123}]}
/// ```
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.versionCode,
    required this.notes,
    required this.apk,
    this.commit,
  });

  static const format = 1;
  static const app = 'termul-mobile';

  /// Nama aset di rilis GitHub.
  static const fileName = 'manifest.json';
  static const signatureName = 'manifest.json.sig';

  /// `major.minor.<jumlah commit>`.
  final String version;

  /// `versionCode` Android (jumlah commit); dibandingkan dengan versi terpasang.
  final int versionCode;
  final String notes;
  final ManifestFile apk;
  final String? commit;

  static final _versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
  static final _namePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*\.apk$');
  static final _hexPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Membaca dan memeriksa isi manifest. Melempar [FormatException] bila tidak sesuai format.
  factory UpdateManifest.parse(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('manifest bukan JSON');
    }
    if (json is! Map<String, Object?>) throw const FormatException('manifest bukan objek');
    if (json['format'] != format) throw FormatException('format ${json['format']}');
    if (json['app'] != app) throw FormatException('app ${json['app']}');
    final version = json['version'];
    final code = json['versionCode'];
    final notes = json['notes'];
    final files = json['files'];
    if (version is! String || !_versionPattern.hasMatch(version)) throw const FormatException('version');
    if (code is! int || code <= 0) throw const FormatException('versionCode');
    if (files is! List) throw const FormatException('files');
    final apks = <ManifestFile>[];
    for (final f in files) {
      if (f is! Map<String, Object?>) throw const FormatException('files[]');
      final name = f['name'];
      final hash = f['sha256'];
      final size = f['size'];
      if (name is! String || hash is! String || size is! int) throw const FormatException('files[]');
      if (!_namePattern.hasMatch(name) || !_hexPattern.hasMatch(hash) || size <= 0) {
        throw FormatException('files[] $name');
      }
      apks.add(ManifestFile(name: name, sha256: hash, size: size));
    }
    if (apks.length != 1) throw FormatException('APK: ${apks.length}');
    final commit = json['commit'];
    return UpdateManifest(
      version: version,
      versionCode: code,
      notes: notes is String ? notes.trim() : '',
      apk: apks.single,
      commit: commit is String ? commit : null,
    );
  }

  /// Isi `manifest.json` (indentasi dua spasi, diakhiri baris baru). Byte inilah yang ditandatangani.
  List<int> encode() => utf8.encode(
    '${const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'app': app,
      'version': version,
      'versionCode': versionCode,
      'commit': ?commit,
      'notes': notes,
      'files': [
        {'name': apk.name, 'sha256': apk.sha256, 'size': apk.size},
      ],
    })}\n',
  );
}

class ManifestFile {
  const ManifestFile({required this.name, required this.sha256, required this.size});

  final String name;

  /// Heksadesimal huruf kecil.
  final String sha256;
  final int size;
}

/// Tanda tangan Ed25519 [signature] (isi berkas `.sig`: Base64 64 byte) atas [manifest] sah untuk [publicKey]
/// (Base64 32 byte).
bool verifyManifest({required List<int> manifest, required String signature, required String publicKey}) {
  try {
    final sig = base64.decode(signature.trim());
    final key = ed.VerifyKey(Uint8List.fromList(base64.decode(publicKey)));
    return key.verify(signature: ed.Signature(Uint8List.fromList(sig)), message: Uint8List.fromList(manifest));
  } on Object {
    // pinenacl melempar Exception untuk tanda tangan palsu atau panjang yang salah; Base64 rusak: FormatException.
    return false;
  }
}

/// Menandatangani [manifest] dengan kunci privat [seed] (32 byte); hasilnya isi berkas `.sig`.
String signManifest({required List<int> manifest, required List<int> seed}) {
  final key = ed.SigningKey.fromSeed(Uint8List.fromList(seed));
  final signed = key.sign(Uint8List.fromList(manifest));
  return '${base64.encode(signed.signature.asTypedList)}\n';
}

/// Kunci publik (Base64) dari kunci privat [seed].
String publicKeyOf(List<int> seed) =>
    base64.encode(ed.SigningKey.fromSeed(Uint8List.fromList(seed)).verifyKey.asTypedList);
