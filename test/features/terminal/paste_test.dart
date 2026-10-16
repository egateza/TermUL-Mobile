import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:termul_mobile/features/terminal/paste_analysis.dart';
import 'package:termul_mobile/features/terminal/terminal_screen.dart' show TerminalLink;
import 'package:termul_mobile/shared/widgets/termul_button.dart';

import 'terminal_screen_test.dart' show pumpTerminal, terminalView;

PasteAnalysis analyze(String s, {bool bracketed = true}) => PasteAnalysis.of(s, bracketed: bracketed);

/// Mengisi papan klip palsu dan mencatat berapa kali dibaca.
void setClipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return text == null ? null : <String, Object?>{'text': text};
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> tapPaste(WidgetTester tester) async {
  await tester.ensureVisible(find.bySemanticsLabel('Tempel dari papan klip'));
  await tester.tap(find.bySemanticsLabel('Tempel dari papan klip'));
  await tester.pumpAndSettle();
}

void main() {
  group('PasteAnalysis', () {
    test('satu baris aman: tidak perlu konfirmasi', () {
      final a = analyze('systemctl status nginx');
      expect(a.lineCount, 1);
      expect(a.needsConfirm, isFalse);
      expect(a.hasRisk, isFalse);
      expect(a.cancelIsPrimary, isFalse);
      expect(a.outgoing, 'systemctl status nginx');
    });

    test('banyak baris: perlu konfirmasi; baris baru dikirim sebagai CR', () {
      final a = analyze('cd /tmp\nls -la');
      expect(a.lineCount, 2);
      expect(a.needsConfirm, isTrue);
      expect(a.outgoing, 'cd /tmp\rls -la');
      expect(a.cancelIsPrimary, isFalse, reason: 'tempel aman aktif dan tidak ada tanda bahaya');
    });

    test('CRLF dan CR lama dinormalkan; baris baru di akhir tidak menambah baris tetapi tetap perlu konfirmasi', () {
      expect(analyze('a\r\nb\rc').lines.map((l) => l.text), ['a', 'b', 'c']);
      final a = analyze('ls\n');
      expect(a.lineCount, 1);
      expect(a.hasNewline, isTrue);
      expect(a.needsConfirm, isTrue);
    });

    test('baris berisiko dikenali (contoh dari desain) dan membuat pilihan aman jadi utama', () {
      final a = analyze('sudo systemctl stop nginx\nsudo rm -rf /var/cache/nginx/*\nsudo systemctl start nginx');
      expect(a.lineCount, 3);
      expect(a.riskCount, 1);
      expect(a.lines[1].risky, isTrue);
      expect(a.lines[0].risky, isFalse);
      expect(a.cancelIsPrimary, isTrue);
    });

    test('daftar pola berisiko', () {
      for (final risky in [
        'rm -rf /',
        'rm -f x',
        'dd if=/dev/zero of=/dev/sda',
        'mkfs.ext4 /dev/sdb1',
        'shutdown -h now',
        'reboot',
        'chmod -R 777 /',
        'chown -R root .',
        'truncate -s 0 log',
        'DROP TABLE users;',
      ]) {
        expect(analyze(risky).hasRisk, isTrue, reason: risky);
        expect(analyze(risky).needsConfirm, isTrue, reason: risky);
      }
      for (final safe in ['rmdir x', 'ls -la', 'git reset', 'echo reboot_later_not']) {
        expect(analyze(safe).hasRisk, isFalse, reason: safe);
      }
    });

    test('satu baris berisiko tetap perlu konfirmasi', () {
      expect(analyze('rm -rf build').needsConfirm, isTrue);
    });

    test('tanpa tempel aman, banyak baris langsung dijalankan: peringatan dan pilihan aman jadi utama', () {
      final a = analyze('ls\npwd', bracketed: false);
      expect(a.runsImmediately, isTrue);
      expect(a.cancelIsPrimary, isTrue);
      expect(analyze('ls', bracketed: false).runsImmediately, isFalse);
    });

    test('karakter kontrol (ESC dan sejenisnya) dibuang dan dilaporkan; tab dan baris baru tetap', () {
      final a = analyze('echo hi\x1b[201~; rm x\tOK\x07');
      expect(a.removedControls, 2);
      expect(a.text.contains('\x1b'), isFalse);
      expect(a.text.contains('\x07'), isFalse);
      expect(a.text.contains('\t'), isTrue);
      expect(a.needsConfirm, isTrue);
    });

    test('kosong', () {
      expect(analyze('').isEmpty, isTrue);
      expect(analyze('\x1b\x07').isEmpty, isTrue);
    });
  });

  group('popover Tempel di kursor prompt', () {
    Future<void> tapCursor(WidgetTester tester) async {
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      await tester.tapAt(state.globalCursorRect.center);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400)); // timer ketuk-ganda xterm
    }

    testWidgets('mengetuk kursor membuka popover dengan ringkasan papan klip; Tempel menempel dan menutupnya', (
      tester,
    ) async {
      setClipboard(tester, 'systemctl status nginx');
      final rig = await pumpTerminal(tester);
      terminalView(tester).terminal.write(r'user@host:~$ ');
      await tester.pump();
      expect(find.byKey(const ValueKey('paste-popover')), findsNothing);

      await tapCursor(tester);
      expect(find.byKey(const ValueKey('paste-popover')), findsOneWidget);
      expect(find.text('Papan klip: 1 baris'), findsOneWidget);
      expect(rig.shell.sent, isEmpty);

      await tester.tap(find.descendant(of: find.byKey(const ValueKey('paste-popover')), matching: find.text('Tempel')));
      await tester.pumpAndSettle();
      expect(rig.shell.sent, 'systemctl status nginx');
      expect(find.byKey(const ValueKey('paste-popover')), findsNothing);
    });

    testWidgets('ketukan kedua di kursor menutup; papan klip kosong tampil "kosong"', (tester) async {
      setClipboard(tester, null);
      await pumpTerminal(tester);
      terminalView(tester).terminal.write(r'user@host:~$ ');
      await tester.pump();
      await tapCursor(tester);
      expect(find.text('Papan klip: kosong'), findsOneWidget);
      await tapCursor(tester);
      expect(find.byKey(const ValueKey('paste-popover')), findsNothing);
    });

    testWidgets('mengetik atau keluaran yang menggeser kursor menutup popover', (tester) async {
      setClipboard(tester, 'ls');
      await pumpTerminal(tester);
      terminalView(tester).terminal.write(r'user@host:~$ ');
      await tester.pump();
      await tapCursor(tester);
      expect(find.byKey(const ValueKey('paste-popover')), findsOneWidget);
      terminalView(tester).terminal.write('x');
      await tester.pump();
      expect(find.byKey(const ValueKey('paste-popover')), findsNothing);
    });

    testWidgets('layar alternatif (vim, htop): ketukan di kursor tidak membuka popover', (tester) async {
      setClipboard(tester, 'ls');
      await pumpTerminal(tester);
      terminalView(tester).terminal.write('[?1049h');
      await tester.pump();
      await tapCursor(tester);
      expect(find.byKey(const ValueKey('paste-popover')), findsNothing);
    });
  });

  group('tombol Tempel di layar terminal', () {
    testWidgets('papan klip kosong: toast, tidak ada yang dikirim', (tester) async {
      setClipboard(tester, null);
      final rig = await pumpTerminal(tester);
      await tapPaste(tester);
      expect(find.text('Papan klip kosong'), findsOneWidget);
      expect(rig.shell.sent, isEmpty);
    });

    testWidgets('satu baris aman: langsung ke prompt tanpa Enter, toast menyebut belum dijalankan', (tester) async {
      setClipboard(tester, 'systemctl status nginx');
      final rig = await pumpTerminal(tester);
      await tapPaste(tester);
      expect(rig.shell.sent, 'systemctl status nginx');
      expect(find.text('Ditempel · 1 baris · belum dijalankan'), findsOneWidget);
      expect(find.text('Tempel 1 baris?'), findsNothing);
    });

    testWidgets('banyak baris berisiko: dialog dengan isi, tanda berisiko, Batal jadi tombol utama', (tester) async {
      setClipboard(tester, 'sudo systemctl stop nginx\nsudo rm -rf /var/cache/nginx/*\nsudo systemctl start nginx');
      final rig = await pumpTerminal(tester);
      terminalView(tester).terminal.write('\x1b[?2004h'); // program di server menyalakan tempel aman
      await tapPaste(tester);
      expect(find.text('Tempel 3 baris?'), findsOneWidget);
      expect(find.text('1 baris berisiko (mis. rm -rf). Periksa sebelum menekan Enter.'), findsOneWidget);
      expect(find.text('berisiko'), findsOneWidget);
      expect(find.text('sudo rm -rf /var/cache/nginx/*'), findsOneWidget);
      expect(find.text('Teks masuk ke prompt tanpa menekan Enter, jadi belum dijalankan.'), findsOneWidget);
      expect(rig.shell.sent, isEmpty, reason: 'belum ada yang dikirim sebelum konfirmasi');
      final batal = tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Batal'));
      final tempel = tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Tempel'));
      expect(batal.variant, TermulButtonVariant.primary);
      expect(tempel.variant, TermulButtonVariant.secondary);

      await tester.tap(find.widgetWithText(TermulButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(rig.shell.sent, isEmpty);
    });

    testWidgets('konfirmasi menempel dengan pembungkus tempel aman bila mode menyala; belum dijalankan', (
      tester,
    ) async {
      setClipboard(tester, 'cd /tmp\nls -la');
      final rig = await pumpTerminal(tester);
      terminalView(tester).terminal.write('\x1b[?2004h');
      await tapPaste(tester);
      expect(find.text('Tempel 2 baris?'), findsOneWidget);
      final tempel = tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Tempel'));
      expect(tempel.variant, TermulButtonVariant.primary, reason: 'tanpa tanda bahaya dan tempel aman aktif');
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel'));
      await tester.pumpAndSettle();
      expect(rig.shell.sent, '\x1b[200~cd /tmp\rls -la\x1b[201~');
      expect(find.text('Ditempel · 2 baris · belum dijalankan'), findsOneWidget);
    });

    testWidgets('tanpa tempel aman: peringatan "langsung dijalankan", teks dikirim polos, toast tidak berjanji', (
      tester,
    ) async {
      setClipboard(tester, 'ls\npwd');
      final rig = await pumpTerminal(tester);
      await tapPaste(tester);
      expect(
        find.text('Server ini belum mendukung tempel aman: setiap baris langsung dijalankan begitu ditempel.'),
        findsOneWidget,
      );
      expect(find.text('Teks masuk ke prompt tanpa menekan Enter, jadi belum dijalankan.'), findsNothing);
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel'));
      await tester.pumpAndSettle();
      expect(rig.shell.sent, 'ls\rpwd');
      expect(find.text('Ditempel · 2 baris'), findsOneWidget);
    });

    testWidgets('karakter kontrol dibuang dan dilaporkan sebelum menempel', (tester) async {
      setClipboard(tester, 'echo hi\x1b[201~ rm x');
      final rig = await pumpTerminal(tester);
      await tapPaste(tester);
      expect(find.textContaining('karakter kontrol dihapus'), findsOneWidget);
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel'));
      await tester.pumpAndSettle();
      expect(rig.shell.sent.contains('\x1b'), isFalse);
      expect(rig.shell.sent, 'echo hi[201~ rm x');
    });

    testWidgets('teks terlalu besar ditolak dengan toast', (tester) async {
      setClipboard(tester, 'a' * (PasteAnalysis.maxChars + 1));
      final rig = await pumpTerminal(tester);
      await tapPaste(tester);
      expect(find.textContaining('terlalu besar'), findsOneWidget);
      expect(rig.shell.sent, isEmpty);
    });

    testWidgets('dialog banyak baris memotong tampilan di 50 baris tetapi menempel semuanya', (tester) async {
      final text = [for (var i = 1; i <= 120; i++) 'echo $i'].join('\n');
      setClipboard(tester, text);
      final rig = await pumpTerminal(tester);
      terminalView(tester).terminal.write('\x1b[?2004h');
      await tapPaste(tester);
      expect(find.text('Tempel 120 baris?'), findsOneWidget);
      expect(find.text('… dan 70 baris lagi'), findsOneWidget);
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel'));
      await tester.pumpAndSettle();
      expect(rig.shell.sent, '\x1b[200~${text.replaceAll('\n', '\r')}\x1b[201~');
    });

    testWidgets('saat sambungan putus, tombol Tempel tidak tersedia', (tester) async {
      setClipboard(tester, 'ls');
      await pumpTerminal(tester, link: TerminalLink.lost);
      expect(find.bySemanticsLabel('Tempel dari papan klip'), findsNothing);
    });
  });
}
