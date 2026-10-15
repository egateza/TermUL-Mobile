import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:termul_mobile/shared/widgets/termul_text_field.dart';

/// Alur sambung ujung ke ujung di perangkat: form host, Keystore, jaringan, dan server SSH sungguhan.
/// Server uji dan kredensialnya datang dari `--dart-define` (tidak ada di repo); tanpa itu tes dilewati.
///
///   flutter test integration_test/connect_flow_test.dart -d PERANGKAT \
///     --dart-define=E2E_HOST=10.0.2.2 --dart-define=E2E_PORT=2222 \
///     --dart-define=E2E_USER=... --dart-define=E2E_PASSWORD=...
///
/// Saat membaca password, Keystore meminta autentikasi perangkat. Di emulator dengan sidik jari terdaftar,
/// jawab dengan `adb emu finger touch 1` (ulangi bila perlu).
const e2eHost = String.fromEnvironment('E2E_HOST');
const e2ePort = String.fromEnvironment('E2E_PORT', defaultValue: '22');
const e2eUser = String.fromEnvironment('E2E_USER');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD');

Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is TermulTextField && w.label == label),
  matching: find.byType(TextField),
);

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 40)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().join(' | ');
  fail('tidak muncul dalam ${timeout.inSeconds} detik: $finder; layar: $texts');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (e2eHost.isEmpty || e2ePassword.isEmpty) {
    test('sambung sungguhan', () {}, skip: 'E2E_HOST dan E2E_PASSWORD tidak diisi');
    return;
  }

  late Directory dir;

  setUp(() async {
    final base = await getApplicationSupportDirectory();
    dir = await Directory('${base.path}${Platform.pathSeparator}sambung_${DateTime.now().microsecondsSinceEpoch}')
        .create(recursive: true);
  });

  tearDown(() async => dir.delete(recursive: true));

  testWidgets('tambah host, sambung, percayai host key, lalu sambung lagi tanpa pertanyaan', (tester) async {
    final deps = await bootstrap(directory: dir);
    await tester.pumpWidget(ProviderScope(overrides: deps.overrides, child: const TermulApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah host'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Nama'), 'server-uji');
    await tester.enterText(input('Host'), e2eHost);
    await tester.enterText(input('Port'), e2ePort);
    await tester.enterText(input('User'), e2eUser);
    await tester.enterText(input('Password'), e2ePassword);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await waitFor(tester, find.widgetWithText(HostRow, 'server-uji'));
    await tester.pumpAndSettle();

    // Sambung pertama: host baru, sidik jari tampil dan disimpan permanen setelah dipercayai.
    await tester.tap(find.widgetWithText(HostRow, 'server-uji'));
    await waitFor(tester, find.text('Host baru'));
    expect(find.textContaining('SHA256:'), findsOneWidget);
    await tester.tap(find.text('Percayai dan sambung'));
    await waitFor(tester, find.text('Tersambung ke server-uji'));
    expect(deps.knownHosts.entriesFor(e2eHost, int.parse(e2ePort)), hasLength(1));
    expect(deps.hosts.snapshot.recent, isNotEmpty);

    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();

    // Sambung kedua: host sudah dikenal, langsung tersambung.
    await tester.tap(find.widgetWithText(HostRow, 'server-uji'));
    await waitFor(tester, find.text('Tersambung ke server-uji'));
    expect(find.text('Host baru'), findsNothing);
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
  });

  testWidgets('password salah: setelah host key dipercayai, galat "Login ditolak"', (tester) async {
    final deps = await bootstrap(directory: dir);
    await tester.pumpWidget(ProviderScope(overrides: deps.overrides, child: const TermulApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah host'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Nama'), 'salah');
    await tester.enterText(input('Host'), e2eHost);
    await tester.enterText(input('Port'), e2ePort);
    await tester.enterText(input('User'), e2eUser);
    await tester.enterText(input('Password'), 'bukan-password-yang-benar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await waitFor(tester, find.widgetWithText(HostRow, 'salah'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(HostRow, 'salah'));
    await waitFor(tester, find.text('Host baru'));
    await tester.tap(find.text('Percayai dan sambung'));
    await waitFor(tester, find.text('Login ditolak'));
  });
}
