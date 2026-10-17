import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/models/host_profile.dart';
import '../../core/platform/screen_monitor.dart';
import '../../core/sftp/sftp_service.dart';
import '../../core/ssh/connection_log.dart';
import '../../core/ssh/reconnect_backoff.dart';
import '../../core/ssh/ssh_connector.dart';
import '../../core/ssh/ssh_failure.dart';
import '../connect/connect_flow.dart';
import '../connect/session_controller.dart';
import 'sftp_transfers.dart';

/// Membuka kanal SFTP pada sambungan SSH. Diganti di tes.
typedef SftpOpener = Future<SftpBrowsing> Function(SshConnection connection);

Future<SftpBrowsing> _openSftp(SshConnection connection) async => SftpService(await connection.client.sftp());

/// Sambungan yang dipakai SFTP. Dua cara (seperti TermUL desktop):
/// - [SftpLink.own]: koneksi SSH sendiri lewat [ConnectFlow] (rahasia dari vault, verifikasi host key). Ditutup
///   bersama layar SFTP. Bila putus, **disambung ulang dengan mekanisme yang sama dengan terminal** (lihat
///   [reconnect]).
/// - [SftpLink.borrowed]: meminjam sambungan sesi terminal. Sambungan itu **tidak** ditutup di sini; hanya kanal
///   SFTP-nya. Bila sesinya putus, sesi itu yang menyambung ulang, dan kanal SFTP dibuka lagi di sambungan barunya.
///
/// Selama [service] null, sambungan belum pernah siap: untuk `own` lihat [flow] (menyambung, host key, gagal).
/// Setelah siap, [lost] true bila sambungan SSH-nya tertutup (mis. Android memutus soket di latar belakang);
/// [service] lama tetap ada supaya daftar folder tetap terlihat sampai sambungan baru siap.
class SftpLink extends ChangeNotifier with WidgetsBindingObserver {
  SftpLink.own({
    required this.profile,
    required ConnectFlow this.flow,
    this._probe = tcpProbe,
    this._backoff = const ReconnectBackoff(),
    this._screenMonitor = const NoopScreenMonitor(),
    bool Function()? autoReconnect,
    SftpOpener? opener,
  }) : session = null,
       _autoReconnect = autoReconnect ?? _alwaysOn,
       _opener = opener ?? _openSftp {
    WidgetsBinding.instance.addObserver(this);
    _screenOffSub = _screenMonitor.onScreenOff.listen((_) => flow?.releaseCredentials());
  }

  SftpLink.borrowed({required SessionController this.session, SftpOpener? opener})
    : profile = session.profile,
      flow = null,
      _probe = tcpProbe,
      _backoff = const ReconnectBackoff(),
      _screenMonitor = const NoopScreenMonitor(),
      _autoReconnect = _alwaysOn,
      _opener = opener ?? _openSftp;

  /// Hanya untuk tes: sudah siap dengan [service] tiruan, tanpa sambungan SSH.
  @visibleForTesting
  SftpLink.ready({required this.profile, required SftpBrowsing service})
    : flow = null,
      session = null,
      _probe = tcpProbe,
      _backoff = const ReconnectBackoff(),
      _screenMonitor = const NoopScreenMonitor(),
      _autoReconnect = _alwaysOn,
      _opener = _openSftp {
    _service = service;
  }

  static bool _alwaysOn() => true;

  final HostProfile profile;

  /// Alur sambung untuk koneksi sendiri; null bila meminjam sesi.
  final ConnectFlow? flow;

  /// Sesi terminal yang dipinjam; null untuk koneksi sendiri.
  final SessionController? session;

  final HostProbe _probe;
  final ReconnectBackoff _backoff;
  final ScreenMonitor _screenMonitor;
  final bool Function() _autoReconnect;
  final SftpOpener _opener;
  StreamSubscription<void>? _screenOffSub;

  /// Transfer yang sedang berjalan di sambungan ini; dibaca untuk konfirmasi keluar.
  final transfers = SftpTransferTracker();

  SftpBrowsing? _service;
  SshConnection? _connection;
  bool _lost = false;
  bool _opening = false;
  bool _disposed = false;
  Object? _openError;

  // Rangkaian sambung ulang (koneksi sendiri), sama dengan SessionController.
  Timer? _retryTimer;
  Timer? _ticker;
  DateTime? _nextAttemptAt;
  int _attempts = 0;
  int _epoch = 0;
  bool _probing = false;
  int _screenOffBaseline = 0;

  /// Folder yang sedang dibuka saat layar ditutup dengan "Tetap terhubung", dan riwayat folder sebelumnya, supaya
  /// penjelajah yang dibuka lagi melanjutkan dari sana.
  String? resumePath;
  List<String> resumeHistory = const [];

