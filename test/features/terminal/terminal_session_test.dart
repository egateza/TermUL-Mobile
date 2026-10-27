import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/features/terminal/key_codes.dart';
import 'package:termul_mobile/features/terminal/shell_channel.dart';
import 'package:termul_mobile/features/terminal/terminal_session.dart';
import 'package:xterm/xterm.dart';

class FakeShell implements ShellChannel {
  final out = StreamController<Uint8List>();
  final err = StreamController<Uint8List>();
  final doneC = Completer<void>();
  final written = <int>[];
  final resizes = <(int, int)>[];
  bool closed = false;

  @override
  Stream<Uint8List> get stdout => out.stream;
  @override
  Stream<Uint8List> get stderr => err.stream;
  @override
  Future<void> get done => doneC.future;
  @override
  void write(Uint8List data) => written.addAll(data);
  @override
  void resize(int columns, int rows) => resizes.add((columns, rows));
  @override
  void close() {
    closed = true;
    if (!doneC.isCompleted) doneC.complete();
  }

  String get sent => utf8.decode(written);
  void clear() => written.clear();
  void emit(List<int> bytes) => out.add(Uint8List.fromList(bytes));
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

String screenText(Terminal t) => t.buffer.getText();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // HardwareKeyboard dibaca saat Enter (LF) diketik

  group('applyModifiers', () {
    test('Ctrl+huruf menjadi kode kontrol, huruf besar dan kecil sama', () {
      expect(applyModifiers('c', ctrl: true, alt: false), '\x03');
      expect(applyModifiers('C', ctrl: true, alt: false), '\x03');
      expect(applyModifiers('d', ctrl: true, alt: false), '\x04');
      expect(applyModifiers('[', ctrl: true, alt: false), '\x1b');
      expect(applyModifiers('z', ctrl: true, alt: false), '\x1a');
    });

    test('Alt memberi awalan ESC; Ctrl+Alt menggabungkan keduanya', () {
      expect(applyModifiers('x', ctrl: false, alt: true), '\x1bx');
      expect(applyModifiers('c', ctrl: true, alt: true), '\x1b\x03');
    });

    test('tanpa pengubah, karakter bukan huruf, dan urutan panjang tidak berubah', () {
      expect(applyModifiers('c', ctrl: false, alt: false), 'c');
      expect(applyModifiers('1', ctrl: true, alt: false), '1');
      expect(applyModifiers('\x1b[A', ctrl: true, alt: true), '\x1b[A');
      expect(applyModifiers('', ctrl: true, alt: true), '');
    });
  });

  group('enterAsCarriageReturn', () {
    test('LF tunggal menjadi CR; CRLF dan teks tanpa LF tidak berubah', () {
      expect(enterAsCarriageReturn('\n'), '\r');
      expect(enterAsCarriageReturn('ls\n'), 'ls\r');
      expect(enterAsCarriageReturn('\r\n'), '\r\n');
      expect(enterAsCarriageReturn('\r'), '\r');
      expect(enterAsCarriageReturn('abc'), 'abc');
    });
  });

