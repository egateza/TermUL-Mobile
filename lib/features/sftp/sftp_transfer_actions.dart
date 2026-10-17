import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;

import '../../core/platform/downloads_saver.dart';
import '../../core/sftp/sftp_service.dart';
import 'sftp_link.dart';
import 'sftp_transfers.dart';

/// Hasil satu transfer, untuk toast di layar.
sealed class TransferOutcome {
  const TransferOutcome(this.name);

  final String name;
}

final class TransferDone extends TransferOutcome {
  /// [location] hanya untuk unduhan (mis. `Unduhan/TermUL`); [savedName] bisa berbeda dari [name].
  const TransferDone(super.name, {this.location, this.savedName, this.overwritten = false});

  final String? location;
  final String? savedName;

  /// Unduhan: isi berkas lama diganti.
  final bool overwritten;
}

final class TransferCancelled extends TransferOutcome {
  const TransferCancelled(super.name);
}

final class TransferFailed extends TransferOutcome {
  const TransferFailed(super.name, this.kind, {this.saveFailed = false});

  final SftpFailureKind kind;

  /// Berkas sudah diterima utuh tetapi tidak bisa disimpan ke Unduhan.
  final bool saveFailed;
}

/// Menjalankan unduhan dan unggahan di atas [SftpLink]: mendaftarkan transfer ke [SftpTransferTracker] (supaya
/// konfirmasi keluar dan pembatalan saat putus mengenalinya), membatasi laju pembaruan progres, dan membersihkan
/// berkas sementara. Tanpa UI sehingga bisa dites.
class SftpTransferActions {
  SftpTransferActions({
    required this.link,
    required this.saver,
    required this.tempDir,
    this.progressInterval = const Duration(milliseconds: 120),
  });

  final SftpLink link;
  final DownloadsSaver saver;

  /// Folder berkas sementara unduhan (cache aplikasi); diganti di tes.
  final Future<Directory> Function() tempDir;

  /// Jarak minimum antar pembaruan progres ke UI (byte demi byte akan membuat UI macet).
  final Duration progressInterval;

  SftpFileOps? get _ops {
    final s = link.service;
    return s is SftpFileOps ? s as SftpFileOps : null;
  }

  /// Meneruskan progres ke pelacak paling sering sekali per [progressInterval]; pembaruan pertama dan yang
  /// mencapai total selalu diteruskan.
  void Function(int) _throttled(SftpTransfer t) {
    final clock = Stopwatch()..start();
    int? lastMs;
    return (bytes) {
      final now = clock.elapsedMilliseconds;
      if (lastMs == null || now - lastMs! >= progressInterval.inMilliseconds || bytes >= (t.total ?? -1)) {
        lastMs = now;
        link.transfers.progress(t, bytes);
      }
    };
  }

  /// Mengunduh [entry] lalu menyalinnya ke Unduhan/TermUL sebagai [saveAs] (bawaan: nama aslinya). Dengan [overwrite],
  /// berkas lama bernama sama diganti. Berkas sementara selalu dihapus; bila dibatalkan atau gagal, tidak ada yang
  /// muncul di Unduhan.
  Future<TransferOutcome> download(SftpEntry entry, {String? saveAs, bool overwrite = false}) async {
    final ops = _ops;
    if (ops == null) return TransferFailed(entry.name, SftpFailureKind.other);
    final t = link.transfers.start(name: entry.name, upload: false, total: entry.size);
    File? temp;
    try {
      final dir = await tempDir();
      temp = File('${dir.path}${Platform.pathSeparator}termul_unduh_${t.id}_${DateTime.now().microsecondsSinceEpoch}');
      final sink = temp.openWrite();
      try {
        await ops.download(entry.path, sink, onProgress: _throttled(t), cancel: t.cancel);
        await sink.flush();
      } finally {
        try {
          await sink.close();
        } on Object {
          // sink bisa sudah rusak setelah pembatalan atau galat; berkas sementara dihapus di bawah
        }
      }
      if (t.cancel.isCancelled) return TransferCancelled(entry.name);
      try {
        final saved = await saver.save(path: temp.path, name: saveAs ?? entry.name, overwrite: overwrite);
        return TransferDone(
          entry.name,
          location: saved.location,
          savedName: saved.name,
          overwritten: saved.overwritten,
        );
      } on DownloadSaveException {
        return TransferFailed(entry.name, SftpFailureKind.other, saveFailed: true);
      }
    } on SftpFailure catch (e) {
      return e.kind == SftpFailureKind.cancelled ? TransferCancelled(entry.name) : TransferFailed(entry.name, e.kind);
    } on Object {
      return t.cancel.isCancelled ? TransferCancelled(entry.name) : TransferFailed(entry.name, SftpFailureKind.other);
    } finally {
      link.transfers.finish(t);
      if (temp != null) {
        try {
          if (temp.existsSync()) temp.deleteSync();
        } on Object {
          // pembersihan terbaik-usaha
        }
      }
    }
  }

  /// Mengunggah [file] ke folder [dir] di server sebagai [remoteName] (bawaan: nama berkasnya; menimpa berkas bernama
  /// sama, pemanggil yang menanyakan). Berkas parsial di server dihapus bila dibatalkan atau gagal
  /// ([SftpService.upload]).
  Future<TransferOutcome> upload(XFile file, String dir, {String? remoteName}) async {
    final ops = _ops;
    final name = remoteName ?? file.name;
    if (ops == null) return TransferFailed(name, SftpFailureKind.other);
    int? total;
    try {
      total = await file.length();
    } on Object {
      total = null;
    }
    final t = link.transfers.start(name: name, upload: true, total: total);
    try {
      await ops.upload(joinRemote(dir, name), file.openRead(), onProgress: _throttled(t), cancel: t.cancel);
      return TransferDone(name);
    } on SftpFailure catch (e) {
      return e.kind == SftpFailureKind.cancelled ? TransferCancelled(name) : TransferFailed(name, e.kind);
    } on Object {
      return t.cancel.isCancelled ? TransferCancelled(name) : TransferFailed(name, SftpFailureKind.other);
    } finally {
      link.transfers.finish(t);
    }
  }
}
