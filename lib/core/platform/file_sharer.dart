import 'package:flutter/services.dart';

/// Gagal membuka menu bagikan (tidak ada Activity, berkas di luar folder yang dibagikan).
class ShareException implements Exception {
  const ShareException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'ShareException';
}

/// Membuka menu bagikan bawaan Android untuk satu berkas (`FileSharer.kt`). Android saja. Berkas harus ada di
/// `<folder sementara aplikasi>/share/`; selesai berarti menu terbuka, bukan berarti pengguna memilih tujuan.
abstract interface class FileSharer {
  Future<void> shareFile({required String path, required String name, required String mimeType, String? title});
}

class MethodChannelFileSharer implements FileSharer {
  MethodChannelFileSharer([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/share');

  final MethodChannel _channel;

  @override
  Future<void> shareFile({required String path, required String name, required String mimeType, String? title}) async {
    try {
      await _channel.invokeMethod<void>('shareFile', {
        'path': path,
        'name': name,
        'mimeType': mimeType,
        'title': title,
      });
    } on PlatformException catch (e) {
      throw ShareException(e.code);
    } on MissingPluginException catch (e) {
      throw ShareException(e);
    }
  }
}
