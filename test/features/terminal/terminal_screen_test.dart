import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/platform/screen_awake.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/features/terminal/terminal_palette.dart';
import 'package:termul_mobile/features/terminal/terminal_screen.dart';
import 'package:termul_mobile/features/terminal/terminal_session.dart';
import 'package:termul_mobile/features/terminal/terminal_transcript.dart';
import 'package:termul_mobile/shared/widgets/key_button.dart';
import 'package:xterm/xterm.dart';

import '../hosts_ui_harness.dart';
import 'terminal_session_test.dart' show FakeShell;

/// Meniru pemilik sesi di aplikasi (`ConnectScreen`): menutup sesi saat pohon widget dibuang.
class _SessionOwner extends StatefulWidget {
  const _SessionOwner({required this.session, required this.child});

  final TerminalSession session;
  final Widget child;

  @override
  State<_SessionOwner> createState() => _SessionOwnerState();
}

class _SessionOwnerState extends State<_SessionOwner> {
  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TermRig {
  TermRig() {
    profile = host(id1, name: 'app-01');
    shell = FakeShell();
    session = TerminalSession(
      open: ({required columns, required rows}) async {
        openedCols = columns;
        openedRows = rows;
        return shell;
      },
    );
  }

  late final TerminalSession session;
  late final FakeShell shell;
  late final HostProfile profile;
  int? openedCols;
  int? openedRows;
}

/// Membuka [TerminalScreen] di atas halaman dasar supaya tombol kembali punya tujuan. Ukuran dalam dp, dpr 1.
Future<TermRig> pumpTerminal(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double keyboard = 0,
  EdgeInsets padding = EdgeInsets.zero,
  TerminalLink link = TerminalLink.up,
  String? failureText,
  VoidCallback? onReconnect,
  bool needsAuth = false,
  TerminalStyle? textStyle,
  bool confirmSingleLinePaste = true,
  VoidCallback? onOpenSftp,
  QuickKeySettings quickKeys = const QuickKeySettings(),
  TranscriptExporter? transcripts,
  ScreenAwake? screenAwake,
  List<Snippet>? snippets,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.padding = FakeViewPadding(top: padding.top, bottom: padding.bottom);
  addTearDown(tester.view.reset);
  final rig = TermRig();
  await tester.pumpWidget(termulMaterialApp(home: const Scaffold(body: Text('daftar'))));
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => _SessionOwner(
            session: rig.session,
            child: TerminalScreen(
              profile: rig.profile,
              session: rig.session,
              link: link,
              failureText: failureText,
              onReconnect: onReconnect,
              needsAuth: needsAuth,
              textStyle: textStyle,
              confirmSingleLinePaste: confirmSingleLinePaste,
              onOpenSftp: onOpenSftp,
              quickKeys: quickKeys,
              transcripts: transcripts,
              screenAwake: screenAwake,
              snippets: snippets,
            ),
          ),
        ),
      );
  await tester.pumpAndSettle();
  return rig;
}

TerminalView terminalView(WidgetTester tester) => tester.widget<TerminalView>(find.byType(TerminalView));

double lineHeight(WidgetTester tester) {
  final render = tester.allRenderObjects.firstWhere((r) => r.runtimeType.toString() == 'RenderTerminal');
  return (render as dynamic).lineHeight as double;
}

void expectRowsFit(WidgetTester tester) {
  final h = tester.getSize(find.byType(TerminalView)).height;
  final rows = terminalView(tester).terminal.viewHeight;
  // Ukuran baris tidak boleh kurang dari yang muat (padding sistem tidak boleh terpotong dua kali).
  expect(rows, (h / lineHeight(tester)).floor(), reason: 'tinggi $h, baris $rows');
}

