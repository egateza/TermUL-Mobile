import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/storage/load_result.dart';
import 'package:termul_mobile/core/storage/streak_repository.dart';
import 'package:termul_mobile/core/streak/streak.dart';
import 'package:termul_mobile/core/streak/streak_record.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';
import 'package:termul_mobile/features/streak/streak_controller.dart';
import 'package:termul_mobile/features/streak/streak_screen.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import '../hosts_ui_harness.dart';

/// Rabu, 14 Oktober 2026, pukul 09.00.
final start = DateTime(2026, 10, 14, 9);
DateTime daysAgo(int n) => DateTime.utc(2026, 10, 14).subtract(Duration(days: n));

class Clock {
  DateTime now = start;
  DateTime call() => now;
}

Finder chip() => find.byKey(const ValueKey('streak-chip'));
Finder hero() => find.byKey(const ValueKey('streak-hero-flame'));

Future<({Harness harness, MemoryStreakRepository repo, Clock clock})> open(
  WidgetTester tester, {
  StreakRecord? record,
  AppSettings settings = const AppSettings(),
  BootReport report = const BootReport(),
}) async {
  // Api bergoyang tanpa henti; reduce motion mematikannya sehingga pumpAndSettle bisa selesai.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final repo = MemoryStreakRepository(record);
  final clock = Clock();
  final harness = Harness(streak: repo, settings: settings, report: report);
  await harness.pump(tester, overrides: [streakClockProvider.overrideWithValue(clock.call)]);
  await tester.pumpAndSettle();
  return (harness: harness, repo: repo, clock: clock);
}

/// Menggulir layar Streak sampai [finder] terlihat (kartu bawah baru dibangun saat digulir).
Future<void> scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
  finder,
  300,
  scrollable: find.descendant(of: find.byType(StreakScreen), matching: find.byType(Scrollable)).first,
);