  SftpBrowsing? get service => _service;
  bool get lost => _lost;
  bool get isOwn => flow != null;

  /// Galat saat membuka kanal SFTP (mis. server tidak mengaktifkan subsistem `sftp`); null bila tidak ada.
  Object? get openError => _openError;

  /// Sedang memeriksa apakah host terjangkau sebelum menyambung ulang.
  bool get probing => _probing;

  /// Detik sampai percobaan sambung ulang berikutnya, atau null bila tidak sedang menunggu.
  int? get secondsUntilRetry {
    final at = _nextAttemptAt;
    if (at == null) return null;
    final ms = at.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Sedang menyambung ulang (probe atau login berjalan) setelah putus.
  bool get reconnecting {
    final f = flow;
    if (f == null || !_lost) return false;
    final s = f.state;
    return _probing || s is ConnectPreparing || s is ConnectConnecting;
  }

  /// Sambung ulang menunggu pengguna menampilkan prompt biometrik (prompt sebelumnya dibatalkan atau gagal).
  bool get needsAuth => _lost && flow?.state is ConnectAuthDenied;

  /// Hanya untuk tes: menandai sambungan putus seperti saat soketnya ditutup Android.
  @visibleForTesting
  void markLost() {
    _lost = true;
    notifyListeners();
  }

  Future<void> start() async {
    final f = flow;
    if (f == null) {
      final s = session;
      if (s != null) {
        s.addListener(_syncBorrowed);
        _syncBorrowed();
      }
      return;
    }
    f.addListener(_onFlow);
    _lost = false;
    _openError = null;
    notifyListeners();
    _screenOffBaseline = await _readScreenOffCount();
    if (_disposed) return;
    await f.start(holdCredentials: true);
  }

  /// Tombol "Coba lagi" dan "Sambung sekarang": pengguna yang memintanya, jadi prompt boleh muncul.
  Future<void> retry() async {
    final f = flow;
    if (f == null) return;
    if (_lost) {
      reconnect(manual: true);
      return;
    }
    if (_service != null) {
      // Operasi gagal karena sambungan mati sebelum penutupan soket tercatat: anggap putus dan sambung ulang.
      _lost = true;
      transfers.cancelAll();
      _connection?.close();
      notifyListeners();
      reconnect(manual: true);
      return;
    }
    _openError = null;
    notifyListeners();
    await f.start(holdCredentials: true);
  }

  /// Menyambung ulang memakai alur yang sama dengan sambungan pertama: host key diperiksa lagi (yang berubah tetap
  /// memblokir), rahasia yang dipegang di memori dipakai tanpa prompt selama layar tidak pernah mati, dan sebelum
  /// menyambung host diperiksa lewat probe TCP. Bila belum terjangkau (mis. mode pesawat), percobaan diulang dengan
  /// jeda bertingkat tanpa prompt.
  ///
  /// [manual] true untuk tombol "Sambung sekarang" atau "Tampilkan prompt". Pemicu otomatis (sambungan putus,
  /// aplikasi terlihat lagi) tidak memunculkan prompt lagi setelah prompt dibatalkan ([needsAuth]).
  void reconnect({bool manual = false}) {
    final f = flow;
    if (_disposed || f == null || !_lost) return;
    // Pengaturan mati: hanya tombol yang menyambung ulang.
    if (!manual && !_autoReconnect()) return;
    final state = f.state;
    if (state is ConnectPreparing || state is ConnectConnecting || state is ConnectNeedsHostKey) return;
    if (_probing) return;
    if (!manual && state is ConnectAuthDenied) return;
    _stopTimers();
    unawaited(_attempt(++_epoch, manual: manual));
  }

  bool _stale(int epoch) => _disposed || epoch != _epoch;

  Future<void> _attempt(int epoch, {bool manual = false}) async {
    final f = flow!;
    _probing = true;
    notifyListeners();
    final reachable = await _probe(profile.host, profile.port);
    _probing = false;
    if (_stale(epoch)) {
      notifyListeners();
      return;
    }
    if (!reachable) {
      connLog('sftp: sambung ulang, host belum terjangkau (percobaan ${_attempts + 1})');
      _scheduleRetry(epoch);
      return;
    }
    // Layar pernah mati sejak rahasia dibaca: buang, sehingga alur membaca vault lagi (prompt biometrik).
    await _dropCredentialsIfScreenWasOff();
    if (_stale(epoch)) return;
    await f.start(holdCredentials: true, manual: manual);
    if (_stale(epoch)) return;
    final state = f.state;
    if (state is ConnectFailed && state.failure is SshNetworkFailure) {
      connLog('sftp: sambung ulang gagal jaringan (percobaan ${_attempts + 1})');
      _scheduleRetry(epoch);
      return;
    }
    // Tersambung, butuh keputusan pengguna, atau galat yang tidak sembuh dengan rahasia yang sama: buang rahasia.
    if (state is! ConnectDone) f.releaseCredentials();
    _endSeries();
  }

  void _scheduleRetry(int epoch) {
    final delay = _backoff.delayAfter(_attempts++);
    _nextAttemptAt = DateTime.now().add(delay);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    _retryTimer = Timer(delay, () {
      _stopTimers();
      if (_stale(epoch)) return;
      if (!_autoReconnect()) {
        _endSeries();
        notifyListeners();
        return;
      }
      // Di latar belakang tidak menyambung (bisa memunculkan prompt biometrik); dilanjutkan saat terlihat lagi.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        notifyListeners();
        return;
      }
      unawaited(_attempt(epoch));
    });
    notifyListeners();
  }

