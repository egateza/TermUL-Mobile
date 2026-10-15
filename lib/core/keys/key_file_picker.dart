import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'private_key_inspector.dart';

/// Memilih berkas kunci privat dari penyimpanan perangkat. Isi dibaca sebagai byte dan tidak disimpan di
/// tempat lain; path berkas tidak dicatat. Tempel dari papan klip sengaja tidak disediakan.
abstract interface class KeyFilePicker {
  /// `null` bila pengguna membatalkan. Melempar [KeyImportException] bila berkas terlalu besar.
  Future<Uint8List?> pick();
}

/// Implementasi dengan `file_selector` (Storage Access Framework di Android). Belum diuji di HP fisik.
class FileSelectorKeyPicker implements KeyFilePicker {
  const FileSelectorKeyPicker();

  @override
  Future<Uint8List?> pick() async {
    final file = await openFile();
    if (file == null) return null;
    if (await file.length() > PrivateKeyInspector.maxBytes) {
      throw const KeyImportException(KeyProblem.notAKey);
    }
    return file.readAsBytes();
  }
}