  group('TerminalSession', () {
    late FakeShell shell;
    late TerminalSession session;
    int? openCols;
    int? openRows;

    setUp(() {
      shell = FakeShell();
      session = TerminalSession(
        resizeDebounce: const Duration(milliseconds: 10),
        open: ({required columns, required rows}) async {
          openCols = columns;
          openRows = rows;
          return shell;
        },
      );
    });

    tearDown(() {
      session.dispose();
    });

    test('shell dibuka dengan ukuran terminal saat itu, bukan 80x24', () async {
      session.terminal.resize(120, 44);
      await session.start();
      expect((openCols, openRows), (120, 44));
      expect(session.state, TerminalSessionState.running);
    });

    test('batas buffer 10.000 baris', () {
      expect(session.terminal.maxLines, 10000);
    });

    test('keluaran stdout dan stderr tampil di terminal', () async {
      await session.start();
      shell.emit(utf8.encode('halo\r\n'));
      shell.err.add(Uint8List.fromList(utf8.encode('galat\r\n')));
      await settle();
      final text = screenText(session.terminal);
      expect(text, contains('halo'));
      expect(text, contains('galat'));
    });

    test('karakter UTF-8 multibyte yang terpotong antar paket tetap utuh', () async {
      await session.start();
      final bytes = utf8.encode('é─😀\r\n'); // 2, 3, 4 byte
      for (final b in bytes) {
        shell.emit([b]);
      }
      await settle();
      final text = screenText(session.terminal);
      expect(text, contains('é─😀'));
      expect(text, isNot(contains('�')));
    });

    test('ketikan dikirim sebagai UTF-8; sebelum shell berjalan dibuang', () async {
      session.terminal.textInput('x'); // belum berjalan
      expect(shell.written, isEmpty);
      await session.start();
      session.terminal.textInput('ls é\r');
      expect(shell.sent, 'ls é\r');
    });

    test('Ctrl sekali pakai: berlaku untuk satu karakter berikutnya lalu padam', () async {
      await session.start();
      session.toggleCtrl();
      expect(session.ctrl, isTrue);
      session.terminal.textInput('c');
      expect(shell.sent, '\x03');
      expect(session.ctrl, isFalse);
      shell.clear();
      session.terminal.textInput('c');
      expect(shell.sent, 'c');
    });

    test('Alt sekali pakai, termasuk dari keyboard sistem (textInput)', () async {
      await session.start();
      session.toggleAlt();
      session.terminal.textInput('b');
      expect(shell.sent, '\x1bb');
      expect(session.alt, isFalse);
    });

    test('Ctrl dan Alt bisa dimatikan lagi dengan ketukan kedua', () async {
      await session.start();
      session.toggleCtrl();
      session.toggleCtrl();
      session.terminal.textInput('c');
      expect(shell.sent, 'c');
    });

    test('tombol khusus: urutan yang dikirim ke server', () async {
      await session.start();
      void expectKey(TerminalKey k, String seq) {
        shell.clear();
        session.pressKey(k);
        expect(shell.sent, seq, reason: '$k');
      }

      expectKey(TerminalKey.escape, '\x1b');
      expectKey(TerminalKey.tab, '\t');
      expectKey(TerminalKey.arrowUp, '\x1b[A');
      expectKey(TerminalKey.arrowDown, '\x1b[B');
      expectKey(TerminalKey.arrowRight, '\x1b[C');
      expectKey(TerminalKey.arrowLeft, '\x1b[D');
      expectKey(TerminalKey.home, '\x1b[H');
      expectKey(TerminalKey.end, '\x1b[F');
      expectKey(TerminalKey.pageUp, '\x1b[5~');
      expectKey(TerminalKey.pageDown, '\x1b[6~');
      expectKey(TerminalKey.f1, '\x1bOP');
      expectKey(TerminalKey.f4, '\x1bOS');
      expectKey(TerminalKey.f5, '\x1b[15~');
      expectKey(TerminalKey.f10, '\x1b[21~');
      expectKey(TerminalKey.f12, '\x1b[24~');
    });

    test('Ctrl pada panah memberi urutan dengan pengubah, lalu padam', () async {
      await session.start();
      session.toggleCtrl();
      session.pressKey(TerminalKey.arrowLeft);
      expect(shell.sent, '\x1b[1;5D');
      expect(session.ctrl, isFalse);
    });

    test('Enter dari keyboard layar (teks LF, mis. Gboard) dikirim sebagai CR', () async {
      await session.start();
      session.terminal.textInput('\n');
      expect(shell.sent, '\r');
    });

    test('^J dari tombol cepat tetap LF', () async {
      await session.start();
      session.pressControl('j');
      expect(shell.written, [10]);
    });

    test('Ctrl sekali pakai lalu j dari keyboard layar tetap LF', () async {
      await session.start();
      session.toggleCtrl();
      session.terminal.textInput('j');
      expect(shell.written, [10]);
    });

    test('^C dan ^D mengirim kode kontrol', () async {
      await session.start();
      session.pressControl('c');
      session.pressControl('d');
      expect(shell.written, [3, 4]);
    });

    test('simbol dikirim apa adanya; Ctrl yang menyala tidak bocor ke ketukan berikutnya', () async {
      await session.start();
      session.pressText('|');
      expect(shell.sent, '|');
    });

    test('perubahan ukuran beruntun hanya mengirim ukuran terakhir, setelah tampilan diam', () async {
      await session.start();
      await settle();
      shell.resizes.clear();
      for (final h in [30, 20, 12, 9, 7, 5]) {
        session.terminal.resize(80, h);
      }
      expect(shell.resizes, isEmpty); // belum diam
      await settle();
      expect(shell.resizes, [(80, 5)]);
    });

    test('shell selesai: keadaan ended', () async {
      await session.start();
      shell.close();
      await settle();
      expect(session.state, TerminalSessionState.ended);
    });

    test('shell gagal dibuka: keadaan failed dan tidak melempar', () async {
      final s = TerminalSession(open: ({required columns, required rows}) async => throw StateError('gagal'));
      await s.start();
      expect(s.state, TerminalSessionState.failed);
      s.dispose();
    });

    test('dispose menutup saluran dan berhenti menulis', () async {
      await session.start();
      final onOutputBefore = session.terminal.onOutput;
      expect(onOutputBefore, isNotNull);
      session.dispose();
      expect(shell.closed, isTrue);
      expect(session.terminal.onOutput, isNull);
      session.terminal.textInput('x');
      expect(shell.written, isEmpty);
      shell.emit(utf8.encode('terlambat')); // tidak melempar
      await settle();
    });

    test('dispose saat shell masih dibuka menutup saluran yang selesai belakangan', () async {
      final gate = Completer<ShellChannel>();
      final s = TerminalSession(open: ({required columns, required rows}) => gate.future);
      final started = s.start();
      s.dispose();
      gate.complete(shell);
      await started;
      expect(shell.closed, isTrue);
    });

    test('restart: riwayat layar tetap, pemisah ditulis, shell lama ditutup, shell baru dipakai', () async {
      await session.start();
      shell.emit(utf8.encode('riwayat-lama\r\n'));
      await settle();
      final baru = FakeShell();
      await session.restart(({required columns, required rows}) async => baru, marker: '-- sambung ulang --');
      expect(shell.closed, isTrue);
      expect(session.state, TerminalSessionState.running);
      final text = screenText(session.terminal);
      expect(text, contains('riwayat-lama'));
      expect(text, contains('-- sambung ulang --'));
      session.terminal.textInput('ls\r');
      expect(baru.sent, 'ls\r');
      expect(shell.written, isEmpty);
      baru.emit(utf8.encode('baru\r\n'));
      await settle();
      expect(screenText(session.terminal), contains('baru'));
      shell.emit(utf8.encode('hantu')); // keluaran saluran lama diabaikan
      await settle();
      expect(screenText(session.terminal), isNot(contains('hantu')));
    });

    test('restart: saluran lama yang selesai belakangan tidak mengubah keadaan', () async {
      await session.start();
      final baru = FakeShell();
      await session.restart(({required columns, required rows}) async => baru, marker: 'x');
      shell.close();
      await settle();
      expect(session.state, TerminalSessionState.running);
    });

    test('restart membersihkan mode yang ditinggal program (layar alternatif, kursor)', () async {
      await session.start();
      session.terminal.write('\x1b[?1049h\x1b[?25l');
      expect(session.terminal.isUsingAltBuffer, isTrue);
      await session.restart(({required columns, required rows}) async => FakeShell(), marker: 'x');
      expect(session.terminal.isUsingAltBuffer, isFalse);
      expect(session.terminal.cursorVisibleMode, isTrue);
    });

    test('start dua kali hanya membuka satu shell', () async {
      var opens = 0;
      final s = TerminalSession(
        open: ({required columns, required rows}) async {
          opens++;
          return FakeShell();
        },
      );
      await s.start();
      await s.start();
      expect(opens, 1);
      s.dispose();
    });
  });
}
