import 'package:flutter/services.dart';

/// Hasil menyimpan berkas ke Unduhan: [name] bisa berbeda dari yang diminta (nama kembar diberi akhiran
/// " (1)"), [location] jalur yang ditampilkan ke pengguna.
class SavedDownload {
  const SavedDownload({required this.name, required this.location, this.overwritten = false});

  final String name;
  final String location;

  /// true bila berkas lama dengan nama itu diganti isinya (bukan berkas baru).
  final bool overwritten;
}

/// Gagal menyimpan ke Unduhan (penyimpanan penuh, MediaStore menolak, berkas sumber hilang).
class DownloadSaveException implements Exception {
  const DownloadSaveException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'DownloadSaveException';
}

/// Menyalin berkas yang sudah selesai diunduh ke folder Unduhan/TermUL (`DownloadsSaver.kt`). Android saja.
abstract interface class DownloadsSaver {
  /// Ada berkas bernama [name] di Unduhan/TermUL (atau di [folder] di dalamnya) yang bisa dilihat aplikasi (milik
  /// aplikasi ini).
  Future<bool> exists(String name, {String? folder});

  /// Ada folder bernama [name] di Unduhan/TermUL yang berisi berkas milik aplikasi ini.
  Future<bool> folderExists(String name);

  /// Menyalin [path] ke Unduhan/TermUL sebagai [name], di dalam [folder] (jalur relatif dengan `/`, dibuat bila
  /// belum ada; bawaan langsung di Unduhan/TermUL). Dengan [overwrite], berkas lama milik aplikasi diganti isinya;
  /// bila tidak bisa diganti, hasilnya disimpan bernomor dan [SavedDownload.overwritten] false.
  Future<SavedDownload> save({required String path, required String name, String? folder, bool overwrite = false});
}

class MethodChannelDownloadsSaver implements DownloadsSaver {
  MethodChannelDownloadsSaver([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/downloads');

  final MethodChannel _channel;

  @override
  Future<bool> exists(String name, {String? folder}) async {
    try {
      return await _channel.invokeMethod<bool>('exists', {'name': name, 'folder': folder}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> folderExists(String name) async {
    try {
      return await _channel.invokeMethod<bool>('folderExists', {'name': name}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<SavedDownload> save({
    required String path,
    required String name,
    String? folder,
    bool overwrite = false,
  }) async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('save', {
        'path': path,
        'name': name,
        'folder': folder,
        'overwrite': overwrite,
      });
      if (r == null) throw const DownloadSaveException();
      return SavedDownload(
        name: (r['name'] as String?) ?? name,
        location: (r['location'] as String?) ?? 'Unduhan/TermUL',
        overwritten: (r['overwritten'] as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      throw DownloadSaveException(e.code);
    } on MissingPluginException catch (e) {
      throw DownloadSaveException(e);
    }
  }
}
