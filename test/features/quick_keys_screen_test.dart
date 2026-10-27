import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/features/settings/quick_keys_screen.dart';

import 'fake_keepalive.dart';
import 'hosts_ui_harness.dart';

/// Membuka Pengaturan lalu "Tombol cepat", dengan penyimpanan palsu yang mencatat setiap simpanan.
Future<List<AppSettings>> _open(WidgetTester tester, {AppSettings initial = const AppSettings()}) async {
  final saved = <AppSettings>[];
  final h = Harness(
    settings: initial,
    saveSettings: (s) async => saved.add(s),
  );
  await h.pump(tester, overrides: [keepAlivePlatformProvider.overrideWithValue(FakeKeepAlive())]);
  await tester.tap(find.bySemanticsLabel('Pengaturan'));
  await tester.pumpAndSettle();
  final row = find.text('Tombol cepat');
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find
        .byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down)
        .first,
  );
  final count = initial.quickKeys.row1.length + initial.quickKeys.row2.length;
  expect(find.text('2 baris · $count tombol'), findsOneWidget);
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(find.byType(QuickKeysScreen), findsOneWidget);
  return saved;
}

QuickKeySettings _current(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(QuickKeysScreen))).read(appSettingsProvider).quickKeys;

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
  finder,
  200,
  scrollable: find
      .descendant(of: find.byType(QuickKeysScreen), matching: find.byType(Scrollable))
      .first,
);

void main() {
  testWidgets('menampilkan dua baris bawaan dengan jumlah dan Kembalikan bawaan nonaktif', (tester) async {
    await _open(tester);
    expect(find.text('BARIS 1'), findsOneWidget);
    expect(find.text('9/10'), findsWidgets);
    expect(find.text('Tombol Escape'), findsOneWidget);
    await _scrollTo(tester, find.text('Kembalikan bawaan'));
    final reset = tester.widget<Semantics>(
      find.ancestor(of: find.text('Kembalikan bawaan'), matching: find.byType(Semantics)).first,
    );
    expect(reset.properties.enabled, isNot(true));
  });

  testWidgets('hapus tombol menyimpan baris tanpa tombol itu', (tester) async {
    final saved = await _open(tester);
    await tester.tap(find.byTooltip('Hapus Garis miring'));
    await tester.pumpAndSettle();
    expect(_current(tester).row1, isNot(contains('slash')));
    expect(saved.last.quickKeys.row1.length, 8);
  });

  testWidgets('tambah dari katalog: tombol terpakai nonaktif, pilihan baru masuk ke akhir baris', (tester) async {
    final saved = await _open(tester);
    await tester.ensureVisible(find.text('Tambah tombol').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah tombol').first);
    await tester.pumpAndSettle();
    expect(find.text('Tambah ke baris 1'), findsOneWidget);
    // Esc sudah dipakai: diketuk tidak menutup sheet.
    await tester.tap(find.byKey(const ValueKey('quick-key-pick-esc')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Tambah ke baris 1'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('quick-key-pick-ctrll')));
    await tester.tap(find.byKey(const ValueKey('quick-key-pick-ctrll')));
    await tester.pumpAndSettle();
    expect(find.text('Tambah ke baris 1'), findsNothing);
    expect(_current(tester).row1.last, 'ctrll');
    expect(saved.last.quickKeys.row1.length, 10);
    expect(find.text('Baris penuh'), findsOneWidget);
  });

  testWidgets('Kembalikan bawaan memulihkan susunan awal', (tester) async {
    await _open(
      tester,
      initial: const AppSettings(quickKeys: QuickKeySettings(row1: ['esc'], row2: ['tab'])),
    );
    expect(find.text('1/10'), findsNWidgets(2));
    await _scrollTo(tester, find.text('Kembalikan bawaan'));
    await tester.tap(find.text('Kembalikan bawaan'));
    await tester.pumpAndSettle();
    expect(_current(tester).isDefault, isTrue);
  });
}
