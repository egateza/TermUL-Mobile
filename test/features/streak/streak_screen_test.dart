import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/storage/load_result.dart';
import 'package:termul_mobile/core/storage/streak_repository.dart';
import 'package:termul_mobile/core/streak/streak.dart';
import 'package:termul_mobile/core/streak/streak_record.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';
import 'package:termul_mobile/features/streak/streak_settings_screen.dart';
import 'package:termul_mobile/features/streak/streak_controller.dart';
import 'package:termul_mobile/features/streak/streak_screen.dart';
import 'package:termul_mobile/features/streak/streak_splash.dart';
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
  bool dismissSplash = true,
}) async {
  // Api bergoyang tanpa henti; reduce motion mematikannya sehingga pumpAndSettle bisa selesai.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final repo = MemoryStreakRepository(record);
  final clock = Clock();
  final harness = Harness(streak: repo, settings: settings, report: report);
  await harness.pump(tester, overrides: [streakClockProvider.overrideWithValue(clock.call)]);
  await tester.pumpAndSettle();
  if (dismissSplash) await closeSplash(tester);
  return (harness: harness, repo: repo, clock: clock);
}

/// Menutup splash streak bila tampil ("Lanjut" atau "Nanti saja").
Future<void> closeSplash(WidgetTester tester) async {
  for (final key in ['streak-splash-continue', 'streak-splash-later']) {
    final f = find.byKey(ValueKey(key));
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f);
      await tester.pumpAndSettle();
    }
  }
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
    final s = await open(
      tester,
      record: StreakRecord(streak: Streak(10, daysAgo(1)), days: [daysAgo(2), daysAgo(1)]),
    );
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
    // Seperti prototipe 8: hari yang dilompati tetap ditandai absen setelah es pecah.
    expect(find.bySemanticsLabel('12 Sen, Okt, absen'), findsOneWidget);
    expect(find.bySemanticsLabel('14 Rab, Okt, aktif'), findsOneWidget);
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
    expect(find.byType(StreakSplash), findsOneWidget, reason: 'hari baru memutar splash');
    await closeSplash(tester);
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

  testWidgets('bantuan terbuka dari header; tautan membuka Pengaturan streak', (tester) async {
    await open(tester);
    await openStreakTab(tester);
    await tester.tap(find.bySemanticsLabel('Bantuan: cara kerja streak'));
    await tester.pumpAndSettle();
    expect(find.text('Cara kerja streak'), findsOneWidget);
    expect(find.text('Contoh jika tidak membuka TermUL'), findsOneWidget);
    await tester.tap(find.text('Atur tampilan streak dan pengingat'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakSettingsScreen), findsOneWidget);
    expect(find.text('Pengaturan streak'), findsOneWidget);
    // Kembali ke tab Streak.
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakScreen), findsOneWidget);
  });

  testWidgets('saklar Pengaturan "Tampilkan streak api" menyembunyikan chip; tersimpan', (tester) async {
    AppSettings? saved;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final harness = Harness(
      saveSettings: (s) async => saved = s,
      streak: MemoryStreakRepository(StreakRecord(streak: Streak(5, DateTime.now()))),
    );
    await harness.pump(tester);
    expect(chip(), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Streak')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Pengaturan streak'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakSettingsScreen), findsOneWidget);
    final row = find.byKey(const ValueKey('settings-streak-show'));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(saved?.streak.show, isFalse);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Host')));
    await tester.pumpAndSettle();
    expect(chip(), findsNothing);
  });

  testWidgets('tab Pengaturan tidak lagi memuat pengaturan streak', (tester) async {
    await open(tester);
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Pengaturan')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.text('Tampilkan streak api'), findsNothing);
    expect(find.text('Pengingat harian'), findsNothing);
    expect(find.text('STREAK'), findsNothing);
  });

  group('splash saat aplikasi dibuka', () {
    testWidgets('hari pertama: bara 1/3 dengan pesan dan Lanjut', (tester) async {
      await open(tester, dismissSplash: false);
      expect(find.byType(StreakSplash), findsOneWidget);
      expect(find.text('STREAK HARIAN'), findsOneWidget);
      expect(find.text('1/3'), findsWidgets);
      expect(find.text('Buka TermUL lagi besok. Streak menyala di hari ke-3.'), findsOneWidget);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.byType(StreakSplash), findsNothing);
    });

    testWidgets('hari ke-3: streak menyala dengan lencana nama level', (tester) async {
      await open(tester, record: StreakRecord(streak: Streak(2, daysAgo(1))), dismissSplash: false);
      expect(find.text('Streak menyala · Api Jingga'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('naik level: lencana Naik level', (tester) async {
      await open(tester, record: StreakRecord(streak: Streak(9, daysAgo(1))), dismissSplash: false);
      expect(find.text('Naik level · Api Merah'), findsOneWidget);
      expect(find.text('HARI STREAK'), findsOneWidget);
    });

    testWidgets('bertambah tanpa naik level: tanpa lencana', (tester) async {
      await open(tester, record: StreakRecord(streak: Streak(22, daysAgo(1))), dismissSplash: false);
      expect(find.byType(StreakSplash), findsOneWidget);
      expect(find.textContaining('Naik level'), findsNothing);
      expect(find.text('23'), findsWidgets);
    });

    testWidgets('padam: diketuk tiga kali cepat di splash, lalu Lanjut', (tester) async {
      final s = await open(tester, record: StreakRecord(streak: Streak(47, daysAgo(2))), dismissSplash: false);
      expect(find.text('Nanti saja'), findsOneWidget);
      expect(find.text('Lanjut'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('streak-splash-flame')));
        await tester.pump();
        s.clock.now = s.clock.now.add(const Duration(milliseconds: 150));
      }
      await tester.pumpAndSettle();
      expect(s.repo.record.streak, Streak(48, daysAgo(0)));
      expect(find.text('Api menyala lagi. Streak lanjut, hari ini ikut dihitung.'), findsOneWidget);
      expect(find.text('Api Magenta'), findsOneWidget);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.byType(StreakSplash), findsNothing);
    });

    testWidgets('beku: Retak c/M bertambah tiap ketukan; Nanti saja menutup tanpa menyalakan', (tester) async {
      final s = await open(tester, record: StreakRecord(streak: Streak(47, daysAgo(6))), dismissSplash: false);
      expect(find.text('Kamu absen 5 hari, api membeku. Ketuk api 7 kali untuk memecahkan es.'), findsOneWidget);
      expect(find.text('Retak 0/7'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('streak-splash-flame')));
      await tester.pumpAndSettle();
      expect(find.text('Retak 1/7'), findsOneWidget);
      await tester.tap(find.text('Nanti saja'));
      await tester.pumpAndSettle();
      expect(find.byType(StreakSplash), findsNothing);
      expect(s.repo.record.streak.count, 47);
      expect(find.bySemanticsLabel(RegExp('Streak 47 hari beku')), findsOneWidget);
    });

    testWidgets('hangus: angka lama dan pesan hangus, lalu mulai lagi 1/3', (tester) async {
      await open(tester, record: StreakRecord(streak: Streak(47, daysAgo(12)), longest: 47), dismissSplash: false);
      // Reduce motion: langsung keadaan akhir (blok "mulai lagi").
      expect(
        find.text('Mulai lagi hari ini. Buka TermUL 3 hari berturut-turut untuk menyalakan streak.'),
        findsOneWidget,
      );
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets('Tampilkan streak api mati: tanpa splash walau hari bertambah', (tester) async {
      await open(
        tester,
        record: StreakRecord(streak: Streak(9, daysAgo(1))),
        settings: const AppSettings(streak: StreakSettings(show: false)),
        dismissSplash: false,
      );
      expect(find.byType(StreakSplash), findsNothing);
    });
  });
}
