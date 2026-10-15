import 'dart:convert';
import 'dart:io';

import 'storage_exception.dart';

/// Hasil memuat berkas JSON: [value] selalu ada; [quarantinedPath] terisi bila berkas rusak dipindahkan.
class JsonLoad<T> {
  const JsonLoad(this.value, {this.quarantinedPath});

  final T value;
  final String? quarantinedPath;
}

/// Membaca [file] sebagai objek JSON lalu mengubahnya dengan [parse].
///
/// - Berkas belum ada: mengembalikan [empty].
/// - Berkas rusak (bukan JSON, bukan objek, atau [parse] melempar [FormatException], [ArgumentError], [TypeError]):
///   dipindah ke `<nama>.corrupt-<epoch ms>` lalu mengembalikan [empty]. Isi berkas tidak dibuang.
/// - Bila pemindahan gagal, melempar [StorageException] dan **tidak** melanjutkan, supaya tulisan berikutnya
///   tidak menimpa berkas yang rusak.
Future<JsonLoad<T>> loadJsonOrQuarantine<T>(
  File file, {
  required T Function(Map<String, Object?> json) parse,
  required T empty,
}) async {
  final String text;
  try {
    // Decode sendiri: readAsString melempar FileSystemException (bukan FormatException) untuk UTF-8 tidak sah.
    text = utf8.decode(await file.readAsBytes());
  } on PathNotFoundException {
    return JsonLoad(empty);
  } on FileSystemException catch (e) {
    if (!await file.exists()) return JsonLoad(empty);
    throw StorageException('Berkas ${file.uri.pathSegments.last} tidak bisa dibaca', e);
  } on FormatException {
    return JsonLoad(empty, quarantinedPath: await _quarantine(file));
  }
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Isi berkas bukan objek JSON');
    }
    return JsonLoad(parse(decoded));
  } on FormatException {
    return JsonLoad(empty, quarantinedPath: await _quarantine(file));
  } on ArgumentError {
    return JsonLoad(empty, quarantinedPath: await _quarantine(file));
  } on TypeError {
    return JsonLoad(empty, quarantinedPath: await _quarantine(file));
  }
}

Future<String> _quarantine(File file) async {
  final base = '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}';
  var target = base;
  for (var i = 1; await File(target).exists(); i++) {
    target = '$base-$i';
  }
  try {
    await file.rename(target);
  } on FileSystemException catch (e) {
    throw StorageException('Berkas ${file.uri.pathSegments.last} rusak dan tidak bisa disisihkan', e);
  }
  return target;
}
