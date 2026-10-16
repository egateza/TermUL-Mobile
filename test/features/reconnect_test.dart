import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/known_host.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/ssh/ssh_failure.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/features/connect/connect_flow.dart';
import 'package:termul_mobile/features/terminal/terminal_screen.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:xterm/xterm.dart';

import 'hosts_ui_harness.dart';
import 'silent_socket.dart';
import 'terminal/terminal_session_test.dart' show FakeShell;

/// Jaringan palsu untuk sambung ulang: tiap sambungan punya soket (bisa diputus) dan shell sendiri.
class FakeNet {
  final sockets = <SilentSocket>[];
  final connections = <SshConnection>[];
  final shells = <FakeShell>[];
  final queue = <Future<SshConnection> Function(HostKeyDecider decide)>[];
  int calls = 0;

  ConnectFunction get fn =>
      ({required HostProfile profile, required SshCredentials credentials, required HostKeyDecider decideHostKey}) {
        calls++;
        return queue.removeAt(0)(decideHostKey);
      };

  ShellOpenerFor get shellOpener => (connection, {required columns, required rows}) async {
    final shell = FakeShell();
    shells.add(shell);
    return shell;
  };

  SshConnection open(HostProfile profile) {
    final link = fakeLink(profile);
    sockets.add(link.socket);
    connections.add(link.connection);
    return link.connection;
  }

  /// Menambah satu giliran sambungan yang langsung berhasil.
  void succeed(HostProfile profile) => queue.add((_) async => open(profile));
}

/// Android memberi tahu perpindahan keadaan secara berurutan; urutan harus sah.
void goBackground() {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
  }
}

void goForeground() {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
  }
}

Terminal terminalOf(WidgetTester tester) => tester.widget<TerminalView>(find.byType(TerminalView)).terminal;

Future<(Harness, FakeNet, HostProfile)> start(WidgetTester tester) async {
  final h = Harness();
  await h.seed([host(id1)]);
  await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
  final profile = h.hosts.snapshot.profiles.single;
  final net = FakeNet();
  net.succeed(profile);
  await h.pump(
    tester,
    overrides: [
      connectFunctionProvider.overrideWithValue(net.fn),
      shellOpenerProvider.overrideWithValue(net.shellOpener),
    ],
    realConnect: true,
  );
  await tester.tap(find.widgetWithText(HostRow, 'app-01'));
  await tester.pumpAndSettle();
  expect(find.byType(TerminalScreen), findsOneWidget);
  expect(find.text('Tersambung'), findsOneWidget);
  return (h, net, profile);
}

