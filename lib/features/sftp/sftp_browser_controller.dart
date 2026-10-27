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
  final _selected = <String>{};
  bool _disposed = false;

  /// Folder yang dikunjungi sebelum folder aktif (yang terakhir di ujung), untuk [back]. Muat ulang tidak menambah.
  final _history = <String>[];

  /// Menghindari balapan: hasil muatan lama dibuang bila pengguna sudah membuka folder lain.
  int _epoch = 0;

  String get path => _path;
  List<SftpEntry> get entries => _entries;
  bool get loading => _loading;
  SftpFailure? get failure => _failure;

  /// Entri yang dipilih, urut seperti di daftar. Ada pilihan berarti mode seleksi aktif: ketukan menambah atau
  /// mencabut pilihan, bukan membuka folder.
  List<SftpEntry> get selection => [
    for (final e in _entries)
      if (_selected.contains(e.path)) e,
  ];

  bool get hasSelection => _selected.isNotEmpty;

  bool isSelected(SftpEntry entry) => _selected.contains(entry.path);

  /// Jumlah entri dipilih, folder ikut dihitung.
  int get selectionCount => _selected.length;

  /// Total ukuran berkas yang dipilih. Folder tidak dihitung (ukurannya tidak diketahui tanpa menelusurinya).
  int get selectionBytes => selection.where((e) => !e.isDirectory).fold(0, (sum, e) => sum + (e.size ?? 0));

  bool get allSelected => _entries.isNotEmpty && _selected.length == _entries.length;

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

  /// Ada folder sebelumnya untuk kembali.
  bool get canGoBack => _history.isNotEmpty;

  /// Salinan riwayat (untuk dipindahkan ke penjelajah baru setelah sambung ulang).
  List<String> get history => List.unmodifiable(_history);

  /// Membuka folder rumah (awal). Dengan [restore] (setelah sambung ulang) mencoba folder itu dulu; bila tidak bisa
  /// dibuka (hilang, izin berubah), jatuh ke folder rumah.
  Future<void> start({String? restore, List<String> history = const []}) async {
    final epoch = ++_epoch;
    _begin();
    _history
      ..clear()
      ..addAll(history);
    try {
      if (restore != null) {
        try {
          final list = await _sftp.list(restore);
          if (epoch != _epoch) return;
          _path = restore;
          _entries = list;
          _selected.clear();
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
    await _load(path, epoch, pushFrom: path == _path ? null : _path);
  }

  /// Kembali ke folder yang dikunjungi sebelumnya (bukan selalu folder induk: setelah melompat lewat breadcrumb,
  /// kembali ke tempat asal lompatan). Mengembalikan false bila tidak ada riwayat. Bila folder itu gagal dibuka,
  /// riwayat tidak berubah.
  Future<bool> back() async {
    if (_history.isEmpty) return false;
    final epoch = ++_epoch;
    _begin();
    await _load(_history.last, epoch, popHistory: true);
    return true;
  }

  Future<void> up() => open(parentRemote(_path));

  Future<void> refresh() => open(_path);

  /// Menambah entri ke pilihan, atau mencabutnya bila sudah dipilih.
  void toggle(SftpEntry entry) {
    if (!_selected.remove(entry.path)) _selected.add(entry.path);
    _notify();
  }

  /// Hanya [entry] yang dipilih (sentuh singkat saat pilihan tunggal: pilihan pindah).
  void selectOnly(SftpEntry entry) {
    if (_selected.length == 1 && _selected.contains(entry.path)) return;
    _selected
      ..clear()
      ..add(entry.path);
    _notify();
  }

  /// Memilih semua entri di folder ini.
  void selectAll() {
    _selected
      ..clear()
      ..addAll(_entries.map((e) => e.path));
    _notify();
  }

  /// Melepas pilihan (setelah aksi dijalankan atau mode seleksi dibatalkan).
  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _notify();
  }

  void _begin() {
    _loading = true;
    _failure = null;
    _notify();
  }

  Future<void> _load(String path, int epoch, {String? pushFrom, bool popHistory = false}) async {
    try {
      final list = await _sftp.list(path);
      if (epoch != _epoch) return;
      if (popHistory && _history.isNotEmpty) _history.removeLast();
      if (pushFrom != null) _history.add(pushFrom);
      _path = path;
      _entries = list;
      _selected.clear();
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
