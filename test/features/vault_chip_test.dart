import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';

import 'hosts_ui_harness.dart';

void main() {
  testWidgets('chip terkunci: ketuk membuka dengan satu prompt, ketuk lagi mengunci', (tester) async {
    final h = Harness();
    await h.pump(tester);
    expect(find.text('Vault terkunci'), findsOneWidget);

    await tester.tap(find.text('Vault terkunci'));
    await tester.pumpAndSettle();
    expect(h.auth.reasons, ['Buka vault supaya host tersambung tanpa prompt']);
    expect(find.text('Vault terbuka'), findsOneWidget);
    expect(find.text('Vault terbuka sampai layar mati'), findsOneWidget);

    await tester.tap(find.text('Vault terbuka'));
    await tester.pumpAndSettle();
    expect(find.text('Vault terkunci'), findsWidgets);
    expect(h.lock.openNow, isFalse);
    expect(h.auth.reasons.length, 1);
  });

  testWidgets('prompt dibatalkan: chip tetap terkunci dengan pesan', (tester) async {
    final h = Harness();
    h.auth.result = false;
    await h.pump(tester);
    await tester.tap(find.text('Vault terkunci'));
    await tester.pumpAndSettle();
    expect(find.text('Vault tetap terkunci'), findsOneWidget);
    expect(h.lock.openNow, isFalse);
  });

  testWidgets('selalu terbuka: chip menyebut terbuka; ketuk memberi keterangan dan tidak mengunci', (tester) async {
    final h = Harness(settings: const AppSettings(security: SecuritySettings(vaultAlwaysOpen: true)));
    await h.pump(tester);
    expect(find.text('Vault terbuka'), findsOneWidget);
    await tester.tap(find.text('Vault terbuka'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Matikan di Pengaturan'), findsOneWidget);
    expect(h.lock.alwaysOpen, isTrue);
    expect(h.auth.reasons, isEmpty);
  });

  group('saklar di Pengaturan', () {
    final saved = <AppSettings>[];
    Future<Harness> open(WidgetTester tester, {bool on = false}) async {
      saved.clear();
      final h = Harness(
        settings: AppSettings(security: SecuritySettings(vaultAlwaysOpen: on)),
        saveSettings: (s) async => saved.add(s),
      );
      await h.pump(tester);
      await tester.tap(find.bySemanticsLabel('Pengaturan'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Jangan kunci vault'),
        300,
        scrollable: find
            .byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down)
            .first,
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('menyalakan: peringatan, lalu satu prompt, lalu tersimpan dan vault terbuka', (tester) async {
      final h = await open(tester);
      await tester.tap(find.text('Jangan kunci vault'));
      await tester.pumpAndSettle();
      expect(find.text('Jangan kunci vault?'), findsOneWidget);
      expect(h.lock.alwaysOpen, isFalse);
      await tester.tap(find.text('Jangan kunci'));
      await tester.pumpAndSettle();
      expect(h.auth.reasons, ['Konfirmasi untuk tidak mengunci vault']);
      expect(h.lock.alwaysOpen, isTrue);
      expect(saved.last.security.vaultAlwaysOpen, isTrue);
    });

    testWidgets('menyalakan dibatalkan di prompt: tetap mati dan tidak tersimpan', (tester) async {
      final h = await open(tester);
      h.auth.result = false;
      await tester.tap(find.text('Jangan kunci vault'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jangan kunci'));
      await tester.pumpAndSettle();
      expect(h.lock.alwaysOpen, isFalse);
      expect(saved, isEmpty);
      expect(find.text('Dibatalkan. Vault tetap terkunci.'), findsOneWidget);
    });

    testWidgets('batal di peringatan: tidak ada prompt dan tidak berubah', (tester) async {
      final h = await open(tester);
      await tester.tap(find.text('Jangan kunci vault'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(h.auth.reasons, isEmpty);
      expect(h.lock.alwaysOpen, isFalse);
      expect(saved, isEmpty);
    });

    testWidgets('mematikan: langsung berlaku tanpa prompt', (tester) async {
      final h = await open(tester, on: true);
      await tester.tap(find.text('Jangan kunci vault'));
      await tester.pumpAndSettle();
      expect(h.auth.reasons, isEmpty);
      expect(h.lock.alwaysOpen, isFalse);
      expect(saved.last.security.vaultAlwaysOpen, isFalse);
      expect(
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen))).read(appSettingsProvider).security,
        const SecuritySettings(),
      );
    });
  });
}
