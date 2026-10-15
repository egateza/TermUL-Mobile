import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// Hasil pemeriksaan berkas kunci privat.
class InspectedKey {
  const InspectedKey({required this.pem, required this.encrypted, required this.type});

  /// Isi PEM (teks). Rahasia: simpan hanya ke vault, jangan dicatat.
  final String pem;

  /// true bila kunci dilindungi passphrase.
  final bool encrypted;

  /// Jenis kunci di PEM, mis. `OPENSSH PRIVATE KEY`, `RSA PRIVATE KEY`, `EC PRIVATE KEY`.
  final String type;
}

enum KeyProblem {
  /// Berkas terlalu besar atau jelas bukan kunci (bukan teks).
  notAKey,

  /// Bukan PEM.
  notPem,

  /// PKCS#8 (`PRIVATE KEY` atau `ENCRYPTED PRIVATE KEY`): belum didukung `dartssh2`.
  pkcs8Unsupported,

  /// PEM kunci jenis lain.
  unsupportedType,

  /// PEM rusak.
  malformed,

  /// Passphrase salah atau kosong.
  wrongPassphrase,
}

class KeyImportException implements Exception {
  const KeyImportException(this.problem, [this.detail]);

  final KeyProblem problem;

  /// Keterangan teknis aman (tanpa isi kunci), mis. nama jenis PEM.
  final String? detail;

  @override
  String toString() => 'KeyImportException(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// Memeriksa dan memvalidasi kunci privat sebelum disimpan ke vault. Jenis yang didukung: `OPENSSH PRIVATE KEY`,
/// `RSA PRIVATE KEY` (PKCS#1), dan `EC PRIVATE KEY` (terbukti di spike). Tidak pernah menulis isi kunci ke log.
abstract final class PrivateKeyInspector {
  static const maxBytes = 64 * 1024;

  static const _supported = {'OPENSSH PRIVATE KEY', 'RSA PRIVATE KEY', 'EC PRIVATE KEY'};
  static final _begin = RegExp(r'-----BEGIN ([A-Z0-9 ]+)-----');

  /// Membaca [bytes] sebagai PEM. Melempar [KeyImportException] bila bukan kunci yang didukung.
  static InspectedKey inspect(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const KeyImportException(KeyProblem.notAKey);
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const KeyImportException(KeyProblem.notAKey);
    }
    final match = _begin.firstMatch(text);
    if (match == null) throw const KeyImportException(KeyProblem.notPem);
    final type = match.group(1)!;
    if (type == 'PRIVATE KEY' || type == 'ENCRYPTED PRIVATE KEY') {
      throw KeyImportException(KeyProblem.pkcs8Unsupported, type);
    }
    if (!_supported.contains(type)) {
      throw KeyImportException(KeyProblem.unsupportedType, type);
    }
    try {
      return InspectedKey(pem: text, encrypted: SSHKeyPair.isEncryptedPem(text), type: type);
    } on Object {
      throw KeyImportException(KeyProblem.malformed, type);
    }
  }

  /// Memastikan [pem] bisa dibuka dengan [passphrase] (null atau kosong untuk kunci tanpa passphrase).
  static void verifyPassphrase(String pem, String? passphrase) {
    try {
      final pass = (passphrase == null || passphrase.isEmpty) ? null : passphrase;
      final pairs = SSHKeyPair.fromPem(pem, pass);
      if (pairs.isEmpty) throw const KeyImportException(KeyProblem.malformed);
    } on SSHKeyDecryptError {
      throw const KeyImportException(KeyProblem.wrongPassphrase);
    } on KeyImportException {
      rethrow;
    } on Object {
      throw const KeyImportException(KeyProblem.malformed);
    }
  }
}
