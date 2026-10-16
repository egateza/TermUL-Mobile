import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:termul_mobile/features/terminal/paste_analysis.dart';
import 'package:termul_mobile/features/terminal/terminal_screen.dart' show TerminalLink;
import 'package:termul_mobile/shared/widgets/key_button.dart';
import 'package:termul_mobile/shared/widgets/termul_button.dart';

import 'terminal_screen_test.dart' show TermRig, pumpTerminal, terminalView;

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

  group('popover Tempel (satu baris pendek)', () {
    final popover = find.byKey(const ValueKey('paste-popover'));

    Future<TermRig> open(WidgetTester tester, String? clip, {bool confirm = true}) async {
      setClipboard(tester, clip);
      final rig = await pumpTerminal(tester, confirmSingleLinePaste: confirm);
      terminalView(tester).terminal.write('\r\n\r\n\r\n\r\nuser@host:~\$ ');
      await tester.pump();
      return rig;
    }

    Future<void> holdAt(WidgetTester tester, Offset at) async {
      await tester.longPressAt(at);
      await tester.pumpAndSettle();
    }

    Rect cursorRect(WidgetTester tester) => tester.state<TerminalViewState>(find.byType(TerminalView)).globalCursorRect;

    testWidgets('tombol Tempel: teks pendek tampil di popover, belum masuk; Tempel di popover mengirimnya', (
      tester,
    ) async {
      final rig = await open(tester, 'systemctl status');
      await tapPaste(tester);
      expect(popover, findsOneWidget);
      expect(find.byKey(const ValueKey('paste-popover-text')), findsOneWidget);
      expect(find.text('systemctl status'), findsOneWidget);
      expect(find.text('Masuk ke prompt, belum dijalankan'), findsOneWidget);
      expect(rig.shell.sent, isEmpty);
      expect(find.text('Tempel 1 baris?'), findsNothing);

      await tester.tap(find.descendant(of: popover, matching: find.text('Tempel')));
      await tester.pumpAndSettle();
      expect(rig.shell.sent, 'systemctl status');
      expect(popover, findsNothing);
      expect(find.text('Ditempel · 1 baris · belum dijalankan'), findsOneWidget);
    });

    testWidgets('tombol Tempel: popover tepat di atas baris kursor, baris prompt tetap terlihat, dalam layar', (
      tester,
    ) async {
      await open(tester, 'ls');
      terminalView(tester).terminal.write('\r\n' * 8);
      await tester.pump();
      await tapPaste(tester);
      final box = tester.getRect(popover);
      final cursor = cursorRect(tester);
      expect(box.bottom, lessThanOrEqualTo(cursor.top));
      expect(box.left, greaterThanOrEqualTo(8));
      expect(box.right, lessThanOrEqualTo(390 - 8));
    });

    testWidgets('saklar mati: teks pendek langsung masuk tanpa popover', (tester) async {
      final rig = await open(tester, 'systemctl status', confirm: false);
      await tapPaste(tester);
      expect(popover, findsNothing);
      expect(rig.shell.sent, 'systemctl status');
    });

    testWidgets('lebih panjang dari ${PasteAnalysis.popoverMaxChars} karakter: dialog, juga bila saklar mati', (
      tester,
    ) async {
      final long = 'a' * (PasteAnalysis.popoverMaxChars + 1);
      for (final confirm in [true, false]) {
        final rig = await open(tester, long, confirm: confirm);
        await tapPaste(tester);
        expect(popover, findsNothing, reason: 'confirm=$confirm');
        expect(find.text('Tempel 1 baris?'), findsOneWidget, reason: 'confirm=$confirm');
        expect(rig.shell.sent, isEmpty);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('tepat di batas ${PasteAnalysis.popoverMaxChars} karakter masih popover', (tester) async {
      await open(tester, 'b' * PasteAnalysis.popoverMaxChars);
      await tapPaste(tester);
      expect(popover, findsOneWidget);
    });

    testWidgets('banyak baris atau berisiko: dialog, bukan popover', (tester) async {
      await open(tester, 'ls\nls');
      await tapPaste(tester);
      expect(popover, findsNothing);
      expect(find.text('Tempel 2 baris?'), findsOneWidget);
    });

    testWidgets('tekan-tahan di area kosong menjalankan alur yang sama, popover di atas jari dan dalam layar', (
      tester,
    ) async {
      await open(tester, 'ls -la');
      final finger = Offset(14, cursorRect(tester).center.dy + 90);
      await holdAt(tester, finger);
      expect(popover, findsOneWidget);
      final box = tester.getRect(popover);
      expect(box.left, greaterThanOrEqualTo(8));
      expect(box.right, lessThanOrEqualTo(390 - 8));
      expect(box.bottom, lessThan(finger.dy));
    });

    testWidgets('tekan-tahan di area kosong dengan papan klip kosong: toast, tanpa popover', (tester) async {
      await open(tester, null);
      await holdAt(tester, Offset(14, cursorRect(tester).center.dy + 90));
      expect(popover, findsNothing);
      expect(find.text('Papan klip kosong'), findsOneWidget);
    });

    testWidgets('tekan-tahan di atas teks memilih kata dan tidak membuka popover', (tester) async {
      await open(tester, 'ls');
      await holdAt(tester, Offset(cursorRect(tester).left - 40, cursorRect(tester).center.dy));
      expect(popover, findsNothing);
      expect(terminalView(tester).controller!.selection, isNotNull);
    });

    testWidgets('ketukan di luar popover menutupnya: di terminal, di bar atas, atau di tombol cepat', (tester) async {
      await open(tester, 'ls');

      await tapPaste(tester);
      expect(popover, findsOneWidget);
      await tester.tapAt(const Offset(200, 500)); // terminal
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(popover, findsNothing);

      await tapPaste(tester);
      expect(popover, findsOneWidget);
      await tester.tapAt(const Offset(200, 30)); // bar atas
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(popover, findsNothing);

      await tapPaste(tester);
      expect(popover, findsOneWidget);
      await tester.tap(find.byType(KeyButton).at(1)); // tombol cepat (tanpa Esc)
      await tester.pumpAndSettle();
      expect(popover, findsNothing);
    });

    testWidgets('ketukan di dalam popover (di luar tombol Tempel) tidak menutupnya', (tester) async {
      await open(tester, 'ls');
      await tapPaste(tester);
      final box = tester.getRect(find.byKey(const ValueKey('paste-popover-text')));
      await tester.tapAt(box.center);
      await tester.pumpAndSettle();
      expect(popover, findsOneWidget);
    });

    testWidgets('tombol Tempel saat popover terbuka: tetap ada satu popover', (tester) async {
      await open(tester, 'ls');
      await tapPaste(tester);
      await tapPaste(tester);
      expect(popover, findsOneWidget);
    });

    testWidgets('keluaran yang menggeser kursor menutup popover', (tester) async {
      await open(tester, 'ls');
      await tapPaste(tester);
      expect(popover, findsOneWidget);
      terminalView(tester).terminal.write('x');
      await tester.pump();
      expect(popover, findsNothing);
    });

    testWidgets('landscape ringkas dengan keyboard (area terminal sempit): popover tetap tampil utuh di dalam layar', (
      tester,
    ) async {
      setClipboard(tester, 'ls -la');
      await pumpTerminal(tester, size: const Size(853, 393), keyboard: 209);
      terminalView(tester).terminal.write('user@host:~\$ ');
      await tester.pump();
      final cursor = tester.state<TerminalViewState>(find.byType(TerminalView)).globalCursorRect;

      // Dari tombol Tempel dan dari tekan-tahan di sisa baris prompt.
      await tapPaste(tester);
      expect(popover, findsOneWidget);
      var box = tester.getRect(popover);
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(393));
      expect(box.left, greaterThanOrEqualTo(8));
      expect(box.right, lessThanOrEqualTo(853 - 8));
      await tester.tapAt(const Offset(600, 200)); // ketukan di luar menutup
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(popover, findsNothing);

      await holdAt(tester, Offset(600, cursor.center.dy));
      expect(popover, findsOneWidget);
      box = tester.getRect(popover);
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(393));
    });

    testWidgets('layar alternatif (tmux, vim): tekan-tahan di sel kosong membuka popover', (tester) async {
      await open(tester, 'ls');
      terminalView(tester).terminal.write('\x1b[?1049h');
      await tester.pump();
      await holdAt(tester, const Offset(14, 400));
      expect(popover, findsOneWidget);
    });

    testWidgets('mouse mode (tmux -mouse): tekan-tahan di sel kosong tetap membuka popover', (tester) async {
      await open(tester, 'ls');
      terminalView(tester).terminal.write('\x1b[?1000h\x1b[?1006h');
      await tester.pump();
      await holdAt(tester, const Offset(14, 400));
      expect(popover, findsOneWidget);
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

    testWidgets('saklar mati, satu baris aman: langsung ke prompt tanpa Enter, toast menyebut belum dijalankan', (
      tester,
    ) async {
      setClipboard(tester, 'systemctl status nginx');
      final rig = await pumpTerminal(tester, confirmSingleLinePaste: false);
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
