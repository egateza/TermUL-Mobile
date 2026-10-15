import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:xterm/xterm.dart';
import 'package:termul_mobile/shared/widgets/termul_text_field.dart';

/// Alur sambung ujung ke ujung di perangkat: form host, Keystore, jaringan, dan server SSH sungguhan.
/// Server uji dan kredensialnya datang dari `--dart-define` (tidak ada di repo); tanpa itu tes dilewati.
///
///   flutter test integration_test/connect_flow_test.dart -d PERANGKAT \
///     --dart-define=E2E_HOST=10.0.2.2 --dart-define=E2E_PORT=2222 \
///     --dart-define=E2E_USER=... --dart-define=E2E_PASSWORD=...
///
/// Keystore sungguhan dipakai, tetapi autentikasi perangkat diganti yang selalu lolos supaya tes deterministik;
/// prompt biometrik sungguhan diuji di `vault_test.dart` (`--dart-define=PROMPT=true`).
const e2eHost = String.fromEnvironment('E2E_HOST');
const e2ePort = String.fromEnvironment('E2E_PORT', defaultValue: '22');
const e2eUser = String.fromEnvironment('E2E_USER');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD');
const e2ePause = int.fromEnvironment('E2E_PAUSE');

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

class _AlwaysAuth implements DeviceAuth {
  @override
  Future<AuthLevel> level() async => AuthLevel.biometric;

  @override
  Future<bool> authenticate(String reason) async => true;
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
    final deps = await bootstrap(directory: dir, auth: _AlwaysAuth());
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
    await waitFor(tester, find.text('Tersambung'));
    expect(deps.knownHosts.entriesFor(e2eHost, int.parse(e2ePort)), hasLength(1));
    expect(deps.hosts.snapshot.recent, isNotEmpty);

    // Terminal sungguhan: ukuran PTY di server cocok dengan layar, dan keluaran deras tidak membuat UI macet.
    await waitFor(tester, find.byType(TerminalView));
    final terminal = tester.widget<TerminalView>(find.byType(TerminalView)).terminal;
    await tester.pump(const Duration(seconds: 2));
    terminal.textInput('stty size\r');
    await tester.pump(const Duration(seconds: 2));
    final size = '${terminal.viewHeight} ${terminal.viewWidth}';
    expect(terminal.buffer.getText(), contains(size), reason: 'stty size seharusnya $size');
    terminal.textInput('yes | head -n 200000 | tail -n 1; echo SELE""SAI\r');
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (!terminal.buffer.getText().contains('SELESAI\n') && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(terminal.buffer.getText(), contains('SELESAI'));
    terminal.textInput('echo "é─😀"\r');
    await tester.pump(const Duration(seconds: 2));
    expect(terminal.buffer.getText(), contains('é─😀'));

    // Pausa opsional untuk mengambil tangkapan layar dari luar (`--dart-define=E2E_PAUSE=20`).
    if (e2ePause > 0) {
      terminal.textInput(
        'clear; ls -la --color=always /etc | head -n 14; echo; printf "\\033[31mmerah \\033[32mhijau \\033[33mkuning \\033[34mbiru \\033[35mungu \\033[36msian\\033[0m\\n"\r',
      );
      await tester.pump(const Duration(seconds: 2));
      // ignore: avoid_print
      print('E2E_PAUSE_MULAI');
      await tester.pump(Duration(seconds: e2ePause));
    }

    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    // Keyboard tidak boleh tertinggal terbuka di daftar host setelah keluar dari terminal.
    expect(MediaQuery.of(tester.element(find.byType(HostRow))).viewInsets.bottom, 0);

    // Sambung kedua: host sudah dikenal, langsung tersambung.
    await tester.tap(find.widgetWithText(HostRow, 'server-uji'));
    await waitFor(tester, find.text('Tersambung'));
    expect(find.text('Host baru'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
  });

  testWidgets('password salah: setelah host key dipercayai, galat "Login ditolak"', (tester) async {
    final deps = await bootstrap(directory: dir, auth: _AlwaysAuth());
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
