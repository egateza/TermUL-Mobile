import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app_providers.dart' show ShellOpenerFor;
import '../../core/models/host_profile.dart';
import '../../core/platform/screen_monitor.dart';
import '../../core/ssh/connection_log.dart';
import '../../core/ssh/reconnect_backoff.dart';
import '../../core/ssh/ssh_connector.dart';
import '../../core/ssh/ssh_failure.dart';
import '../terminal/shell_channel.dart';
import '../terminal/terminal_session.dart';
import 'connect_flow.dart';
import 'keepalive_sync.dart';

/// Keadaan satu sesi menurut pengguna, dengan kata (bukan hanya warna) di UI.
enum SessionPhase {
  /// Sedang menyambung pertama kali (belum ada terminal).
  connecting,
  connected,
  reconnecting,

  /// Sambungan putus dan menunggu sambung ulang.
  lost,

  /// Butuh keputusan pengguna (host key, rahasia, atau prompt gagal) sebelum bisa tersambung.
  needsAttention,
}

/// Satu sesi terminal ke satu host, dari alur sambung sampai terminal: pemilik [ConnectFlow], sambungan SSH, dan
/// [TerminalSession]; mengawasi putusnya sambungan, menyambung ulang, dan mendaftarkan diri ke daftar sesi aktif
/// untuk foreground service. Tidak terikat ke layar: layar ([ConnectScreen]) hanya menampilkannya, sehingga sesi
/// bisa tetap hidup di latar belakang setelah layar ditutup dan dibuka lagi dari "Sesi aktif".
class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  SessionController({
    required this.id,
    required this.ordinal,
    required this.profile,
    required this.flow,
    required this._registry,
    required this._shellOpener,
    required this.reconnectedMarker,
    this.onEndedWhileDetached,
    DateTime? startedAt,
    this._probe = tcpProbe,
    this._backoff = const ReconnectBackoff(),
    this._screenMonitor = const NoopScreenMonitor(),
  }) : startedAt = startedAt ?? DateTime.now() {
    flow.addListener(_onFlow);
    _screenOffSub = _screenMonitor.onScreenOff.listen((_) => flow.releaseCredentials());
    WidgetsBinding.instance.addObserver(this);
  }

  final int id;

  /// Nomor sesi di antara sesi ke profil yang sama (1, 2, ...), supaya beberapa sesi ke host yang sama bisa dibedakan.
  final int ordinal;
  final HostProfile profile;
  final ConnectFlow flow;
  final DateTime startedAt;

  /// Penanda yang ditulis di terminal saat sambungan diganti (sudah dilokalkan).
  final String reconnectedMarker;

  /// Dipanggil bila sesi berakhir (mis. "Putuskan semua" di notifikasi) selagi tidak ada layar yang menampilkannya.
  final VoidCallback? onEndedWhileDetached;

  final ActiveSessionsNotifier _registry;
  final ShellOpenerFor _shellOpener;
  final HostProbe _probe;
  final ReconnectBackoff _backoff;
  final ScreenMonitor _screenMonitor;
  StreamSubscription<void>? _screenOffSub;

  /// Nilai [ScreenMonitor.screenOffCount] saat rahasia terakhir dibaca atau diperiksa. Bila sekarang berbeda, layar
  /// pernah mati sejak itu dan rahasia yang dipegang harus dibuang.
  int _screenOffBaseline = 0;

  // Rangkaian sambung ulang: probe jaringan, lalu sambung dengan rahasia yang dipegang (satu prompt biometrik).
  Timer? _retryTimer;
  Timer? _ticker;
  DateTime? _nextAttemptAt;
  int _attempts = 0;
  int _epoch = 0;
  bool _probing = false;

  TerminalSession? _session;
  SshConnection? _current;
  bool _lost = false;
  bool _registered = false;
  bool _attached = false;
  bool _ended = false;
  bool _disposed = false;
  DateTime? _backgroundSince;

  TerminalSession? get session => _session;
  bool get lost => _lost;

  /// Ada layar yang sedang menampilkan sesi ini.
  bool get attached => _attached;

  /// Pengguna atau notifikasi sudah menutup sesi ini.
  bool get ended => _ended;

  SessionPhase get phase {
    final state = flow.state;
    if (_session == null) {
      return switch (state) {
        ConnectPreparing() || ConnectConnecting() => SessionPhase.connecting,
        _ => SessionPhase.needsAttention,
      };
    }
    return switch (state) {
      ConnectDone() => _lost ? SessionPhase.lost : SessionPhase.connected,
      ConnectPreparing() || ConnectConnecting() => SessionPhase.reconnecting,
      ConnectFailed() || ConnectAuthDenied() => SessionPhase.lost,
      _ => SessionPhase.needsAttention,
    };
  }

  /// Sambungan pertama: satu prompt biometrik, lalu rahasia dipegang di memori selama layar tidak pernah mati
  /// (lihat [reconnect]).
  Future<void> start() async {
    _screenOffBaseline = await _readScreenOffCount();
    if (_disposed) return;
    await flow.start(holdCredentials: true);
  }

  Future<int> _readScreenOffCount() async {
    try {
      return await _screenMonitor.screenOffCount();
    } on Object {
      return _screenOffBaseline;
    }
  }

  /// Membuang rahasia yang dipegang bila layar pernah mati sejak terakhir diperiksa. Sambung ulang berikutnya lalu
  /// membaca vault lagi (prompt biometrik).
  Future<void> _dropCredentialsIfScreenWasOff() async {
    final count = await _readScreenOffCount();
    if (count == _screenOffBaseline) return;
    _screenOffBaseline = count;
    flow.releaseCredentials();
  }

  /// Layar mulai atau berhenti menampilkan sesi ini. Selama tidak ada layar, sambungan yang putus tidak disambung
  /// ulang otomatis (alurnya bisa memunculkan prompt biometrik di layar lain); sambung ulang terjadi saat sesi
  /// dibuka lagi (lihat [reconnect], dipanggil layar setelah frame pertama).
  void attach() => _attached = true;

  void detach() {
    _attached = false;
    _endSeries();
  }

  /// Sedang memeriksa apakah host terjangkau sebelum menyambung ulang.
  bool get probing => _probing;

  /// Detik sampai percobaan sambung ulang berikutnya, atau null bila tidak sedang menunggu.
  int? get secondsUntilRetry {
    final at = _nextAttemptAt;
    if (at == null) return null;
    final ms = at.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _register() {
    if (_registered) return;
    _registered = true;
    _registry.register(ActiveSession(id: id, name: profile.name, disconnect: disconnectFromNotification));
  }

  /// Mencabut pendaftaran. Saat dipanggil dari [dispose], perubahan state provider ditunda ke microtask supaya tidak
  /// terjadi di tengah pembongkaran pohon widget (dan diabaikan bila kontainer sudah dibuang).
  void _unregister({bool defer = false}) {
    if (!_registered) return;
    _registered = false;
    if (!defer) {
      _registry.unregister(id);
      return;
    }
    scheduleMicrotask(() {
      try {
        _registry.unregister(id);
      } on Object {
        // Kontainer provider sudah dibuang (aplikasi ditutup): tidak ada yang perlu dicabut.
      }
    });
  }

  /// "Putuskan semua" di notifikasi atau tombol Putuskan di daftar sesi aktif: menutup sambungan segera (juga saat
  /// aplikasi di latar belakang, jadi tidak bergantung pada penggambaran layar).
  void disconnectFromNotification() {
    if (_ended) return;
    connLog('putus atas permintaan pengguna');
    _endSeries();
    flow.releaseCredentials();
    _current?.close();
    _unregister();
    _ended = true;
    notifyListeners();
    if (!_attached) onEndedWhileDetached?.call();
  }

  /// Tersambung (pertama kali atau setelah sambung ulang): pasang sambungan ke sesi terminal dan awasi putusnya.
  void _onFlow() {
    final state = flow.state;
    if (_disposed) return;
    if (state is ConnectDone && !identical(state.connection, _current)) {
      final connection = state.connection;
      final previous = _current;
      _current = connection;
      _lost = false;
      _register();
      previous?.close();
      unawaited(connection.closed.then((reason) => _onClosed(connection, reason)));
      Future<ShellChannel> open({required int columns, required int rows}) =>
          _shellOpener(connection, columns: columns, rows: rows);
      final session = _session;
      if (session == null) {
        _session = TerminalSession(open: open);
      } else {
        unawaited(session.restart(open, marker: reconnectedMarker));
      }
    }
    notifyListeners();
  }

  void _onClosed(SshConnection connection, CloseReason reason) {
    if (_disposed || !identical(connection, _current) || reason == CloseReason.userClosed || _lost) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final since = _backgroundSince;
    connLog(
      'sambungan putus: alasan=${reason.name}, siklus=${lifecycle?.name}, '
      'di latar belakang ${since == null ? '-' : '${DateTime.now().difference(since).inSeconds} dtk'}',
    );
    _unregister();
    _lost = true;
    notifyListeners();
    // `null` = belum ada pesan siklus hidup (aplikasi baru mulai): anggap terlihat.
    if (_attached && (lifecycle == null || lifecycle == AppLifecycleState.resumed)) reconnect();
  }

  /// Menyambung ulang memakai alur yang sama dengan sambungan pertama (host key diperiksa lagi; host key yang
  /// berubah tetap memblokir dan butuh keputusan pengguna).
  ///
  /// Rahasia: dibaca dari vault (prompt biometrik) saat sambungan pertama lalu dipegang di memori. Selama layar tidak
  /// pernah mati sejak itu (pengguna masih memakai aplikasi), sambung ulang memakainya tanpa prompt. Layar mati
  /// melepas rahasia ([ScreenMonitor]), jadi sambung ulang berikutnya minta biometrik lagi.
  ///
  /// Sebelum menyambung, host diperiksa lewat probe TCP. Bila belum terjangkau (mis. mode pesawat), percobaan diulang
  /// dengan jeda bertingkat ([ReconnectBackoff]) dan tidak ada prompt. Dipanggil juga oleh tombol "Sambung
  /// sekarang": menggantikan hitungan mundur yang sedang jalan.
  ///
  /// [manual] true untuk tombol "Sambung sekarang" / "Tampilkan prompt". Pemicu otomatis (sambungan putus, aplikasi
  /// terlihat lagi) tidak memunculkan prompt lagi setelah prompt dibatalkan atau gagal ([needsAuth]): pengguna yang
  /// memintanya lewat tombol, supaya mengetuk di luar prompt tidak membuat prompt muncul berulang.
  void reconnect({bool manual = false}) {
    if (_disposed || _ended || !_lost) return;
    final state = flow.state;
    if (state is ConnectPreparing || state is ConnectConnecting || state is ConnectNeedsHostKey) return;
    if (_probing) return;
    if (!manual && state is ConnectAuthDenied) return;
    _stopTimers();
    unawaited(_attempt(++_epoch, manual: manual));
  }

  /// Sambung ulang menunggu pengguna menampilkan prompt biometrik (prompt sebelumnya dibatalkan atau gagal).
  bool get needsAuth => _lost && flow.state is ConnectAuthDenied;

  bool _stale(int epoch) => _disposed || _ended || !_attached || epoch != _epoch;

  Future<void> _attempt(int epoch, {bool manual = false}) async {
    _probing = true;
    notifyListeners();
    final reachable = await _probe(profile.host, profile.port);
    _probing = false;
    if (_stale(epoch)) {
      notifyListeners();
      return;
    }
    if (!reachable) {
      connLog('sambung ulang: host belum terjangkau (percobaan ${_attempts + 1})');
      _scheduleRetry(epoch);
      return;
    }
    // Layar pernah mati sejak rahasia dibaca: buang, sehingga alur di bawah membaca vault lagi (prompt biometrik).
    await _dropCredentialsIfScreenWasOff();
    if (_stale(epoch)) return;
    await flow.start(holdCredentials: true, manual: manual);
    if (_stale(epoch)) return;
    final state = flow.state;
    if (state is ConnectFailed && state.failure is SshNetworkFailure) {
      connLog('sambung ulang: gagal jaringan (percobaan ${_attempts + 1})');
      _scheduleRetry(epoch);
      return;
    }
    // Tersambung (rahasia tetap dipegang untuk putus berikutnya), atau butuh keputusan pengguna, atau galat yang
    // tidak akan sembuh dengan rahasia yang sama (login ditolak, kunci rusak, host key ditolak): buang rahasia.
    if (state is! ConnectDone) flow.releaseCredentials();
    _endSeries();
  }

  void _scheduleRetry(int epoch) {
    final delay = _backoff.delayAfter(_attempts++);
    _nextAttemptAt = DateTime.now().add(delay);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    _retryTimer = Timer(delay, () {
      _stopTimers();
      if (_stale(epoch)) return;
      // Di latar belakang tidak menyambung (bisa memunculkan prompt biometrik); dilanjutkan saat aplikasi terlihat.
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

  /// Mengakhiri rangkaian sambung ulang: menghentikan hitungan dan membatalkan percobaan yang sedang menunggu.
  /// Rahasia yang dipegang tidak disentuh (dilepas oleh layar mati, galat yang tidak sembuh sendiri, atau sesi ditutup).
  void _endSeries() {
    _epoch++;
    _stopTimers();
    _attempts = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state != AppLifecycleState.resumed) {
      _backgroundSince ??= DateTime.now();
      connLog('siklus: ${state.name}');
      return;
    }
    final since = _backgroundSince;
    _backgroundSince = null;
    unawaited(_dropCredentialsIfScreenWasOff());
    connLog(
      'siklus: resumed setelah ${since == null ? '-' : '${DateTime.now().difference(since).inSeconds} dtk'}, '
      'sambungan ${_lost ? 'sudah putus' : 'dianggap hidup'}',
    );
    final connection = _current;
    if (connection == null) return;
    if (_lost) {
      if (_attached) reconnect(); // putus selagi di latar belakang: sambung ulang sekarang aplikasi terlihat lagi
      return;
    }
    // Android mematikan soket aplikasi di latar belakang tanpa memberi tahu; periksa sebelum dipakai (spike A4).
    unawaited(
      connection.checkAlive().then((alive) {
        connLog('pemeriksaan sambungan setelah kembali: ${alive ? 'hidup' : 'mati'}');
        if (alive || _disposed || !identical(connection, _current) || _lost) return;
        connection.close();
        _onClosed(connection, CloseReason.error);
      }),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopTimers();
    unawaited(_screenOffSub?.cancel());
    _unregister(defer: true);
    WidgetsBinding.instance.removeObserver(this);
    flow.removeListener(_onFlow);
    final state = flow.state;
    if (state is ConnectDone) state.connection.close();
    flow.dispose();
    _current?.close();
    _session?.dispose();
    super.dispose();
  }
}
