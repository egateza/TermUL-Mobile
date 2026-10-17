import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/features/hosts/host_list_screen.dart';
import 'package:termul_mobile/features/sessions/sessions_screen.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';
import 'package:termul_mobile/features/snippets/snippets_screen.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import 'hosts_ui_harness.dart';

Finder tab(String label) => find.descendant(of: find.byType(TermulNavBar), matching: find.text(label));

void main() {
  testWidgets('lima tab; Host aktif dan tab lain dibangun saat pertama dibuka', (tester) async {
    await Harness().pump(tester);
    expect(find.byType(HostListScreen), findsOneWidget);
    expect(find.byType(SessionsScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);
    final bar = tester.widget<TermulNavBar>(find.byType(TermulNavBar));
    expect(bar.items.map((i) => i.label), ['Host', 'Sesi', 'Snippet', 'Pengaturan']);
    expect(bar.active, 'hosts');
  });

  testWidgets('tab Sesi dan Pengaturan tanpa tombol Kembali; tab Snippet membuka layar Snippet; tidak ada tab SFTP', (
    tester,
  ) async {
    await Harness().pump(tester);
    await tester.tap(tab('Sesi'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionsScreen), findsOneWidget);
    expect(find.text('Tidak ada sesi di latar belakang'), findsOneWidget);
    expect(find.bySemanticsLabel('Kembali'), findsNothing);

    expect(tab('SFTP'), findsNothing);

    await tester.tap(tab('Snippet'));
    await tester.pumpAndSettle();
    expect(find.byType(SnippetsScreen), findsOneWidget);
    expect(find.text('Belum ada snippet'), findsOneWidget);

    await tester.tap(tab('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Kembali'), findsNothing);
  });

  testWidgets('pencarian di Host bertahan saat berpindah tab', (tester) async {
    await Harness().pump(tester);
    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.pump();
    await tester.tap(tab('Snippet'));
    await tester.pumpAndSettle();
    await tester.tap(tab('Host'));
    await tester.pumpAndSettle();
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('tombol kembali dari tab lain menuju Host dulu', (tester) async {
    await Harness().pump(tester);
    await tester.tap(tab('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<TermulNavBar>(find.byType(TermulNavBar)).active, 'hosts');
  });

  testWidgets('tab aktif memakai aksen dan target sentuh tab minimal 56 dp; bar tersembunyi saat keyboard terbuka', (
    tester,
  ) async {
    await Harness().pump(tester);
    for (final label in ['Host', 'Sesi', 'Snippet', 'Pengaturan']) {
      final size = tester.getSize(find.ancestor(of: tab(label), matching: find.byType(InkWell)).first);
      expect(size.height, greaterThanOrEqualTo(56), reason: label);
    }
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(find.byType(TermulNavBar), findsNothing);
  });
}