Future<void> openStreakTab(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Streak')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pertama kali dibuka: hari ke-1 tersimpan, chip menulis 1/3', (tester) async {
    final s = await open(tester);
    expect(s.repo.record.streak, Streak(1, daysAgo(0)));
    expect(s.repo.record.days, [daysAgo(0)]);
    expect(find.descendant(of: chip(), matching: find.text('1/3')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Hari ke-1 dari 3 menuju streak')), findsOneWidget);
  });

  testWidgets('streak aktif: chip 11x membuka tab Streak dengan angka, level, dan lencana', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(10, daysAgo(1)), days: [daysAgo(2), daysAgo(1)]));
    expect(s.repo.record.streak.count, 11);
    expect(find.descendant(of: chip(), matching: find.text('11x')), findsOneWidget);
    await tester.tap(chip());
    await tester.pumpAndSettle();
    expect(find.byType(StreakScreen), findsOneWidget);
    expect(find.text('11'), findsWidgets);
    expect(find.text('Hari ini selesai'), findsOneWidget);
    expect(find.text('Hari ini terhitung sejak aplikasi dibuka. Sampai jumpa besok.'), findsOneWidget);
    await scrollTo(tester, find.text('Menuju Level 4 · hari ke-30'));
    expect(find.text('3 · Api Merah'), findsOneWidget);
    expect(find.text('Tinggal 19 hari lagi.'), findsOneWidget);
    await scrollTo(tester, find.text('Oktober 2026'));
    expect(find.bySemanticsLabel('Level 3, Api Merah, level sekarang'), findsOneWidget);
  });

  testWidgets('padam: tiga ketukan cepat menyalakan api, hari ini terhitung dan tersimpan', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(23, daysAgo(2)), longest: 23));
    expect(s.repo.record.streak.count, 23, reason: 'padam: angka belum berubah');
    expect(find.bySemanticsLabel(RegExp('Streak 23 hari padam')), findsOneWidget);
    await openStreakTab(tester);
    expect(find.textContaining('jadi api padam. Ketuk api 3x cepat'), findsOneWidget);
    await scrollTo(tester, find.textContaining('Absen 1 hari (13 Okt): api padam.'));
    await tester.drag(find.byType(StreakScreen), const Offset(0, 3000));
    await tester.pumpAndSettle();

    await tester.tap(hero());
    await tester.pump();
    s.clock.now = s.clock.now.add(const Duration(milliseconds: 200));
    await tester.tap(hero());
    await tester.pump();
    expect(find.text('Sisa 1 ketukan lagi untuk menyalakan api.'), findsOneWidget);
    s.clock.now = s.clock.now.add(const Duration(milliseconds: 200));
    await tester.tap(hero());
    await tester.pumpAndSettle();
    expect(find.text('Api menyala lagi. Hari ini terhitung.'), findsOneWidget);
    expect(s.repo.record.streak, Streak(24, daysAgo(0)));
    expect(s.repo.record.longest, 24);
    expect(find.text('Hari ini selesai'), findsOneWidget);
  });

  testWidgets('padam: ketukan yang terlalu lambat tidak dihitung beruntun', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(23, daysAgo(2))));
    await openStreakTab(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(hero());
      await tester.pump();
      s.clock.now = s.clock.now.add(const Duration(milliseconds: 600));
    }
    expect(s.repo.record.streak.count, 23);
    expect(find.text('Sisa 2 ketukan lagi untuk menyalakan api.'), findsOneWidget);
  });

  testWidgets('beku: absen 5 hari butuh 7 ketukan, es pecah melanjutkan streak', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(23, daysAgo(6))));
    expect(find.bySemanticsLabel(RegExp('Streak 23 hari beku')), findsOneWidget);
    await openStreakTab(tester);
    expect(find.text('Kamu absen 5 hari, api membeku. Ketuk api 7 kali untuk memecahkan es.'), findsOneWidget);
    await scrollTo(tester, find.textContaining('Absen 5 hari (9-13 Okt): api membeku. Ketuk 7 kali'));
    await tester.drag(find.byType(StreakScreen), const Offset(0, 3000));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(hero());
      await tester.pump();
    }
    expect(find.text('Sisa 1 ketukan lagi untuk memecahkan es.'), findsOneWidget);
    expect(s.repo.record.streak.count, 23);
    await tester.tap(hero());
    await tester.pumpAndSettle();
    expect(find.text('Es pecah! Streak dilanjutkan. Hari ini terhitung.'), findsOneWidget);
    expect(s.repo.record.streak, Streak(24, daysAgo(0)));
  });

  testWidgets('hangus: streak mulai lagi dari 1/3', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(47, daysAgo(12)), longest: 47));
    expect(s.repo.record.streak, Streak(1, daysAgo(0)));
    expect(s.repo.record.longest, 47);
    expect(find.descendant(of: chip(), matching: find.text('1/3')), findsOneWidget);
  });

  testWidgets('tanggal berganti selagi terbuka dihitung saat aplikasi kembali ke depan', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(5, daysAgo(1))));
    expect(s.repo.record.streak.count, 6);
    s.clock.now = start.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(s.repo.record.streak.count, 7);
    expect(find.descendant(of: chip(), matching: find.text('7x')), findsOneWidget);
  });

  testWidgets('"Tampilkan streak api" mati: chip hilang, hari tetap dihitung', (tester) async {
    final s = await open(tester, settings: const AppSettings(streak: StreakSettings(show: false)));
    expect(chip(), findsNothing);
    expect(s.repo.record.streak.count, 1);
  });

  testWidgets('berkas streak rusak: banner menyebut nama berkas dan bisa ditutup', (tester) async {
    await open(
      tester,
      report: const BootReport(streak: LoadResult(quarantinedPath: r'C:\data\streak.json.corrupt-1')),
    );
    await openStreakTab(tester);
    expect(find.text('Data streak rusak'), findsOneWidget);
    expect(find.textContaining('streak.json.corrupt-1'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Data streak rusak'), findsNothing);
  });

  testWidgets('bantuan terbuka dari header; tautan Pengaturan pindah ke tab Pengaturan', (tester) async {
    await open(tester);
    await openStreakTab(tester);
    await tester.tap(find.bySemanticsLabel('Bantuan: cara kerja streak'));
    await tester.pumpAndSettle();
    expect(find.text('Cara kerja streak'), findsOneWidget);
    expect(find.text('Contoh jika tidak membuka TermUL'), findsOneWidget);
    await tester.tap(find.text('Atur tampilan streak dan pengingat'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('saklar Pengaturan "Tampilkan streak api" menyembunyikan chip; tersimpan', (tester) async {
    AppSettings? saved;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final harness = Harness(saveSettings: (s) async => saved = s);
    await harness.pump(tester);
    expect(chip(), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Pengaturan')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-streak-show'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(saved?.streak.show, isFalse);
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Host')));
    await tester.pumpAndSettle();
    expect(chip(), findsNothing);
  });
}
