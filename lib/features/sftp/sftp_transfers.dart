import 'package:flutter/foundation.dart';

import '../../core/sftp/sftp_service.dart';

/// Satu transfer yang sedang berjalan. [total] null bila ukurannya belum diketahui.
class SftpTransfer {
  SftpTransfer({required this.id, required this.name, required this.upload, this.total, SftpCancelToken? cancel})
    : cancel = cancel ?? SftpCancelToken();

  final int id;
  final String name;
  final bool upload;
  final int? total;
  final SftpCancelToken cancel;
  int done = 0;

  /// 0 sampai 100, atau null bila total belum diketahui.
  int? get percent => total == null || total == 0 ? null : (done * 100 ~/ total!).clamp(0, 100);
}

/// Daftar transfer aktif satu sambungan SFTP. Layar membacanya untuk memutuskan isi konfirmasi keluar, dan
/// [cancelAll] menghentikan semuanya (berkas parsial dibersihkan oleh `SftpService`).
class SftpTransferTracker extends ChangeNotifier {
  final _active = <SftpTransfer>[];
  int _nextId = 0;

  List<SftpTransfer> get active => List.unmodifiable(_active);
  bool get isBusy => _active.isNotEmpty;

  SftpTransfer start({required String name, required bool upload, int? total}) {
    final t = SftpTransfer(id: _nextId++, name: name, upload: upload, total: total);
    _active.add(t);
    notifyListeners();
    return t;
  }

  void progress(SftpTransfer t, int bytes) {
    t.done = bytes;
    notifyListeners();
  }

  void finish(SftpTransfer t) {
    if (_active.remove(t)) notifyListeners();
  }

  void cancelAll() {
    for (final t in List.of(_active)) {
      t.cancel.cancel();
    }
  }
}