void main() {
  testWidgets('tombol Ke bawah muncul saat scrollback dan kembali menyembunyikan tombol', (tester) async {
    final rig = await pumpTerminal(tester);
    rig.session.terminal.write(List.generate(80, (i) => 'baris $i\r\n').join());
    await tester.pumpAndSettle();
    final scroll = terminalView(tester).scrollController!;
    expect(scroll.position.maxScrollExtent, greaterThan(24));
    scroll.jumpTo(0);
    await tester.pump();
    final button = find.bySemanticsLabel('Ke bawah');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(button, findsNothing);
  });

  testWidgets('tombol SFTP di header tidak ada bila onOpenSftp tidak diberikan', (tester) async {
    await pumpTerminal(tester);
    expect(find.bySemanticsLabel('Buka panel SFTP'), findsNothing);
  });

  testWidgets('tombol SFTP di header memanggil onOpenSftp', (tester) async {
    var opened = 0;
    await pumpTerminal(tester, onOpenSftp: () => opened++);
    final button = find.bySemanticsLabel('Buka panel SFTP');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tap(button);
    expect(opened, 1);
  });

  testWidgets('potret: header dengan nama dan status berkata; shell dibuka dengan ukuran layar sebenarnya', (
    tester,
  ) async {
    final rig = await pumpTerminal(tester, padding: const EdgeInsets.only(top: 47, bottom: 16));
    expect(find.text('app-01'), findsOneWidget);
    expect(find.text('Tersambung'), findsOneWidget);
    expect(rig.openedRows, greaterThan(24));
    expect(rig.openedRows, terminalView(tester).terminal.viewHeight);
    expect(rig.openedCols, terminalView(tester).terminal.viewWidth);
    expectRowsFit(tester);
  });

  testWidgets('landscape tanpa keyboard: mode ringkas, tombol kembali 32 dp, baris cocok dengan tinggi', (
    tester,
  ) async {
    await pumpTerminal(tester, size: const Size(853, 393), padding: const EdgeInsets.only(top: 24, bottom: 16));
    expect(find.text('Tersambung'), findsOneWidget);
    expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
    expect(tester.getSize(find.bySemanticsLabel('Kembali')).height, 32);
    final keys = tester.widgetList<KeyButton>(find.byType(KeyButton));
    expect(keys.every((k) => k.compact), isTrue);
    expectRowsFit(tester);
  });

  testWidgets('landscape dengan keyboard: tanpa tombol kembali, baris tetap cocok dan ada isinya', (tester) async {
    await pumpTerminal(
      tester,
      size: const Size(853, 393),
      keyboard: 209,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
    );
    expect(find.bySemanticsLabel('Kembali'), findsNothing);
    expect(terminalView(tester).terminal.viewHeight, greaterThanOrEqualTo(1));
    expectRowsFit(tester);
  });

  testWidgets('potret dengan keyboard: baris berkurang tetapi tetap cocok; tombol 44 dp', (tester) async {
    await pumpTerminal(tester, keyboard: 300, padding: const EdgeInsets.only(top: 47, bottom: 16));
    final keys = tester.widgetList<KeyButton>(find.byType(KeyButton));
    expect(keys.every((k) => !k.compact), isTrue);
    expectRowsFit(tester);
  });

  testWidgets('perubahan keyboard bertahap: baris selalu cocok dengan tinggi di tiap langkah', (tester) async {
    await pumpTerminal(tester, size: const Size(853, 393), padding: const EdgeInsets.only(top: 24, bottom: 16));
    final seen = <int>{};
    for (var i = 1; i <= 10; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: 209.0 * i / 10);
      await tester.pump(const Duration(milliseconds: 16));
      expectRowsFit(tester);
      seen.add(terminalView(tester).terminal.viewHeight);
    }
    await tester.pumpAndSettle();
    expectRowsFit(tester);
  });

  testWidgets('tombol cepat mengirim urutan yang benar', (tester) async {
    final rig = await pumpTerminal(tester);

    Future<void> tapKey(String aria) async {
      await tester.ensureVisible(find.bySemanticsLabel(aria));
      await tester.tap(find.bySemanticsLabel(aria));
      await tester.pump();
    }

    await tapKey('Tombol Escape');
    expect(rig.shell.sent, '\x1b');
    rig.shell.clear();
    await tapKey('Tombol Tab');
    expect(rig.shell.sent, '\t');
    rig.shell.clear();
    await tapKey('Ctrl C, hentikan program');
    expect(rig.shell.written, [3]);
    rig.shell.clear();
    await tapKey('Panah atas');
    expect(rig.shell.sent, '\x1b[A');
    rig.shell.clear();
    await tapKey('PgUp'.replaceAll('PgUp', 'Page Up'));
    expect(rig.shell.sent, '\x1b[5~');
    rig.shell.clear();
    await tapKey('Garis tegak');
    expect(rig.shell.sent, '|');
  });

  testWidgets('Ctrl menyala sampai ketukan berikutnya, termasuk dari keyboard sistem', (tester) async {
    final rig = await pumpTerminal(tester);
    final session = terminalView(tester).terminal;
    await tester.tap(find.bySemanticsLabel('Ctrl, berlaku untuk satu ketukan berikutnya'));
    await tester.pump();
    final ctrlKey = tester.widgetList<KeyButton>(find.byType(KeyButton)).firstWhere((k) => k.label == 'Ctrl');
    expect(ctrlKey.pressed, isTrue);
    session.textInput('c'); // keyboard sistem
    await tester.pump();
    expect(rig.shell.written, [3]);
    final after = tester.widgetList<KeyButton>(find.byType(KeyButton)).firstWhere((k) => k.label == 'Ctrl');
    expect(after.pressed, isFalse);
  });

  testWidgets('Fn menukar baris dengan F1 sampai F12 dan ABC mengembalikannya', (tester) async {
    final rig = await pumpTerminal(tester);
    // Fn ada di kolom setelah enam kolom pertama: geser dulu.
    await tester.ensureVisible(find.bySemanticsLabel('Tombol F1 sampai F12'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Tombol F1 sampai F12'));
    await tester.pump();
    expect(find.bySemanticsLabel('Tombol Escape'), findsNothing);
    await tester.tap(find.bySemanticsLabel('F1'));
    await tester.pump();
    expect(rig.shell.sent, '\x1bOP');
    rig.shell.clear();
    await tester.tap(find.bySemanticsLabel('Kembali ke tombol biasa'));
    await tester.pump();
    expect(find.bySemanticsLabel('Tombol Escape'), findsOneWidget);
  });

  testWidgets('tombol cepat dua baris: tujuh kolom terlihat selebar sama, Home panah atas End di atas panah kiri bawah kanan', (tester) async {
    await pumpTerminal(tester);
    Rect rect(String label) => tester.getRect(find.bySemanticsLabel(label));
    expect(rect('Panah atas').center.dx, moreOrLessEquals(rect('Panah bawah').center.dx));
    expect(rect('Home').center.dx, moreOrLessEquals(rect('Panah kiri').center.dx));
    expect(rect('End').center.dx, moreOrLessEquals(rect('Panah kanan').center.dx));
    expect(rect('Panah atas').top, lessThan(rect('Panah bawah').top));
    final esc = rect('Tombol Escape');
    expect(esc.width, greaterThanOrEqualTo(44));
    expect(rect('Tombol Tab').width, moreOrLessEquals(esc.width));
    // Kolom ketujuh (PgUp) masih di dalam layar 390 dp; kolom kedelapan (Fn) di luar dan perlu digeser.
    expect(esc.left, moreOrLessEquals(8));
    expect(rect('Page Up').right, lessThanOrEqualTo(390));
    expect(rect('Tombol F1 sampai F12').right, greaterThan(390));
  });

  testWidgets('tanpa tombol Snippet di bilah (menunggu prototipe Snippet berikutnya)', (tester) async {
    await pumpTerminal(tester);
    expect(find.byTooltip('Snippet'), findsNothing);
  });

  testWidgets('susunan dari pengaturan dipakai: pintasan Ctrl mengirim kode kontrol', (tester) async {
    final rig = await pumpTerminal(
      tester,
      quickKeys: const QuickKeySettings(row1: ['ctrll', 'del'], row2: ['enter']),
    );
    expect(find.bySemanticsLabel('Tombol Escape'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Ctrl L, bersihkan layar'));
    await tester.pump();
    expect(rig.shell.sent, '\x0c');
    rig.shell.clear();
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();
    expect(rig.shell.sent, '\x1b[3~');
    rig.shell.clear();
    await tester.tap(find.bySemanticsLabel('Enter'));
    await tester.pump();
    expect(rig.shell.sent, '\r');
  });

  testWidgets('tombol cepat tidak mengambil fokus dari terminal (keyboard sistem tetap terbuka)', (tester) async {
    await pumpTerminal(tester);
    final before = FocusManager.instance.primaryFocus;
    await tester.tap(find.bySemanticsLabel('Tombol Tab'));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(before));
  });

  testWidgets('keluaran server tampil, dan ketikan dari keyboard sistem sampai ke server', (tester) async {
    final rig = await pumpTerminal(tester);
    rig.shell.emit('user@app-01:~\$ '.codeUnits);
    await tester.pump(const Duration(milliseconds: 50));
    expect(terminalView(tester).terminal.buffer.getText(), contains('user@app-01'));
    terminalView(tester).terminal.textInput('ls\r');
    expect(rig.shell.sent, 'ls\r');
  });

  testWidgets('kembali saat hidup meminta konfirmasi; Batal tetap di terminal; Putuskan menutup layar', (tester) async {
    await pumpTerminal(tester);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Putuskan sambungan?'), findsOneWidget);
    expect(find.textContaining('tmux'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsNothing);
    expect(find.text('daftar'), findsOneWidget);
  });

  testWidgets('setelah shell selesai, status berkata "Sesi berakhir" dan kembali tanpa konfirmasi', (tester) async {
    final rig = await pumpTerminal(tester);
    rig.shell.close();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Sesi berakhir'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Putuskan sambungan?'), findsNothing);
    expect(find.text('daftar'), findsOneWidget);
  });

  testWidgets('tombol kembali sistem juga meminta konfirmasi saat hidup', (tester) async {
    await pumpTerminal(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Putuskan sambungan?'), findsOneWidget);
  });

  testWidgets('warna latar terminal memakai token ground-deep', (tester) async {
    await pumpTerminal(tester);
    expect(terminalView(tester).theme.background, TermulPalette.groundDeep);
    expect(terminalView(tester).theme.foreground, TermulPalette.terminalInk);
  });

  testWidgets('papan ketik sistem (KeyEvent) tidak merusak: Enter dari perangkat keras terkirim', (tester) async {
    final rig = await pumpTerminal(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(rig.shell.sent, contains('\r'));
  });

  testWidgets('sambungan putus: banner dengan kata, status Terputus, tombol Sambung sekarang memanggil callback', (
    tester,
  ) async {
    var calls = 0;
    await pumpTerminal(tester, link: TerminalLink.lost, onReconnect: () => calls++);
    expect(find.text('Koneksi terputus'), findsOneWidget);
    expect(find.text('Terputus'), findsOneWidget);
    expect(find.textContaining('tmux'), findsOneWidget);
    await tester.tap(find.text('Sambung sekarang'));
    expect(calls, 1);
    // Riwayat layar tetap ada dan kembali tidak meminta konfirmasi (shell sudah mati).
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('daftar'), findsOneWidget);
  });

  testWidgets('gambar terminal dipotong di batas areanya (tidak menimpa label profil saat keyboard terbuka)', (
    tester,
  ) async {
    await pumpTerminal(tester, size: const Size(844, 390), keyboard: 209, padding: const EdgeInsets.only(top: 24));
    final clip = find.ancestor(of: find.byType(TerminalView), matching: find.byType(ClipRect));
    expect(clip, findsWidgets);
    // Batas potong berhimpit dengan area terminal: tidak lebih tinggi daripadanya dan di bawah bar atas.
    final area = tester.getRect(clip.first);
    final bar = tester.getRect(find.text('app-01'));
    expect(area.top, greaterThanOrEqualTo(bar.bottom - 1));
  });

  testWidgets('landscape dengan keyboard: banner putus tidak meluap dan tombol Sambung sekarang tetap bisa diketuk', (
    tester,
  ) async {
    var calls = 0;
    await pumpTerminal(
      tester,
      size: const Size(844, 390),
      keyboard: 209,
      padding: const EdgeInsets.only(top: 24),
      link: TerminalLink.lost,
      onReconnect: () => calls++,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Koneksi terputus'), findsOneWidget);
    await tester.tap(find.text('Sambung sekarang'));
    expect(calls, 1);
  });

  testWidgets('sambung ulang butuh verifikasi: peringatan dengan kata dan tombol Tampilkan prompt', (tester) async {
    var calls = 0;
    await pumpTerminal(tester, link: TerminalLink.lost, needsAuth: true, onReconnect: () => calls++);
    expect(find.text('Perlu verifikasi'), findsOneWidget);
    expect(find.textContaining('sidik jari, PIN, atau pola'), findsOneWidget);
    expect(find.text('Terputus'), findsOneWidget);
    expect(find.text('Sambung sekarang'), findsNothing);
    await tester.tap(find.text('Tampilkan prompt'));
    expect(calls, 1);
  });

  testWidgets('menyambung ulang: banner dan status berkata, tanpa tombol', (tester) async {
    await pumpTerminal(tester, link: TerminalLink.reconnecting);
    expect(find.text('Menyambung ulang…'), findsNWidgets(2)); // banner dan status
    expect(find.text('Sambung sekarang'), findsNothing);
  });

  testWidgets('sambung ulang gagal: banner galat memuat alasan dan tombol Sambung sekarang', (tester) async {
    await pumpTerminal(tester, link: TerminalLink.lost, failureText: 'Tidak bisa tersambung', onReconnect: () {});
    expect(find.text('Gagal menyambung ulang'), findsOneWidget);
    expect(find.text('Tidak bisa tersambung'), findsOneWidget);
    expect(find.text('Sambung sekarang'), findsOneWidget);
  });

  testWidgets('riwayat layar tetap terlihat di bawah banner', (tester) async {
    final rig = await pumpTerminal(tester, link: TerminalLink.lost, onReconnect: () {});
    rig.session.terminal.write('riwayat-lama\r\n');
    await tester.pump();
    expect(rig.session.terminal.buffer.getText(), contains('riwayat-lama'));
    expectRowsFit(tester);
  });

  testWidgets('ukuran huruf bawaan: 13 sp dengan tinggi baris 1,3', (tester) async {
    final rig = await pumpTerminal(tester);
    expect(terminalView(tester).textStyle.fontSize, 13);
    expect(terminalView(tester).textStyle.height, 1.3);
    expect(rig.openedRows, terminalView(tester).terminal.viewHeight);
    expectRowsFit(tester);
  });

  testWidgets('ukuran huruf dari pengaturan dipakai: huruf kecil memuat banyak baris dan kolom, PTY ikut', (
    tester,
  ) async {
    final rig = await pumpTerminal(
      tester,
      textStyle: terminalStyleFor(const TerminalSettings(fontSize: 9, lineHeight: 1.1)),
    );
    expect(terminalView(tester).textStyle.fontSize, 9);
    expect(terminalView(tester).textStyle.height, 1.1);
    expect(terminalView(tester).terminal.viewHeight, greaterThan(60)); // sekitar 72 baris pada 720 dp
    expect(terminalView(tester).terminal.viewWidth, greaterThan(40)); // huruf uji lebar sama dengan tingginya (Ahem)
    expect(rig.openedRows, terminalView(tester).terminal.viewHeight);
    expect(rig.openedCols, terminalView(tester).terminal.viewWidth);
    expectRowsFit(tester);
  });
}
