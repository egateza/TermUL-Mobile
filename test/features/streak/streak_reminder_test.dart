import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/platform/reminder_platform.dart';
import 'package:termul_mobile/core/storage/streak_repository.dart';
import 'package:termul_mobile/core/streak/streak.dart';
import 'package:termul_mobile/core/streak/streak_record.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';
import 'package:termul_mobile/features/streak/streak_controller.dart';
import 'package:termul_mobile/features/streak/streak_reminder.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import '../fake_keepalive.dart';
import '../hosts_ui_harness.dart';
import 'streak_screen_test.dart' show Clock, closeSplash, daysAgo, start;

Future<({NoopReminder reminder, Clock clock, FakeKeepAlive keepAlive, List<AppSettings> saved})> open(
  WidgetTester tester, {
  required StreakRecord record,
  AppSettings settings = const AppSettings(),
  DateTime? now,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final reminder = NoopReminder();
  final clock = Clock()..now = now ?? start;
  final keepAlive = FakeKeepAlive();
  final saved = <AppSettings>[];
  final harness = Harness(
    streak: MemoryStreakRepository(record),
    settings: settings,
    saveSettings: (s) async => saved.add(s),
  );
  await harness.pump(
    tester,
    overrides: [
      streakClockProvider.overrideWithValue(clock.call),
      reminderPlatformProvider.overrideWithValue(reminder),
      keepAlivePlatformProvider.overrideWithValue(keepAlive),
    ],
  );
  await tester.pumpAndSettle();
  await closeSplash(tester);
  return (reminder: reminder, clock: clock, keepAlive: keepAlive, saved: saved);
}

void main() {
  group('nextReminder', () {
    test('hari ini belum terhitung dan belum pukul 20: hari ini 20.00', () {
      expect(nextReminder(now: DateTime(2026, 10, 14, 9), todayCounted: false), DateTime(2026, 10, 14, 20));
    });

    test('hari ini sudah terhitung: besok 20.00', () {
      expect(nextReminder(now: DateTime(2026, 10, 14, 9), todayCounted: true), DateTime(2026, 10, 15, 20));
    });

    test('sudah lewat pukul 20: besok 20.00; akhir bulan pindah bulan', () {
      expect(nextReminder(now: DateTime(2026, 10, 31, 21), todayCounted: false), DateTime(2026, 11, 1, 20));
    });
  });

  testWidgets('aplikasi dibuka: pengingat dijadwalkan besok pukul 20.00 dengan teksnya', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(5, daysAgo(1))));
    expect(s.reminder.scheduledAt, DateTime(2026, 10, 15, 20));
    expect(s.reminder.title, 'Api streak menunggu');
    expect(s.reminder.text, 'Buka TermUL hari ini supaya streak tetap menyala.');
  });

  testWidgets('padam belum dinyalakan: hari ini 20.00; setelah dinyalakan pindah ke besok', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(23, daysAgo(2))));
    expect(s.reminder.scheduledAt, DateTime(2026, 10, 14, 20));
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Streak')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('streak-hero-flame')));
      await tester.pump();
      s.clock.now = s.clock.now.add(const Duration(milliseconds: 150));
    }
    await tester.pumpAndSettle();
    expect(s.reminder.scheduledAt, DateTime(2026, 10, 15, 20));
  });

  testWidgets('saklar Pengingat harian mati: jadwal dibatalkan dan tersimpan', (tester) async {
    final s = await open(tester, record: StreakRecord(streak: Streak(5, daysAgo(1))));
    expect(s.reminder.scheduledAt, isNotNull);
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Pengaturan')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-streak-reminder'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    // Bawa baris ke tengah supaya tidak tertutup bar navigasi.
    await tester.drag(row, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(s.saved.last.streak.reminder, isFalse);
    expect(s.reminder.scheduledAt, isNull);
  });

  testWidgets('menyalakan pengingat dengan izin ditolak: tetap mati dan pesan tampil', (tester) async {
    final s = await open(
      tester,
      record: StreakRecord(streak: Streak(5, daysAgo(1))),
      settings: const AppSettings(streak: StreakSettings(reminder: false)),
    );
    expect(s.reminder.scheduledAt, isNull);
    s.keepAlive
      ..enabled = false
      ..grantOnRequest = false;
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Pengaturan')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-streak-reminder'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    // Bawa baris ke tengah supaya tidak tertutup bar navigasi.
    await tester.drag(row, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Izin notifikasi diperlukan untuk pengingat harian'), findsOneWidget);
    expect(s.saved, isEmpty);
    expect(s.reminder.scheduledAt, isNull);
  });

  testWidgets('pengingat menyala tetapi notifikasi diblokir: peringatan dengan tombol Izinkan', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    final s = await open(tester, record: StreakRecord(streak: Streak(5, daysAgo(1))));
    s.keepAlive.enabled = false;
    await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Pengaturan')));
    await tester.pumpAndSettle();
    final blocked = find.text('Notifikasi belum diizinkan, jadi pengingat tidak akan tampil.');
    await tester.scrollUntilVisible(
      blocked,
      300,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    expect(blocked, findsOneWidget);
    s.keepAlive.grantOnRequest = true;
    await tester.tap(find.descendant(of: find.byType(Row), matching: find.text('Izinkan')).last);
    await tester.pumpAndSettle();
    expect(blocked, findsNothing);
  });
}
