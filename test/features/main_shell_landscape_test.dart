import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/features/hosts/host_list_screen.dart';
import 'package:termul_mobile/features/sessions/sessions_screen.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:termul_mobile/shared/widgets/termul_chip.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import 'hosts_ui_harness.dart';

/// Ukuran HP di landscape (dp), seperti di test layout terminal.
const landscape = Size(853, 393);

String _uuid(int i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';

Finder railTab(String label) => find.descendant(of: find.byType(TermulNavRail), matching: find.text(label));

void main() {
  testWidgets('landscape: rel navigasi di kiri menggantikan bar bawah, empat tab, tinggi tab minimal 44 dp', (
    tester,
  ) async {
    await Harness().pump(tester, size: landscape);
    expect(find.byType(TermulNavBar), findsNothing);
    expect(find.byType(TermulNavRail), findsOneWidget);
    final rail = tester.widget<TermulNavRail>(find.byType(TermulNavRail));
    expect(rail.items.map((i) => i.label), ['Host', 'Sesi', 'Snippet', 'Pengaturan']);
    expect(rail.active, 'hosts');
    expect(tester.getRect(find.byType(TermulNavRail)).left, 0);
    expect(tester.getSize(find.byType(TermulNavRail)).width, TermulNavRail.width);
    for (final label in ['Host', 'Sesi', 'Snippet', 'Pengaturan']) {
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

  testWidgets('landscape: berpindah tab lewat rel; rel disembunyikan saat keyboard terbuka dan kembali sesudahnya', (
    tester,
  ) async {
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
    expect(find.byType(TermulNavRail), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget, reason: 'halaman tidak dibangun ulang');
    tester.view.viewInsets = FakeViewPadding.zero;
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
      expect(find.byType(DropdownPill), findsOneWidget);

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

  testWidgets('landscape: filter jadi satu dropdown; memilih Favorit menyaring dan mengubah label tombol', (
    tester,
  ) async {
    final h = Harness();
    await h.seed(
      [host(_uuid(1), name: 'alfa'), host(_uuid(2), name: 'bravo', hostName: '192.0.2.12')],
      favorites: [_uuid(2)],
    );
    await h.pump(tester, size: landscape);

    expect(find.byType(FilterChipButton), findsNothing, reason: 'chip diganti dropdown di landscape');
    expect(find.byType(DropdownPill), findsOneWidget);
    expect(find.descendant(of: find.byType(DropdownPill), matching: find.text('Semua')), findsOneWidget);
    expect(find.text('alfa'), findsOneWidget);

    await tester.tap(find.byType(DropdownPill));
    await tester.pumpAndSettle();
    expect(find.text('Filter host'), findsOneWidget);
    // Satu tombol per nilai HostFilter, sehingga filter baru ikut otomatis.
    expect(find.text('Semua'), findsNWidgets(2));
    expect(find.text('Favorit'), findsOneWidget);
    await tester.tap(find.text('Favorit'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(DropdownPill), matching: find.text('Favorit')), findsOneWidget);
    expect(tester.widget<DropdownPill>(find.byType(DropdownPill)).active, isTrue);
    expect(find.text('bravo'), findsOneWidget);
    expect(find.text('alfa'), findsNothing);
  });

  testWidgets('potret tetap memakai chip Semua dan Favorit', (tester) async {
    await Harness().pump(tester);
    expect(find.byType(FilterChipButton), findsNWidgets(2));
    expect(find.byType(DropdownPill), findsNothing);
  });

  testWidgets('landscape dengan keyboard terbuka: pencarian tetap fokus dan daftar host tetap terlihat', (
    tester,
  ) async {
    final h = Harness();
    await h.seed([for (var i = 0; i < 6; i++) host(_uuid(i + 1), name: 'server-$i', hostName: '192.0.2.${10 + i}')]);
    await h.pump(tester, size: landscape);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 209);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    // Kolom pencarian tidak kehilangan fokus (keyboard tidak menutup sendiri) dan filter/tombol tambah menyingkir.
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode?.hasFocus ?? true, isTrue);
    expect(find.byType(DropdownPill), findsNothing);
    expect(find.bySemanticsLabel('Tambah host'), findsNothing);
    expect(find.text('TANPA GRUP'), findsNothing, reason: 'judul grup disembunyikan selagi mengetik');

    // Paling sedikit satu baris host terlihat utuh di atas keyboard.
    final visibleHeight = landscape.height - 209;
    final rows = find.byType(HostRow);
    expect(rows, findsWidgets);
    final fully = rows.evaluate().where((e) => tester.getRect(find.byWidget(e.widget)).bottom <= visibleHeight);
    expect(fully.length, greaterThanOrEqualTo(1));

    // Keyboard turun: judul, dropdown, dan tombol tambah kembali.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byType(DropdownPill), findsOneWidget);
    expect(find.bySemanticsLabel('Tambah host'), findsOneWidget);
    expect(find.text('TANPA GRUP'), findsOneWidget);
  });

  testWidgets('landscape: ikon dan label tiap tab rel sejajar di tengah, rel di tengah tinggi layar', (tester) async {
    await Harness().pump(tester, size: landscape);
    final rail = tester.getRect(find.byType(TermulNavRail));
    final centers = <double>[];
    for (final label in ['Host', 'Sesi', 'Snippet', 'Pengaturan']) {
      final tab = tester.getRect(find.ancestor(of: railTab(label), matching: find.byType(InkWell)).first);
      centers.add(tester.getCenter(railTab(label)).dx - tab.center.dx);
    }
    for (final c in centers) {
      expect(c.abs(), lessThan(1.5), reason: 'label harus di tengah lebar tab');
    }
    final first = tester.getRect(find.ancestor(of: railTab('Host'), matching: find.byType(InkWell)).first);
    final last = tester.getRect(find.ancestor(of: railTab('Pengaturan'), matching: find.byType(InkWell)).first);
    final groupCenter = (first.top + last.bottom) / 2;
    expect(groupCenter, closeTo((rail.top + rail.bottom) / 2, 12));
  });

  testWidgets('potret dengan keyboard terbuka: tinggi keyboard dikurangi sekali saja, daftar host tetap terlihat', (
    tester,
  ) async {
    final h = Harness();
    await h.seed([for (var i = 0; i < 6; i++) host(_uuid(i + 1), name: 'server-$i', hostName: '192.0.2.${10 + i}')]);
    await h.pump(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byType(ListView).first);
    // Area di atas keyboard (844 - 300 = 544) dipakai daftar: bukan 544 - 300 lagi.
    expect(list.bottom, closeTo(844 - 300, 1));
    expect(list.height, greaterThan(150));
  });
}
