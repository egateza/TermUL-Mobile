import 'dart:convert';
import 'dart:io';

import 'package:xterm/xterm.dart';

import '../../core/platform/downloads_saver.dart';
import '../../core/platform/file_sharer.dart';

/// Isi terminal sebagai teks biasa (menu tekan-tahan: Salin semua, Simpan transkrip, Bagikan transkrip): seluruh
/// scrollback layar yang sedang tampil, baris yang terbungkus disambung lagi, spasi di ujung baris dan baris kosong
/// di bawah prompt dibuang.
class TerminalTranscript {
  const TerminalTranscript._(this.text, this.lineCount);

  factory TerminalTranscript.of(Terminal terminal) {
    final lines = terminal.buffer.getText().split('\n').map((l) => l.trimRight()).toList();
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return TerminalTranscript._(lines.join('\n'), lines.length);
  }

  final String text;
  final int lineCount;

  bool get isEmpty => lineCount == 0;

  /// Nama berkas `host-YYYYMMDD-HHMM.txt`; karakter yang tidak aman untuk nama berkas diganti `_`.
  static String fileName(String host, DateTime at) {
    final safe = host.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}';
    return '${safe.isEmpty ? 'terminal' : safe}-$stamp.txt';
  }
}

/// Menulis transkrip ke berkas sementara lalu menyimpannya ke Unduhan/TermUL atau membuka menu bagikan. Berkas
/// sementara ada di `<tmp>/share/` (syarat `FileSharer`) dan diganti setiap kali dipakai.
class TranscriptExporter {
  const TranscriptExporter({required this.tempDir, required this.saver, required this.sharer});

  final Future<Directory> Function() tempDir;
  final DownloadsSaver saver;
  final FileSharer sharer;

  Future<File> _write(String name, String text) async {
    final dir = Directory('${(await tempDir()).path}${Platform.pathSeparator}share');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(utf8.encode(text.endsWith('\n') ? text : '$text\n'), flush: true);
    return file;
  }

  /// Menyimpan ke Unduhan/TermUL; nama kembar diberi nomor oleh [saver].
  Future<SavedDownload> save(String name, String text) async {
    final file = await _write(name, text);
    try {
      return await saver.save(path: file.path, name: name);
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// Membuka menu bagikan Android. Berkas dibiarkan: aplikasi tujuan membacanya setelah menu terbuka.
  Future<void> share(String name, String text, {String? title}) async {
    final file = await _write(name, text);
    await sharer.shareFile(path: file.path, name: name, mimeType: 'text/plain', title: title);
  }
}
