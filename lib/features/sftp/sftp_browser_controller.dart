import 'package:flutter/foundation.dart';

import '../../core/sftp/sftp_service.dart';

/// Keadaan penjelajah folder SFTP: folder yang sedang dibuka, isinya, dan entri yang dipilih. Tanpa UI sehingga
/// bisa dites. Membuka folder yang gagal (izin ditolak, tidak ada) tidak mengubah folder aktif; galatnya
/// disimpan di [failure] dan dihapus oleh operasi berikutnya.
class SftpBrowserController extends ChangeNotifier {
  SftpBrowserController(this._sftp);

  final SftpBrowsing _sftp;

  String _path = '/';
  List<SftpEntry> _entries = const [];
  bool _loading = false;
  SftpFailure? _failure;
  SftpEntry? _selected;
  bool _disposed = false;

  /// Menghindari balapan: hasil muatan lama dibuang bila pengguna sudah membuka folder lain.
  int _epoch = 0;

  String get path => _path;
  List<SftpEntry> get entries => _entries;
  bool get loading => _loading;
  SftpFailure? get failure => _failure;
  SftpEntry? get selected => _selected;

  /// Bagian jalur untuk breadcrumb: `/etc/nginx` menjadi `[('/', '/'), ('etc', '/etc'), ('nginx', '/etc/nginx')]`.
  List<(String, String)> get crumbs {
    final out = <(String, String)>[('/', '/')];
    var acc = '';
    for (final part in _path.split('/')) {
      if (part.isEmpty) continue;
      acc = '$acc/$part';
      out.add((part, acc));
    }
    return out;
  }

  bool get atRoot => _path == '/';

  /// Membuka folder rumah (awal). Dengan [restore] (setelah sambung ulang) mencoba folder itu dulu; bila tidak bisa
  /// dibuka (hilang, izin berubah), jatuh ke folder rumah.
  Future<void> start({String? restore}) async {
    final epoch = ++_epoch;
    _begin();
    try {
      if (restore != null) {
        try {
          final list = await _sftp.list(restore);
          if (epoch != _epoch) return;
          _path = restore;
          _entries = list;
          _selected = null;
          _loading = false;
          _notify();
          return;
        } on Object {
          if (epoch != _epoch) return;
        }
      }
      final home = await _sftp.home();
      if (epoch != _epoch) return;
      await _load(home, epoch);
    } on SftpFailure catch (e) {
      _fail(e, epoch);
    }
  }

  Future<void> open(String path) async {
    final epoch = ++_epoch;
    _begin();
    await _load(path, epoch);
  }

  Future<void> up() => open(parentRemote(_path));

  Future<void> refresh() => open(_path);

  void select(SftpEntry? entry) {
    _selected = identical(_selected, entry) ? null : entry;
    _notify();
  }

  /// Melepas pilihan (setelah aksi pada berkas dijalankan).
  void clearSelection() {
    if (_selected == null) return;
    _selected = null;
    _notify();
  }

  void _begin() {
    _loading = true;
    _failure = null;
    _notify();
  }

  Future<void> _load(String path, int epoch) async {
    try {
      final list = await _sftp.list(path);
      if (epoch != _epoch) return;
      _path = path;
      _entries = list;
      _selected = null;
      _loading = false;
      _notify();
    } on SftpFailure catch (e) {
      _fail(e, epoch);
    } on Object catch (e) {
      _fail(SftpFailure(SftpFailureKind.other, 'Operasi SFTP gagal', e), epoch);
    }
  }

  void _fail(SftpFailure e, int epoch) {
    if (epoch != _epoch) return;
    _failure = e;
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
