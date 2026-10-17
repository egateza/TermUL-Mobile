import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import 'profile_import.dart';

/// Memilih berkas daftar profil (`profiles.json` dari TermUL desktop) dan mengembalikan isinya sebagai teks.
/// Jalur berkas tidak dicatat.
abstract interface class ProfileFilePicker {
  /// `null` bila pengguna membatalkan. Melempar [ImportFormatException] bila berkas terlalu besar atau bukan teks.
  Future<String?> pick();
}

/// Implementasi dengan `file_selector` (Storage Access Framework di Android). Tanpa filter jenis berkas: pengelola
/// berkas Android kadang melaporkan `.json` sebagai `application/octet-stream` sehingga filter menyembunyikannya.
/// Belum diuji di HP fisik.
class FileSelectorProfilePicker implements ProfileFilePicker {
  const FileSelectorProfilePicker();

  /// Daftar ratusan profil masih jauh di bawah ini; batas mencegah berkas asing memenuhi memori.
  static const maxBytes = 2 * 1024 * 1024;

  @override
  Future<String?> pick() async {
    final file = await openFile();
    if (file == null) return null;
    if (await file.length() > maxBytes) throw const ImportFormatException('Berkas terlalu besar untuk daftar profil.');
    try {
      return utf8.decode(await file.readAsBytes());
    } on FormatException {
      throw const ImportFormatException('Berkas bukan teks.');
    }
  }
}