  void _stopTimers() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _ticker?.cancel();
    _ticker = null;
    _nextAttemptAt = null;
  }

  void _endSeries() {
    _epoch++;
    _stopTimers();
    _attempts = 0;
  }

  Future<int> _readScreenOffCount() async {
    try {
      return await _screenMonitor.screenOffCount();
    } on Object {
      return _screenOffBaseline;
    }
  }

  Future<void> _dropCredentialsIfScreenWasOff() async {
    final count = await _readScreenOffCount();
    if (count == _screenOffBaseline) return;
    _screenOffBaseline = count;
    flow?.releaseCredentials();
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

  /// Sesi yang dipinjam berubah: sambungan baru (setelah sambung ulang sesi) dibuka lagi kanal SFTP-nya; sesi
  /// putus atau berakhir menandai sambungan putus.
  void _syncBorrowed() {
    final s = session;
    if (_disposed || s == null) return;
    final connection = s.connection;
    if (s.ended || s.lost || connection == null || connection.isClosed) {
      if (_service != null && !_lost) {
        _lost = true;
        transfers.cancelAll();
      }
      notifyListeners();
      return;
    }
    if (!identical(connection, _connection)) {
      unawaited(_open(connection));
    } else {
      notifyListeners();
    }
  }

  Future<void> _open(SshConnection connection) async {
    if (_opening) return;
    _opening = true;
    final previousConnection = _connection;
    try {
      final opened = await _opener(connection);
      if (_disposed) {
        if (opened is SftpService) opened.close();
        return;
      }
      _closeService();
      _service = opened;
      _connection = connection;
      if (isOwn) previousConnection?.close();
      _openError = null;
      _lost = false;
      _endSeries();
      unawaited(connection.closed.then((reason) => _onClosed(connection, reason)));
    } on Object catch (e) {
      _openError = e;
    } finally {
      _opening = false;
    }
    if (!_disposed) notifyListeners();
  }

  void _onClosed(SshConnection connection, CloseReason reason) {
    if (_disposed || !identical(_connection, connection) || reason == CloseReason.userClosed || _lost) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    connLog('sftp: sambungan putus, alasan=${reason.name}, siklus=${lifecycle?.name}');
    _lost = true;
    transfers.cancelAll();
    notifyListeners();
    // `null` = belum ada pesan siklus hidup (aplikasi baru mulai): anggap terlihat.
    if (isOwn && (lifecycle == null || lifecycle == AppLifecycleState.resumed)) reconnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !isOwn || state != AppLifecycleState.resumed) return;
    unawaited(_dropCredentialsIfScreenWasOff());
    final connection = _connection;
    if (connection == null) return;
    if (_lost) {
      reconnect(); // putus selagi di latar belakang: sambung ulang sekarang aplikasi terlihat lagi
      return;
    }
    // Android mematikan soket aplikasi di latar belakang tanpa memberi tahu; periksa sebelum dipakai.
    unawaited(
      connection.checkAlive().then((alive) {
        if (alive || _disposed || !identical(connection, _connection) || _lost) return;
        connection.close();
        _onClosed(connection, CloseReason.error);
      }),
    );
  }

  void _closeService() {
    final s = _service;
    if (s is SftpService) s.close();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopTimers();
    if (isOwn) WidgetsBinding.instance.removeObserver(this);
    unawaited(_screenOffSub?.cancel());
    session?.removeListener(_syncBorrowed);
    final f = flow;
    f?.removeListener(_onFlow);
    transfers.cancelAll();
    _closeService();
    if (f != null) {
      final state = f.state;
      if (state is ConnectDone) state.connection.close();
      _connection?.close();
      f.dispose();
    }
    transfers.dispose();
    super.dispose();
  }
}
