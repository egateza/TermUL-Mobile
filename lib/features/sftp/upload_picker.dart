import 'package:file_selector/file_selector.dart';

/// Memilih berkas dari penyimpanan perangkat untuk diunggah. Isi dibaca bertahap lewat [XFile.openRead], tidak
/// dimuat utuh ke memori; jalur berkas tidak dicatat.
abstract interface class UploadPicker {
  /// Kosong bila pengguna membatalkan.
  Future<List<XFile>> pick();
}

/// Implementasi dengan `file_selector` (Storage Access Framework di Android).
class FileSelectorUploadPicker implements UploadPicker {
  const FileSelectorUploadPicker();

  @override
  Future<List<XFile>> pick() => openFiles();
}
