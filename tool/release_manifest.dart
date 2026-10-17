// Alat rilis TermUL Mobile (padanan ReleaseTool desktop): membuat kunci penandatangan, menulis dan menandatangani
// manifest.json, dan memeriksa hasilnya. Dipanggil oleh tool/release.ps1; lihat docs/release.md.
//
//   dart run tool/release_manifest.dart keygen  [--key FILE]
//   dart run tool/release_manifest.dart publish --apk FILE --version 0.1.120 --code 120 --notes FILE --out DIR
//                                               [--commit HASH] [--key FILE]
//   dart run tool/release_manifest.dart verify  --dir DIR
//
// Kunci privat: --key, atau env TERMUL_MOBILE_UPDATE_KEY, atau %USERPROFILE%\.termul-release\mobile-update-signing.key.
// Isinya Base64 seed Ed25519 32 byte. Jangan pernah di-commit atau dikirim lewat chat.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:termul_mobile/core/update/manifest.dart';
import 'package:termul_mobile/core/update/update_keys.dart';

Never fail(String message) {
  stderr.writeln('GAGAL: $message');
  exit(1);
}

Map<String, String> options(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (!args[i].startsWith('--') || i + 1 >= args.length) fail('argumen tidak dikenal: ${args[i]}');
    out[args[i].substring(2)] = args[++i];
  }
  return out;
}

String defaultKeyPath() {
  final env = Platform.environment['TERMUL_MOBILE_UPDATE_KEY'];
  if (env != null && env.isNotEmpty) return env;
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home == null) fail('USERPROFILE/HOME tidak ada; pakai --key');
  return '$home${Platform.pathSeparator}.termul-release${Platform.pathSeparator}mobile-update-signing.key';
}

List<int> readSeed(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('Private key tidak ada: $path (buat dengan keygen, atau set TERMUL_MOBILE_UPDATE_KEY)');
  }
  final List<int> seed;
  try {
    seed = base64.decode(file.readAsStringSync().trim());
  } on FormatException {
    fail('Private key bukan Base64: $path');
  }
  if (seed.length != 32) fail('Private key harus 32 byte: $path');
  return seed;
}

void keygen(Map<String, String> o) {
  final path = o['key'] ?? defaultKeyPath();
  final file = File(path);
  if (file.existsSync()) fail('Key sudah ada, tidak ditimpa: $path (pindahkan dulu file lama)');
  final random = Random.secure();
  final seed = List<int>.generate(32, (_) => random.nextInt(256));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${base64.encode(seed)}\n');
  stdout.writeln('Private key: $path');
  stdout.writeln('Public key (salin ke lib/core/update/update_keys.dart): ${publicKeyOf(seed)}');
}

void publish(Map<String, String> o) {
  final apkPath = o['apk'] ?? fail('--apk wajib');
  final version = o['version'] ?? fail('--version wajib');
  final code = int.tryParse(o['code'] ?? '') ?? fail('--code wajib (angka)');
  final notesPath = o['notes'] ?? fail('--notes wajib');
  final outPath = o['out'] ?? fail('--out wajib');
  final seed = readSeed(o['key'] ?? defaultKeyPath());
  if (updatePublicKey.isEmpty) fail('updatePublicKey di lib/core/update/update_keys.dart masih kosong');
  if (publicKeyOf(seed) != updatePublicKey) {
    fail('Private key tidak cocok dengan updatePublicKey di lib/core/update/update_keys.dart');
  }
  final apk = File(apkPath);
  if (!apk.existsSync()) fail('APK tidak ada: $apkPath');
  final notesFile = File(notesPath);
  if (!notesFile.existsSync()) fail('Catatan rilis tidak ada: $notesPath');
  final notes = notesFile.readAsStringSync().replaceAll('\r\n', '\n').trim();
  if (notes.isEmpty) fail('Catatan rilis kosong');

  final out = Directory(outPath);
  if (out.existsSync()) out.deleteSync(recursive: true);
  out.createSync(recursive: true);
  final name = 'termul-mobile-$version.apk';
  final copy = apk.copySync('${out.path}${Platform.pathSeparator}$name');
  final bytes = copy.readAsBytesSync();
  final manifest = UpdateManifest(
    version: version,
    versionCode: code,
    notes: notes,
    commit: o['commit'],
    apk: ManifestFile(name: name, sha256: crypto.sha256.convert(bytes).toString(), size: bytes.length),
  );
  final manifestBytes = manifest.encode();
  // Pastikan aplikasi bisa membaca persis apa yang ditulis.
  final parsed = UpdateManifest.parse(manifestBytes);
  if (parsed.version != version || parsed.versionCode != code) fail('manifest tidak terbaca ulang');
  final signature = signManifest(manifest: manifestBytes, seed: seed);
  File('${out.path}${Platform.pathSeparator}${UpdateManifest.fileName}').writeAsBytesSync(manifestBytes);
  File('${out.path}${Platform.pathSeparator}${UpdateManifest.signatureName}').writeAsStringSync(signature);
  stdout.writeln('Rilis $version (versionCode $code): $name, ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB');
  stdout.writeln('version=$version');
}

void verify(Map<String, String> o) {
  final dir = o['dir'] ?? fail('--dir wajib');
  final sep = Platform.pathSeparator;
  final manifestBytes = File('$dir$sep${UpdateManifest.fileName}').readAsBytesSync();
  final signature = File('$dir$sep${UpdateManifest.signatureName}').readAsStringSync();
  if (!verifyManifest(manifest: manifestBytes, signature: signature, publicKey: updatePublicKey)) {
    fail('Tanda tangan manifest tidak sah untuk updatePublicKey');
  }
  final m = UpdateManifest.parse(manifestBytes);
  final apk = File('$dir$sep${m.apk.name}').readAsBytesSync();
  if (apk.length != m.apk.size || crypto.sha256.convert(apk).toString() != m.apk.sha256) {
    fail('APK tidak cocok dengan manifest');
  }
  stdout.writeln('OK: ${m.version} (versionCode ${m.versionCode}), ${m.apk.name}');
}

void main(List<String> args) {
  if (args.isEmpty) fail('perintah: keygen | publish | verify');
  final o = options(args.sublist(1));
  switch (args.first) {
    case 'keygen':
      keygen(o);
    case 'publish':
      publish(o);
    case 'verify':
      verify(o);
    default:
      fail('perintah tidak dikenal: ${args.first}');
  }
}
