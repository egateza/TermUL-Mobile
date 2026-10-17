import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/storage/snippet_repository.dart';
import 'package:termul_mobile/features/snippets/snippet_panel.dart';
import 'package:termul_mobile/features/snippets/snippets_screen.dart';
import 'package:termul_mobile/shared/widgets/termul_button.dart';
import 'package:termul_mobile/shared/widgets/termul_icon_button.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import '../hosts_ui_harness.dart';
import '../reconnect_test.dart' show FakeNet, start;
import '../sessions_test.dart' show chooseKeep;

const _status = Snippet(id: 'a', title: 'Status layanan', command: r'systemctl status ${layanan}');
const _plain = Snippet(id: 'b', title: 'Cek disk', command: 'df -h /');
const _multi = Snippet(id: 'c', title: 'Dua baris', command: 'df -h /\ndu -sh /var/log\n');
const _marked = Snippet(id: 'd', title: 'Restart', command: 'sudo systemctl restart nginx', dangerous: true);
const _auto = Snippet(id: 'e', title: 'Bersihkan', command: 'sudo rm -rf /tmp/x');
const _otherHost = Snippet(id: 'f', title: 'Khusus host lain', command: 'uptime', hostId: id2);
const _thisHost = Snippet(id: 'g', title: 'Khusus app-01', command: 'hostname', hostId: id1);

Future<(Harness, FakeNet)> startWith(WidgetTester tester, List<Snippet> snippets) async {
  final (h, net, _) = await start(
    tester,
    overrides: [snippetRepositoryProvider.overrideWithValue(MemorySnippetRepository(snippets))],
  );
  return (h, net);
}

Future<void> openPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Snippet'));
  await tester.pumpAndSettle();
  expect(find.byType(SnippetPanel), findsOneWidget);
}

Finder inPanel(Finder f) => find.descendant(of: find.byType(SnippetPanel), matching: f);

Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

