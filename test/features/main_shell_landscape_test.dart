import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/features/hosts/host_list_screen.dart';
import 'package:termul_mobile/features/sessions/sessions_screen.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import 'hosts_ui_harness.dart';

/// Ukuran HP di landscape (dp), seperti di test layout terminal.
const landscape = Size(853, 393);

String _uuid(int i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';

Finder railTab(String label) => find.descendant(of: find.byType(TermulNavRail), matching: find.text(label));

void main() {
  testWidgets('landscape: rel navigasi di kiri menggantikan bar bawah, lima tab, tinggi tab minimal 44 dp', (
    tester,
  ) async {
    await Harness().pump(tester, size: landscape);
    expect(find.byType(TermulNavBar), findsNothing);
    expect(find.byType(TermulNavRail), findsOneWidget);
    final rail = tester.widget<TermulNavRail>(find.byType(TermulNavRail));
    expect(rail.items.map((i) => i.label), ['Host', 'Sesi', 'SFTP', 'Snippet', 'Pengaturan']);
    expect(rail.active, 'hosts');
    expect(tester.getRect(find.byType(TermulNavRail)).left, 0);
    expect(tester.getSize(find.byType(TermulNavRail)).width, TermulNavRail.width);
    for (final label in ['Host', 'Sesi', 'SFTP', 'Snippet', 'Pengaturan']) {
      final size = tester.getSize(find.ancestor(of: railTab(label), matching: find.byType(InkWell)).first);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
    // Semua tab muat di layar tanpa digulir.
    expect(tester.getRect(railTab('Pengaturan')).bottom, lessThan(landscape.height));
  });

  testWidgets('potret tetap memakai bar bawah, tanpa rel', (tester) async {
    await Harness().pump(tester);
    expect(find.byType(TermulNavBar), findsOneWidget);
    expect(find.byType(TermulNavRail), findsNothing);
  });

  testWidgets('landscape: berpindah tab lewat rel; rel tetap ada saat keyboard terbuka', (tester) async {
    await Harness().pump(tester, size: landscape);
    await tester.tap(railTab('Sesi'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionsScreen), findsOneWidget);
    await tester.tap(railTab('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.widget<TermulNavRail>(find.byType(TermulNavRail)).active, 'settings');

    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(find.byType(TermulNavRail), findsOneWidget);
  });

  testWidgets(
    'landscape: daftar host tidak terhalang header; satu baris header, daftar memakai sebagian besar tinggi',
    (tester) async {
      final h = Harness();
      await h.seed([for (var i = 0; i < 8; i++) host(_uuid(i), name: 'server-$i', hostName: '192.0.2.${10 + i}')]);
      await h.pump(tester, size: landscape);
      expect(find.byType(HostListScreen), findsOneWidget);

      // Judul, pencarian, filter, dan tombol tambah sebaris: pencarian dan tombol tambah sama tinggi barisnya.
      final search = tester.getRect(find.byType(TextField).first);
      final add = tester.getRect(find.bySemanticsLabel('Tambah host'));
      expect(search.center.dy, closeTo(add.center.dy, 6));
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Favorit'), findsOneWidget);

      // Baris host pertama sudah terlihat di separuh atas layar, dan paling sedikit tiga baris tampil.
      final rows = find.byType(HostRow);
      expect(rows, findsWidgets);
      expect(tester.getRect(rows.first).top, lessThan(landscape.height / 2));
      final visible = rows.evaluate().where((e) {
        final r = tester.getRect(find.byWidget(e.widget));
        return r.bottom <= landscape.height;
      }).length;
      expect(visible, greaterThanOrEqualTo(3));
    },
  );

  testWidgets('landscape: pencarian di baris ringkas tetap menyaring daftar', (tester) async {
    final h = Harness();
    await h.seed([host(_uuid(1), name: 'alfa'), host(_uuid(2), name: 'bravo', hostName: '192.0.2.12')]);
    await h.pump(tester, size: landscape);
    await tester.enterText(find.byType(TextField).first, 'bra');
    await tester.pumpAndSettle();
    expect(find.text('bravo'), findsOneWidget);
    expect(find.text('alfa'), findsNothing);
  });
}
