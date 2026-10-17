import 'package:flutter/services.dart';

/// Hasil menyimpan berkas ke Unduhan: [name] bisa berbeda dari yang diminta (nama kembar diberi akhiran
/// " (1)"), [location] jalur yang ditampilkan ke pengguna.
class SavedDownload {
  const SavedDownload({required this.name, required this.location});

  final String name;
  final String location;
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
  Future<SavedDownload> save({required String path, required String name});
}

class MethodChannelDownloadsSaver implements DownloadsSaver {
  MethodChannelDownloadsSaver([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/downloads');

  final MethodChannel _channel;

  @override
  Future<SavedDownload> save({required String path, required String name}) async {
    try {
      final r = await _channel.invokeMapMethod<String, String>('save', {'path': path, 'name': name});
      if (r == null) throw const DownloadSaveException();
      return SavedDownload(name: r['name'] ?? name, location: r['location'] ?? 'Unduhan/TermUL');
    } on PlatformException catch (e) {
      throw DownloadSaveException(e.code);
    } on MissingPluginException catch (e) {
      throw DownloadSaveException(e);
    }
  }
}
