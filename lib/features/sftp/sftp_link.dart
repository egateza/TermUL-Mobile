import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/host_profile.dart';
import '../../core/sftp/sftp_service.dart';
import '../../core/ssh/ssh_connector.dart';
import '../connect/connect_flow.dart';
import 'sftp_transfers.dart';

/// Sambungan yang dipakai SFTP. Dua cara (seperti TermUL desktop):
/// - [SftpLink.own]: koneksi SSH sendiri lewat [ConnectFlow] (rahasia dari vault, verifikasi host key). Ditutup
///   bersama layar SFTP.
/// - [SftpLink.borrowed]: meminjam sambungan sesi terminal yang sedang hidup. Sambungan itu **tidak** ditutup di
///   sini; hanya kanal SFTP-nya.
///
/// Selama [service] null, sambungan belum siap: untuk `own` lihat [flow] (menyambung, host key, gagal). Setelah
/// siap, [lost] true bila sambungan SSH-nya tertutup (mis. Android memutus soket di latar belakang).
class SftpLink extends ChangeNotifier {
  SftpLink.own({required this.profile, required ConnectFlow this.flow}) : _borrowed = null;

  SftpLink.borrowed({required this.profile, required SshConnection connection}) : flow = null, _borrowed = connection;

  /// Hanya untuk tes: sudah siap dengan [service] tiruan, tanpa sambungan SSH.
  @visibleForTesting
  SftpLink.ready({required this.profile, required SftpBrowsing service}) : flow = null, _borrowed = null {
    _service = service;
  }

  final HostProfile profile;

  /// Alur sambung untuk koneksi sendiri; null bila meminjam sesi.
  final ConnectFlow? flow;
  final SshConnection? _borrowed;

  /// Transfer yang sedang berjalan di sambungan ini; dibaca untuk konfirmasi keluar.
  final transfers = SftpTransferTracker();

  SftpBrowsing? _service;
  SshConnection? _connection;
  bool _lost = false;
  bool _opening = false;
  bool _disposed = false;
  Object? _openError;

  SftpBrowsing? get service => _service;
  bool get lost => _lost;
  bool get isOwn => flow != null;

  /// Galat saat membuka kanal SFTP (mis. server tidak mengaktifkan subsistem `sftp`); null bila tidak ada.
  Object? get openError => _openError;

  /// Hanya untuk tes: menandai sambungan putus seperti saat soketnya ditutup Android.
  @visibleForTesting
  void markLost() {
    _lost = true;
    notifyListeners();
  }

  Future<void> start() async {
    final f = flow;
    if (f == null) {
      final b = _borrowed;
      if (b != null) await _open(b);
      return;
    }
    f.addListener(_onFlow);
    _lost = false;
    _openError = null;
    notifyListeners();
    await f.start();
  }

  /// Menyambung ulang koneksi sendiri setelah putus atau gagal (satu prompt biometrik bila rahasia tidak dipegang).
  Future<void> reconnect() async {
    final f = flow;
    if (f == null) return;
    transfers.cancelAll();
    _closeService();
    _service = null;
    _connection?.close();
    _connection = null;
    _lost = false;
    _openError = null;
    notifyListeners();
    await f.start();
  }

  void _closeService() {
    final s = _service;
    if (s is SftpService) s.close();
  }

  void _onFlow() {
    if (_disposed) return;
    final state = flow!.state;
    if (state is ConnectDone && !identical(state.connection, _connection)) {
      unawaited(_open(state.connection));
    } else {
      notifyListeners();
    }
  }

  Future<void> _open(SshConnection connection) async {
    if (_opening) return;
    _opening = true;
    try {
      final client = await connection.client.sftp();
      if (_disposed) {
        client.close();
        return;
      }
      _connection = connection;
      _service = SftpService(client);
      _openError = null;
      unawaited(
        connection.closed.then((_) {
          if (_disposed || !identical(_connection, connection)) return;
          _lost = true;
          notifyListeners();
        }),
      );
    } on Object catch (e) {
      _openError = e;
    } finally {
      _opening = false;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final f = flow;
    f?.removeListener(_onFlow);
    transfers.cancelAll();
    _closeService();
    if (f != null) {
      final state = f.state;
      if (state is ConnectDone) state.connection.close();
      f.dispose();
    }
    transfers.dispose();
    super.dispose();
  }
}
