import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';

import 'hosts_ui_harness.dart';

/// Membuka layar Pengaturan dari daftar host, dengan penyimpanan palsu yang mencatat setiap simpanan.
class _Setup {
  final saved = <AppSettings>[];
  Object? saveError;

  Future<void> save(AppSettings s) async {
    if (saveError != null) throw saveError!;
    saved.add(s);
  }

  Future<Harness> open(WidgetTester tester, {AppSettings initial = const AppSettings()}) async {
    final h = Harness(settings: initial, saveSettings: save);
    await h.pump(tester);
    await tester.tap(find.bySemanticsLabel('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    return h;
  }
}

AppSettings _current(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SettingsScreen))).read(appSettingsProvider);

double _previewFontSize(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(of: find.byKey(const ValueKey('settings-preview')), matching: find.byType(Text)),
  );
  return text.textSpan!.style!.fontSize!;
}

void main() {
  testWidgets('menampilkan bagian Terminal dengan nilai bawaan dan pratinjau', (tester) async {
    await _Setup().open(tester);
    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('TERMINAL'), findsOneWidget);
    expect(find.text('Ukuran font'), findsOneWidget);
    expect(find.text('13 px'), findsOneWidget);
    expect(find.text('Tinggi baris'), findsOneWidget);
    expect(find.text('1,3×'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-preview')), findsOneWidget);
    expect(_previewFontSize(tester), 13);
  });

  testWidgets('tombol font mengubah nilai, pratinjau, dan menyimpan', (tester) async {
    final setup = _Setup();
    await setup.open(tester);
    await tester.tap(find.bySemanticsLabel('Besarkan font'));
    await tester.pumpAndSettle();
    expect(find.text('14 px'), findsOneWidget);
    expect(_previewFontSize(tester), 14);
    expect(_current(tester).terminal.fontSize, 14);
    expect(setup.saved.last.terminal.fontSize, 14);

    await tester.tap(find.bySemanticsLabel('Kecilkan font'));
    await tester.tap(find.bySemanticsLabel('Kecilkan font'));
    await tester.pumpAndSettle();
    expect(find.text('12 px'), findsOneWidget);
    expect(setup.saved.last.terminal.fontSize, 12);
  });

  testWidgets('tinggi baris bergerak 0,1 tanpa sisa desimal', (tester) async {
    final setup = _Setup();
    await setup.open(tester);
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.pumpAndSettle();
    expect(find.text('1,6×'), findsOneWidget);
    expect(setup.saved.last.terminal.lineHeight, 1.6);
    await tester.tap(find.bySemanticsLabel('Rapatkan baris'));
    await tester.pumpAndSettle();
    expect(setup.saved.last.terminal.lineHeight, 1.5);
  });

  testWidgets('di batas rentang tombol nonaktif', (tester) async {
    final setup = _Setup();
    await setup.open(tester, initial: const AppSettings(terminal: TerminalSettings(fontSize: 8, lineHeight: 2.0)));
    expect(find.text('8 px'), findsOneWidget);
    expect(find.text('2,0×'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Kecilkan font'));
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.pumpAndSettle();
    expect(setup.saved, isEmpty);
    expect(_current(tester).terminal.fontSize, 8);
  });

  testWidgets('Kembalikan bawaan menulis nilai bawaan dan nonaktif bila sudah bawaan', (tester) async {
    final setup = _Setup();
    await setup.open(tester, initial: const AppSettings(terminal: TerminalSettings(fontSize: 18, lineHeight: 1.8)));
    await tester.tap(find.text('Kembalikan bawaan'));
    await tester.pumpAndSettle();
    expect(setup.saved.single.terminal, const TerminalSettings());
    expect(find.text('13 px'), findsOneWidget);
    await tester.tap(find.text('Kembalikan bawaan'));
    await tester.pumpAndSettle();
    expect(setup.saved, hasLength(1));
  });

  testWidgets('gagal menyimpan: banner tampil, nilai tetap berlaku, hilang setelah berhasil', (tester) async {
    final setup = _Setup()..saveError = const FormatException('disk penuh');
    await setup.open(tester);
    await tester.tap(find.bySemanticsLabel('Besarkan font'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan tidak tersimpan'), findsOneWidget);
    expect(_current(tester).terminal.fontSize, 14);
    setup.saveError = null;
    await tester.tap(find.bySemanticsLabel('Besarkan font'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan tidak tersimpan'), findsNothing);
    expect(setup.saved.single.terminal.fontSize, 15);
  });

  testWidgets('target sentuh tombol langkah minimal 44 px dan Kembali menutup layar', (tester) async {
    await _Setup().open(tester);
    for (final label in ['Kecilkan font', 'Besarkan font', 'Rapatkan baris', 'Renggangkan baris']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(TermulSize.tapMin), reason: label);
      expect(size.height, greaterThanOrEqualTo(TermulSize.tapMin), reason: label);
    }
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });
}
