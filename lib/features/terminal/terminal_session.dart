import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import 'key_codes.dart';
import 'shell_channel.dart';

enum TerminalSessionState {
  /// Belum dibuka atau sedang membuka shell.
  opening,

  /// Shell berjalan.
  running,

  /// Shell selesai (pengguna mengetik `exit`, atau sambungan putus).
  ended,

  /// Shell tidak bisa dibuka.
  failed,
}

/// Satu sesi terminal: `Terminal` (xterm) yang tersambung ke [ShellChannel]. Menangani aliran UTF-8, pengubah
/// Ctrl dan Alt sekali pakai, dan pengiriman ukuran setelah tampilan diam. Semua sumber daya ditutup di
/// [dispose]. Tanpa UI sehingga bisa dites.
class TerminalSession extends ChangeNotifier {
  TerminalSession({required this.open, this.maxLines = 10000, this.resizeDebounce = const Duration(milliseconds: 150)})
    : terminal = Terminal(maxLines: maxLines) {
    terminal.onOutput = _onOutput;
    terminal.onResize = (width, height, pixelWidth, pixelHeight) => _scheduleResize();
  }

  final ShellOpener open;
  final int maxLines;
  final Duration resizeDebounce;
  final Terminal terminal;

  ShellChannel? _channel;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  Timer? _resizeTimer;
  TerminalSessionState _state = TerminalSessionState.opening;
  bool _ctrl = false;
  bool _alt = false;
  bool _disposed = false;

  TerminalSessionState get state => _state;

  bool get ctrl => _ctrl;

  bool get alt => _alt;

  /// Membuka shell dengan ukuran yang sedang terpasang pada [terminal]. Panggil setelah tampilan terminal
  /// melakukan layout pertama supaya PTY langsung berukuran benar.
  Future<void> start() async {
    if (_channel != null || _disposed) return;
    _setState(TerminalSessionState.opening);
    final ShellChannel channel;
    try {
      channel = await open(columns: terminal.viewWidth, rows: terminal.viewHeight);
    } on Object {
      _setState(TerminalSessionState.failed);
      return;
    }
    if (_disposed) {
      channel.close();
      return;
    }
    _channel = channel;
    _stdout = _decode(channel.stdout).listen(terminal.write);
    _stderr = _decode(channel.stderr).listen(terminal.write);
    unawaited(channel.done.then<void>((_) => _ended(channel), onError: (Object _) => _ended(channel)));
    _setState(TerminalSessionState.running);
    _scheduleResize(); // ukuran bisa berubah selama shell dibuka
  }

  /// UTF-8 streaming: karakter multibyte yang terpotong di antara dua paket tidak rusak.
  static Stream<String> _decode(Stream<Uint8List> s) =>
      s.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true));

  void _ended(ShellChannel channel) {
    if (_disposed || !identical(channel, _channel)) return;
    _setState(TerminalSessionState.ended);
  }

  void _setState(TerminalSessionState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  void _onOutput(String data) {
    final out = applyModifiers(data, ctrl: _ctrl, alt: _alt);
    _releaseModifiers();
    final channel = _channel;
    if (channel == null || _state != TerminalSessionState.running) return;
    channel.write(Uint8List.fromList(utf8.encode(out)));
  }

  /// Kirim ukuran setelah tampilan diam; nilai dibaca saat timer berbunyi (bukan dari callback), supaya yang
  /// terkirim selalu ukuran terbaru.
  void _scheduleResize() {
    _resizeTimer?.cancel();
    if (_channel == null) return;
    _resizeTimer = Timer(resizeDebounce, () {
      _channel?.resize(terminal.viewWidth, terminal.viewHeight);
    });
  }

  void _releaseModifiers() {
    if (!_ctrl && !_alt) return;
    _ctrl = false;
    _alt = false;
    if (!_disposed) notifyListeners();
  }

  void toggleCtrl() {
    _ctrl = !_ctrl;
    notifyListeners();
  }

  void toggleAlt() {
    _alt = !_alt;
    notifyListeners();
  }

  /// Tombol khusus (Esc, Tab, panah, Home, End, PgUp, PgDn, F1..F12) dengan pengubah yang sedang menyala.
  void pressKey(TerminalKey key) {
    terminal.keyInput(key, ctrl: _ctrl, alt: _alt);
    _releaseModifiers();
  }

  /// Ctrl+[letter] langsung, mis. `^C` dan `^D`.
  void pressControl(String letter) {
    terminal.charInput(letter.toLowerCase().codeUnitAt(0), ctrl: true);
    _releaseModifiers();
  }

  /// Teks biasa (simbol yang sulit diketik di keyboard HP); Ctrl dan Alt berlaku bila menyala.
  void pressText(String text) {
    terminal.textInput(text);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    unawaited(_stdout?.cancel());
    unawaited(_stderr?.cancel());
    terminal.onOutput = null;
    terminal.onResize = null;
    _channel?.close();
    _channel = null;
    super.dispose();
  }
}
