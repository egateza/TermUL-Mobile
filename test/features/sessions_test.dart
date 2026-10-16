import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/features/connect/session_manager.dart';
import 'package:termul_mobile/features/sessions/sessions_screen.dart';
import 'package:termul_mobile/features/terminal/terminal_screen.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';

import 'reconnect_test.dart' show start, terminalOf;

Future<void> pressBack(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Kembali'));
  await tester.pumpAndSettle();
}

Future<void> chooseKeep(WidgetTester tester) async {
  await pressBack(tester);
  await tester.tap(find.text('Tetap terhubung di latar belakang'));
  await tester.pumpAndSettle();
}

Future<void> openSessions(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp(r'^Sesi( aktif, \d+)?$')));
  await tester.pumpAndSettle();
  expect(find.byType(SessionsScreen), findsOneWidget);
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HostRow, skipOffstage: false).first));

void main() {
  testWidgets('keluar dari terminal: tiga pilihan dan catatan bila pengaturan latar belakang mati', (tester) async {
    await start(tester);
    await pressBack(tester);
    expect(find.text('Keluar dari terminal?'), findsOneWidget);
    expect(find.text('Tetap terhubung di latar belakang'), findsOneWidget);
    expect(find.text('Putuskan'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.textContaining('Pengaturan "Pertahankan koneksi di latar belakang" mati'), findsOneWidget);
    expect(find.text('Buka Pengaturan'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget, reason: 'Batal tetap di terminal');
  });

  testWidgets('catatan tidak muncul bila pengaturan latar belakang menyala', (tester) async {
    await start(tester, settings: const AppSettings(connection: ConnectionSettings(keepAlive: true)));
    await pressBack(tester);
    expect(find.text('Tetap terhubung di latar belakang'), findsOneWidget);
    expect(find.textContaining('mati, jadi Android'), findsNothing);
  });

  testWidgets('Tetap terhubung: layar tertutup, sesi tetap hidup, lencana 1, bisa dibuka lagi dengan riwayat utuh', (
    tester,
  ) async {
    final (_, net, _) = await start(tester);
    net.shells[0].emit('riwayat-penting\r\n'.codeUnits);
    await tester.pump(const Duration(milliseconds: 50));
    await chooseKeep(tester);
    expect(find.byType(TerminalScreen), findsNothing);
    expect(net.shells[0].closed, isFalse, reason: 'sesi dibiarkan hidup');
    expect(find.bySemanticsLabel('Sesi aktif, 1'), findsOneWidget);

    await openSessions(tester);
    expect(find.text('app-01'), findsOneWidget);
    expect(find.text('Tersambung'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^app-01, Tersambung')));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(terminalOf(tester).buffer.getText(), contains('riwayat-penting'));
    expect(net.calls, 1, reason: 'tidak menyambung baru');
    expect(containerOf(tester).read(sessionManagerProvider), isEmpty, reason: 'sedang tampil, bukan di latar belakang');

    terminalOf(tester).textInput('ls\r');
    expect(net.shells[0].sent, 'ls\r');
  });

  testWidgets('Putuskan di dialog menutup sesi dan tidak meninggalkan sesi di latar belakang', (tester) async {
    final (_, net, _) = await start(tester);
    await pressBack(tester);
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsNothing);
    expect(net.shells[0].closed, isTrue);
    expect(find.bySemanticsLabel('Sesi'), findsOneWidget);
    expect(containerOf(tester).read(sessionManagerProvider), isEmpty);
  });

  testWidgets('daftar sesi aktif kosong: penjelasan cara menambahkannya', (tester) async {
    await start(tester);
    await pressBack(tester);
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
    await openSessions(tester);
    expect(find.text('Tidak ada sesi di latar belakang'), findsOneWidget);
  });

  testWidgets('Putuskan sesi dari daftar: konfirmasi, sambungan ditutup, sesi hilang dari daftar', (tester) async {
    final (_, net, _) = await start(tester);
    await chooseKeep(tester);
    await openSessions(tester);
    await tester.tap(find.bySemanticsLabel('Putuskan app-01'));
    await tester.pumpAndSettle();
    expect(find.text('Putuskan sesi?'), findsOneWidget);
    expect(net.shells[0].closed, isFalse, reason: 'belum, menunggu konfirmasi');
    await tester.tap(find.text('Putuskan').last);
    await tester.pumpAndSettle();
    expect(net.shells[0].closed, isTrue);
    expect(find.text('Tidak ada sesi di latar belakang'), findsOneWidget);
    expect(containerOf(tester).read(sessionManagerProvider), isEmpty);
  });

  testWidgets('dua sesi ke profil yang sama: dibedakan nomor, masing-masing punya sambungan dan riwayat sendiri', (
    tester,
  ) async {
    final (h, net, profile) = await start(tester);
    net.shells[0].emit('sesi-satu\r\n'.codeUnits);
    await tester.pump(const Duration(milliseconds: 50));
    await chooseKeep(tester);

    net.succeed(profile);
    await tester.tap(find.widgetWithText(HostRow, 'app-01'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(net.calls, 2, reason: 'membuka host lagi menyambung sesi baru');
    expect(terminalOf(tester).buffer.getText(), isNot(contains('sesi-satu')));
    net.shells[1].emit('sesi-dua\r\n'.codeUnits);
    await tester.pump(const Duration(milliseconds: 50));
    await chooseKeep(tester);
    expect(find.bySemanticsLabel('Sesi aktif, 2'), findsOneWidget);

    await openSessions(tester);
    expect(find.text('app-01'), findsOneWidget);
    expect(find.text('app-01 · sesi 2'), findsOneWidget);
    expect(find.text('Putuskan semua'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^app-01, Tersambung')));
    await tester.pumpAndSettle();
    expect(terminalOf(tester).buffer.getText(), contains('sesi-satu'));
    expect(h.auth.reasons, hasLength(2));
  });

  testWidgets('Putuskan semua dari daftar menutup semua sesi di latar belakang', (tester) async {
    final (_, net, profile) = await start(tester);
    await chooseKeep(tester);
    net.succeed(profile);
    await tester.tap(find.widgetWithText(HostRow, 'app-01'));
    await tester.pumpAndSettle();
    await chooseKeep(tester);
    await openSessions(tester);
    await tester.tap(find.text('Putuskan semua'));
    await tester.pumpAndSettle();
    expect(find.text('Putuskan 2 sesi?'), findsOneWidget);
    await tester.tap(find.text('Putuskan').last);
    await tester.pumpAndSettle();
    expect(net.shells.every((s) => s.closed), isTrue);
    expect(containerOf(tester).read(sessionManagerProvider), isEmpty);
  });

  testWidgets(
    'sesi di latar belakang putus: ditandai Terputus tanpa sambung ulang otomatis; dibuka lagi menyambung ulang',
    (tester) async {
      final (_, net, profile) = await start(tester);
      await chooseKeep(tester);
      net.sockets.last.dropServer();
      await tester.pump(const Duration(milliseconds: 100));
      await openSessions(tester);
      expect(find.text('Terputus'), findsOneWidget);
      expect(net.calls, 1, reason: 'tanpa layar, tidak ada sambung ulang otomatis (bisa memunculkan prompt biometrik)');

      net.succeed(profile);
      await tester.tap(find.bySemanticsLabel(RegExp('^app-01, Terputus')));
      await tester.pumpAndSettle();
      expect(net.calls, 2, reason: 'membuka lagi menyambung ulang');
      expect(find.byType(TerminalScreen), findsOneWidget);
      expect(find.text('Tersambung'), findsOneWidget);
      expect(terminalOf(tester).buffer.getText(), contains('— tersambung ulang —'));
    },
  );

  testWidgets('"Putuskan semua" di notifikasi juga menutup sesi yang ada di latar belakang', (tester) async {
    final (_, net, _) = await start(tester);
    await chooseKeep(tester);
    expect(containerOf(tester).read(activeSessionsProvider), hasLength(1));
    containerOf(tester).read(activeSessionsProvider.notifier).disconnectAll();
    await tester.pumpAndSettle();
    expect(net.shells[0].closed, isTrue);
    expect(containerOf(tester).read(sessionManagerProvider), isEmpty);
    expect(containerOf(tester).read(activeSessionsProvider), isEmpty);
    expect(find.bySemanticsLabel('Sesi'), findsOneWidget);
  });
}
