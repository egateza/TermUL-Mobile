import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/features/terminal/terminal_screen.dart';
import 'package:termul_mobile/shared/widgets/key_button.dart';
import 'package:xterm/xterm.dart';

import '../hosts_ui_harness.dart';
import '../silent_socket.dart';
import 'terminal_session_test.dart' show FakeShell;

class TermRig {
  TermRig() {
    profile = host(id1, name: 'app-01');
    connection = fakeConnection(profile);
    shell = FakeShell();
  }

  late final SshConnection connection;
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
          builder: (_) => TerminalScreen(
            profile: rig.profile,
            connection: rig.connection,
            openShell: ({required columns, required rows}) async {
              rig.openedCols = columns;
              rig.openedRows = rows;
              return rig.shell;
            },
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
    final rig = await pumpTerminal(tester);
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
    expect(rig.shell.closed, isTrue); // shell ditutup saat layar dibuang
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
}