void main() {
  group('dari terminal (ikon Snippet dan panel di bawah bilah tombol cepat)', () {
    testWidgets('ikon Snippet tetap di kiri bilah; panel menampilkan snippet untuk semua host atau host ini saja', (
      tester,
    ) async {
      await startWith(tester, [_plain, _otherHost, _thisHost]);
      expect(find.byTooltip('Snippet'), findsOneWidget);
      expect(find.byType(SnippetPanel), findsNothing);
      await openPanel(tester);
      expect(inPanel(find.text('Cek disk')), findsOneWidget);
      expect(inPanel(find.text('Khusus app-01')), findsOneWidget);
      expect(inPanel(find.text('Khusus host lain')), findsNothing);
      expect(inPanel(find.text('Kelola semua')), findsOneWidget);
      // Menyala saat terbuka, dan ketuk lagi menutup.
      expect(
        tester
            .widget<TermulIconButton>(find.byWidgetPredicate((w) => w is TermulIconButton && w.label == 'Snippet'))
            .pressed,
        isTrue,
      );
      await tester.tap(find.byTooltip('Snippet'));
      await tester.pumpAndSettle();
      expect(find.byType(SnippetPanel), findsNothing);
    });

    testWidgets('tanpa snippet untuk host ini: panel menyuruh membuat di tab Snippet', (tester) async {
      await startWith(tester, [_otherHost]);
      await openPanel(tester);
      expect(find.text('Belum ada snippet untuk host ini. Buat di tab Snippet.'), findsOneWidget);
    });

    testWidgets('perintah berbahaya diberi kata "berbahaya" di barisnya', (tester) async {
      await startWith(tester, [_plain, _marked, _auto]);
      await openPanel(tester);
      expect(inPanel(find.text('berbahaya')), findsNWidgets(2));
    });

    testWidgets('ketuk snippet satu baris yang aman: langsung masuk ke prompt tanpa Enter, panel menutup', (
      tester,
    ) async {
      final (_, net) = await startWith(tester, [_plain]);
      await openPanel(tester);
      await tester.tap(inPanel(find.text('Cek disk')));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, 'df -h /');
      expect(find.byType(SnippetPanel), findsNothing);
      expect(find.textContaining('belum dijalankan'), findsOneWidget);
    });

    testWidgets('ketuk snippet banyak baris: dialog tempel dulu; Tempel mengirim baris dengan Enter', (tester) async {
      final (_, net) = await startWith(tester, [_multi]);
      await openPanel(tester);
      await tester.tap(inPanel(find.text('Dua baris')));
      await tester.pumpAndSettle();
      expect(find.text('Tempel 2 baris?'), findsOneWidget);
      expect(net.shells[0].sent, isEmpty);
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, contains('df -h /'));
      expect(net.shells[0].sent, contains('du -sh /var/log'));
    });

    testWidgets('ketuk snippet yang terdeteksi berisiko (rm -rf): dialog dengan peringatan, Batal jadi tombol utama', (
      tester,
    ) async {
      final (_, net) = await startWith(tester, [_auto]);
      await openPanel(tester);
      await tester.tap(inPanel(find.text('Bersihkan')));
      await tester.pumpAndSettle();
      expect(find.textContaining('baris berisiko'), findsOneWidget);
      expect(
        tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Batal')).variant,
        TermulButtonVariant.primary,
      );
      expect(net.shells[0].sent, isEmpty);
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, 'sudo rm -rf /tmp/x');
    });

    testWidgets('ketuk snippet yang ditandai berbahaya: peringatan dulu; Batal tidak menempel, Tetap tempel menempel', (
      tester,
    ) async {
      final (_, net) = await startWith(tester, [_marked]);
      await openPanel(tester);
      await tester.tap(inPanel(find.text('Restart')));
      await tester.pumpAndSettle();
      expect(find.text('Perintah berbahaya'), findsOneWidget);
      expect(net.shells[0].sent, isEmpty);
      expect(
        tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Batal')).variant,
        TermulButtonVariant.primary,
      );
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, isEmpty);

      await openPanel(tester);
      await tester.tap(inPanel(find.text('Restart')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap tempel'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, 'sudo systemctl restart nginx');
    });

    testWidgets('snippet berisi variabel: ketuk membuka detail untuk mengisi; tujuan sesi ini, tanpa Edit dan Hapus', (
      tester,
    ) async {
      final (_, net) = await startWith(tester, [_status]);
      await openPanel(tester);
      await tester.tap(inPanel(find.text('Status layanan')));
      await tester.pumpAndSettle();
      expect(find.byType(SnippetPanel), findsNothing);
      expect(find.text('Kirim ke'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.byTooltip('Hapus'), findsNothing);
      expect(tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Tempel ke app-01')).onPressed, isNull);
      expect(find.text('Isi semua variabel untuk menempel atau menyalin.'), findsOneWidget);

      await tester.enterText(inputByLabel('layanan'), 'sshd');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel ke app-01'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, 'systemctl status sshd');
      expect(find.text('Ditempel ke app-01 · belum dijalankan'), findsOneWidget);
    });

    testWidgets('tekan lama baris: detail dengan Tempel & jalankan (menambah Enter) dan Salin', (tester) async {
      final (_, net) = await startWith(tester, [_plain, _multi]);
      await openPanel(tester);
      await tester.longPress(inPanel(find.text('Cek disk')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TermulButton, 'Salin'), findsOneWidget);
      await tester.tap(find.text('Tempel & jalankan'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, 'df -h /\r');
      expect(find.text('Dijalankan di app-01'), findsOneWidget);

      // Baris baru di ujung perintah tidak menggandakan Enter.
      net.shells[0].clear();
      await tester.pump(const Duration(seconds: 3)); // toast sebelumnya hilang dulu
      await tester.pumpAndSettle();
      await openPanel(tester);
      await tester.longPress(inPanel(find.text('Dua baris')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tempel & jalankan'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, 'df -h /\rdu -sh /var/log\r');
    });

    testWidgets('perintah berbahaya di detail dari terminal: Tempel & jalankan nonaktif, Tempel meminta peringatan', (
      tester,
    ) async {
      final (_, net) = await startWith(tester, [_marked]);
      await openPanel(tester);
      await tester.longPress(inPanel(find.text('Restart')));
      await tester.pumpAndSettle();
      expect(tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Tempel & jalankan')).onPressed, isNull);
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel ke app-01'));
      await tester.pumpAndSettle();
      expect(find.text('Perintah berbahaya'), findsOneWidget);
      expect(net.shells[0].sent, isEmpty);
      await tester.tap(find.text('Tetap tempel'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, 'sudo systemctl restart nginx');
    });

    testWidgets('karakter kontrol berbahaya di perintah dibuang saat dikirim dari detail', (tester) async {
      final (_, net) = await startWith(tester, [const Snippet(id: 'x', title: 'Aneh', command: 'ls\x1b[31m -l')]);
      await openPanel(tester);
      await tester.longPress(inPanel(find.text('Aneh')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TermulButton, 'Tempel ke app-01'));
      await tester.pumpAndSettle();
      expect(net.shells[0].sent, isNot(contains('\x1b')));
      expect(net.shells[0].sent, contains('ls'));
    });

    testWidgets('Kelola semua membuka tab Snippet', (tester) async {
      await startWith(tester, [_plain]);
      await openPanel(tester);
      await tester.tap(inPanel(find.text('Kelola semua')));
      await tester.pumpAndSettle();
      expect(find.byType(SnippetsScreen), findsOneWidget);
      expect(find.byTooltip('Snippet baru'), findsOneWidget);
    });
  });

  group('dari tab Snippet (tanpa tempel ke sesi)', () {
    Future<void> toSnippetTab(WidgetTester tester) async {
      await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Snippet')));
      await tester.pumpAndSettle();
    }

    testWidgets('sesi di latar belakang tidak menjadi tujuan: hanya Salin dan Edit, tanpa "Kirim ke"', (tester) async {
      final (_, net) = await startWith(tester, [_plain]);
      await chooseKeep(tester);
      await toSnippetTab(tester);
      await tester.tap(find.text('Cek disk'));
      await tester.pumpAndSettle();
      expect(find.text('Kirim ke'), findsNothing);
      expect(find.textContaining('Tempel'), findsNothing);
      expect(find.widgetWithText(TermulButton, 'Salin'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byTooltip('Hapus'), findsOneWidget);
      expect(net.shells[0].sent, isEmpty);
    });
  });
}