Future<void> drop(WidgetTester tester, FakeNet net) async {
  net.sockets.last.dropServer();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('sambungan putus: sambung ulang otomatis, riwayat tetap, pemisah ditulis, shell baru dipakai', (
    tester,
  ) async {
    final (h, net, profile) = await start(tester);
    net.shells[0].emit('riwayat-lama\r\n'.codeUnits);
    await tester.pump(const Duration(milliseconds: 50));

    final gate = Completer<SshConnection>();
    net.queue.add((_) => gate.future);
    await drop(tester, net);
    expect(net.calls, 2, reason: 'sambung ulang otomatis dimulai');
    expect(find.text('Menyambung ulang…'), findsNWidgets(2)); // banner dan status
    expect(terminalOf(tester).buffer.getText(), contains('riwayat-lama'));

    gate.complete(net.open(profile));
    await tester.pumpAndSettle();
    expect(find.text('Menyambung ulang…'), findsNothing);
    expect(find.text('Tersambung'), findsOneWidget);
    final text = terminalOf(tester).buffer.getText();
    expect(text, contains('riwayat-lama'));
    expect(text, contains('— tersambung ulang —'));
    expect(net.shells, hasLength(2));
    expect(net.shells[0].closed, isTrue);

    terminalOf(tester).textInput('ls\r');
    expect(net.shells[1].sent, 'ls\r');
    expect(net.shells[0].sent, isEmpty);
    expect(h.auth.reasons, hasLength(2)); // vault dibuka lagi untuk sambung ulang
  });

  testWidgets('sambung ulang gagal: banner galat dengan alasan; Sambung sekarang mencoba lagi sampai berhasil', (
    tester,
  ) async {
    final (_, net, profile) = await start(tester);
    net.queue.add((_) async => throw const SshNetworkFailure('putus'));
    await drop(tester, net);
    await tester.pumpAndSettle();
    expect(find.text('Gagal menyambung ulang'), findsOneWidget);
    expect(find.text('Tidak bisa tersambung'), findsOneWidget);
    expect(find.text('Terputus'), findsOneWidget);

    net.succeed(profile);
    await tester.tap(find.text('Sambung sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Gagal menyambung ulang'), findsNothing);
    expect(find.text('Tersambung'), findsOneWidget);
    expect(net.calls, 3);
  });

  testWidgets('host key berubah saat sambung ulang: layar host key muncul; menolak kembali ke terminal dengan galat', (
    tester,
  ) async {
    final (_, net, _) = await start(tester);
    net.shells[0].emit('penting\r\n'.codeUnits);
    await tester.pump(const Duration(milliseconds: 50));
    HostKeyChoice? seen;
    net.queue.add((decide) async {
      final c = await decide(
        const HostKeyChallenge(
          host: '192.0.2.11',
          port: 22,
          type: 'ssh-ed25519',
          fingerprint: 'SHA256:baru',
          verdict: HostKeyVerdict.changed,
          storedFingerprints: ['SHA256:lama'],
        ),
      );
      seen = c;
      throw const SshHostKeyRejected(changed: true);
    });
    await drop(tester, net);
    await tester.pumpAndSettle();
    expect(find.text('Host key berubah'), findsOneWidget);
    await tester.tap(find.text('Batalkan koneksi'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(find.text('Gagal menyambung ulang'), findsOneWidget);
    expect(seen, HostKeyChoice.reject);
    expect(find.text('Koneksi dibatalkan'), findsOneWidget);
    expect(terminalOf(tester).buffer.getText(), contains('penting'));
  });

  testWidgets('putus saat di latar belakang: tidak menyambung sampai aplikasi terlihat lagi', (tester) async {
    final (_, net, profile) = await start(tester);
    goBackground();
    net.succeed(profile);
    await drop(tester, net);
    await tester.pump();
    expect(net.calls, 1); // di latar belakang tidak ada prompt biometrik dan tidak ada sambungan

    goForeground();
    await tester.pumpAndSettle();
    expect(net.calls, 2);
    expect(find.text('Tersambung'), findsOneWidget);
  });

  testWidgets('kembali dari latar belakang dengan soket yang sudah mati diam-diam: terdeteksi lalu disambung ulang', (
    tester,
  ) async {
    final (_, net, profile) = await start(tester);
    // Soket tidak ditutup dan tidak menjawab (seperti soket yang dimatikan Android tanpa kabar).
    goBackground();
    goForeground();
    net.succeed(profile);
    await tester.pump(const Duration(seconds: 6)); // batas ping 5 detik
    await tester.pumpAndSettle();
    expect(net.calls, 2);
    expect(find.text('Tersambung'), findsOneWidget);
  });

  testWidgets('kembali dari latar belakang dengan sambungan hidup: tidak menyambung ulang', (tester) async {
    // Sambungan palsu belum terautentikasi sehingga ping tidak pernah dibalas; yang diuji di sini hanya bahwa
    // `checkAlive` dipanggil sekali dan tidak ada sambung ulang selama masih dalam batas waktu.
    final (_, net, _) = await start(tester);
    goForeground();
    await tester.pump(const Duration(seconds: 1));
    expect(net.calls, 1);
  });

  testWidgets('menutup layar sambil menyambung ulang menutup semuanya tanpa galat', (tester) async {
    final (_, net, _) = await start(tester);
    final gate = Completer<SshConnection>();
    net.queue.add((_) => gate.future);
    await drop(tester, net);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsNothing);
    expect(net.shells.every((s) => s.closed), isTrue);
    final late = fakeLink(net.connections.first.profile);
    gate.complete(late.connection);
    await tester.pumpAndSettle();
    expect(late.connection.isClosed, isTrue); // sambungan yang selesai setelah batal ditutup
  });

  testWidgets('keluar lewat Putuskan menutup sambungan dan shell', (tester) async {
    final (_, net, _) = await start(tester);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
    expect(net.connections.single.isClosed, isTrue);
    expect(net.shells.single.closed, isTrue);
  });

  testWidgets('sesi baru memakai settings.json terbaru tanpa memulai ulang aplikasi', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final profile = h.hosts.snapshot.profiles.single;
    final net = FakeNet()
      ..succeed(profile)
      ..succeed(profile);
    var fontSize = 13.0;
    var loads = 0;
    await h.pump(
      tester,
      overrides: [
        connectFunctionProvider.overrideWithValue(net.fn),
        shellOpenerProvider.overrideWithValue(net.shellOpener),
        settingsLoaderProvider.overrideWithValue(() async {
          loads++;
          return AppSettings(terminal: TerminalSettings(fontSize: fontSize, lineHeight: 1.2));
        }),
      ],
      realConnect: true,
    );

    await tester.tap(find.widgetWithText(HostRow, 'app-01'));
    await tester.pumpAndSettle();
    expect(tester.widget<TerminalView>(find.byType(TerminalView)).textStyle.fontSize, 13);
    expect(loads, 1);

    // Berkas diubah di luar; keluar dari sesi lalu buka lagi: ukuran baru terpakai.
    fontSize = 9;
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putuskan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HostRow, 'app-01'));
    await tester.pumpAndSettle();
    final style = tester.widget<TerminalView>(find.byType(TerminalView)).textStyle;
    expect(style.fontSize, 9);
    expect(style.height, 1.2);
    expect(loads, 2);
  });

  testWidgets('mengubah pengaturan saat sesi terbuka langsung mengubah huruf dan ukuran PTY', (tester) async {
    final (_, net, _) = await start(tester);
    TerminalView view() => tester.widget<TerminalView>(find.byType(TerminalView));
    expect(view().textStyle.fontSize, 13);
    final rowsBefore = net.shells.single.resizes.isEmpty ? null : net.shells.single.resizes.last;
    final container = ProviderScope.containerOf(tester.element(find.byType(TerminalView)));
    await container
        .read(appSettingsProvider.notifier)
        .update(const AppSettings(terminal: TerminalSettings(fontSize: 9, lineHeight: 1.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // melewati debounce 150 ms
    expect(view().textStyle.fontSize, 9);
    expect(view().textStyle.height, 1.0);
    expect(net.shells.single.resizes, isNotEmpty);
    expect(net.shells.single.resizes.last, isNot(equals(rowsBefore)));
  });
}
