import 'package:flutter/services.dart';

/// Membuka Android Storage Access Framework agar pengguna memilih lokasi dan nama berkas ekspor.
abstract interface class DeviceDocumentSaver {
  /// `false` bila pengguna membatalkan pemilih lokasi.
  Future<bool> save({required String name, required String mimeType, required Uint8List bytes});
}

class MethodChannelDeviceDocumentSaver implements DeviceDocumentSaver {
  MethodChannelDeviceDocumentSaver([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/documents');

  final MethodChannel _channel;

  @override
  Future<bool> save({required String name, required String mimeType, required Uint8List bytes}) async {
    try {
      return await _channel.invokeMethod<bool>('saveDocument', {'name': name, 'mimeType': mimeType, 'bytes': bytes}) ??
          false;
    } on PlatformException catch (e) {
      throw DeviceDocumentSaveException(e.code);
    } on MissingPluginException catch (e) {
      throw DeviceDocumentSaveException(e);
    }
  }
}

class DeviceDocumentSaveException implements Exception {
  const DeviceDocumentSaveException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'DeviceDocumentSaveException';
}
