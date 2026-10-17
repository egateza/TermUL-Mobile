import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart' show activeSessionsProvider;
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/platform/screen_monitor.dart';
import 'package:termul_mobile/core/ssh/reconnect_backoff.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';
import 'package:termul_mobile/core/vault/auth_gate.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/features/connect/connect_flow.dart';
import 'package:termul_mobile/features/connect/session_controller.dart';
import 'package:termul_mobile/features/sftp/sftp_link.dart';
import 'package:termul_mobile/features/sftp/sftp_screen.dart';
import 'package:termul_mobile/l10n/app_localizations.dart';
import 'package:termul_mobile/features/terminal/shell_channel.dart';

import '../../core/vault/fakes.dart';
import '../hosts_ui_harness.dart';
import '../silent_socket.dart';
import 'sftp_browser_test.dart' show FakeBrowsing, dir;

class _FakeScreen implements ScreenMonitor {
  int count = 0;
  final events = StreamController<void>.broadcast();

  @override
  Future<int> screenOffCount() async => count;

  @override
  Stream<void> get onScreenOff => events.stream;

  void off() {
    count++;
    events.add(null);
  }
}

class _Rig {
  _Rig() {
    auth = FakeDeviceAuth(currentLevel: AuthLevel.biometric);
    vault = KeystoreCredentialVault(auth: auth, store: MemorySecretStore(), index: MemoryVaultIndex());
    profile = host(id1, auth: AuthMethod.password);
    hosts = JsonHostRepository(File('tidak-dipakai.json'), writer: noWrite);
  }

  late final FakeDeviceAuth auth;
  late final KeystoreCredentialVault vault;
  late final HostProfile profile;
  late final JsonHostRepository hosts;
  final screen = _FakeScreen();
  final gate = AuthGate();
  final links = <({SshConnection connection, SilentSocket socket})>[];
  final opened = <FakeBrowsing>[];
  final probed = <String>[];
  var connectCalls = 0;
  var reachable = false;
  var autoReconnect = true;

  Future<SshConnection> _connect() async {
    connectCalls++;
    final link = fakeLink(profile);
    links.add(link);
    return link.connection;
  }

  ConnectFlow flow() => ConnectFlow(
    profile: profile,
    vault: vault,
    hosts: hosts,
    unlockReason: 'buka',
    gate: gate,
    connect: ({required profile, required credentials, required decideHostKey}) => _connect(),
  );

  Future<FakeBrowsing> _opener(SshConnection c) async {
    final f = FakeBrowsing({
      '/home/u': [dir('/home/u', 'proyek')],
      '/': [dir('/', 'home'), dir('/', 'etc')],
    });
    opened.add(f);
    return f;
  }

  Future<SftpLink> own() async {
    await vault.put(id1, SecretType.loginPassword, 'rahasia');
    await hosts.save(profile);
    return SftpLink.own(
      profile: profile,
      flow: flow(),
      probe: (h, p) async {
        probed.add('$h:$p');
        return reachable;
      },
      backoff: const ReconnectBackoff([Duration(seconds: 2), Duration(seconds: 5)]),
      screenMonitor: screen,
      autoReconnect: () => autoReconnect,
      opener: _opener,
    );
  }

  Future<SessionController> session(ProviderContainer container) async {
    await vault.put(id1, SecretType.loginPassword, 'rahasia');
    await hosts.save(profile);
    return SessionController(
      id: 0,
      ordinal: 1,
      profile: profile,
      flow: flow(),
      registry: container.read(activeSessionsProvider.notifier),
      shellOpener: (connection, {required columns, required rows}) => Completer<ShellChannel>().future,
      reconnectedMarker: '— tersambung ulang —',
      probe: (h, p) async => reachable,
      backoff: const ReconnectBackoff([Duration(seconds: 2)]),
      screenMonitor: screen,
    );
  }

  void dispose() {
    for (final l in links) {
      l.connection.close();
    }
  }
}

void main() {
  testWidgets('koneksi sendiri: putus lalu sambung ulang otomatis tanpa prompt, layanan SFTP diganti', (tester) async {
    final rig = _Rig();
    final link = await rig.own();
    addTearDown(link.dispose);

    unawaited(link.start());
    await tester.pump();
    await tester.pump();
    expect(link.service, isNotNull);
    expect(rig.opened, hasLength(1));
    expect(rig.auth.reasons, hasLength(1)); // satu-satunya prompt: sambungan pertama
    final first = link.service;

    // Putus; host belum terjangkau: hitungan mundur berjalan, daftar lama tetap ada, tanpa prompt.
    final t = link.transfers.start(name: 'a.bin', upload: true, total: 10);
    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(link.lost, isTrue);
    expect(link.service, same(first));
    expect(link.secondsUntilRetry, 2);
    expect(t.cancel.isCancelled, isTrue, reason: 'transfer dibatalkan saat sambungan putus');

    await tester.pump(const Duration(seconds: 2)); // masih tak terjangkau, jeda 5 detik
    await tester.pump();
    expect(rig.probed, hasLength(2));
    expect(link.secondsUntilRetry, 5);

    // Host terjangkau: tersambung lagi tanpa prompt kedua.
    rig.reachable = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump();
    expect(rig.connectCalls, 2);
    expect(rig.auth.reasons, hasLength(1), reason: 'rahasia dipegang selama layar tidak mati');
    expect(link.lost, isFalse);
    expect(link.secondsUntilRetry, isNull);
    expect(link.service, isNot(same(first)));
    expect(rig.opened, hasLength(2));
    rig.dispose();
  });

  testWidgets('sambung ulang otomatis mati: tidak menyambung sendiri, tombol Sambung sekarang tetap jalan', (
    tester,
  ) async {
    final rig = _Rig()
      ..reachable = true
      ..autoReconnect = false;
    final link = await rig.own();
    addTearDown(link.dispose);
    unawaited(link.start());
    await tester.pump();
    await tester.pump();
    expect(rig.connectCalls, 1);

    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(link.lost, isTrue);
    expect(rig.probed, isEmpty);
    expect(rig.connectCalls, 1);

    link.reconnect(); // pemicu otomatis diabaikan
    await tester.pump();
    expect(rig.connectCalls, 1);

    unawaited(link.retry()); // tombol
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(rig.connectCalls, 2);
    expect(link.lost, isFalse);
    rig.dispose();
  });

  testWidgets('layar mati sejak rahasia dibaca: sambung ulang membaca vault lagi (prompt kedua)', (tester) async {
    final rig = _Rig()..reachable = true;
    final link = await rig.own();
    addTearDown(link.dispose);
    unawaited(link.start());
    await tester.pump();
    await tester.pump();
    expect(rig.auth.reasons, hasLength(1));

    rig.screen.off();
    await tester.pump();
    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(rig.connectCalls, 2);
    expect(rig.auth.reasons, hasLength(2), reason: 'layar pernah mati: rahasia dilepas');
    rig.dispose();
  });

  testWidgets('menutup layar menutup koneksi sendiri dan membatalkan transfer', (tester) async {
    final rig = _Rig();
    final link = await rig.own();
    unawaited(link.start());
    await tester.pump();
    await tester.pump();
    final t = link.transfers.start(name: 'b.bin', upload: false);
    link.dispose();
    expect(t.cancel.isCancelled, isTrue);
    expect(rig.links.single.connection.isClosed, isTrue);
    rig.dispose();
  });

  testWidgets('sesi dipinjam: mengikuti sambung ulang sesi terminalnya, kanal SFTP dibuka lagi', (tester) async {
    final rig = _Rig();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = await rig.session(container);
    addTearDown(session.dispose);
    session.attach();
    unawaited(session.start());
    await tester.pump();
    expect(session.connection, isNotNull);

    final link = SftpLink.borrowed(session: session, opener: rig._opener);
    addTearDown(link.dispose);
    unawaited(link.start());
    await tester.pump();
    await tester.pump();
    expect(link.service, isNotNull);
    expect(rig.opened, hasLength(1));
    final first = link.service;

    // Sesi putus: SFTP ikut ditandai putus; sesinya yang menyambung ulang.
    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(link.lost, isTrue);
    expect(link.isOwn, isFalse);

    rig.reachable = true;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(session.lost, isFalse);
    expect(link.lost, isFalse);
    expect(link.service, isNot(same(first)));
    expect(rig.opened, hasLength(2));
    rig.dispose();
  });

  testWidgets(
    'layar: putus menampilkan banner menunggu server dengan hitungan mundur; setelah tersambung, folder yang dibuka dipulihkan',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final rig = _Rig();
      final link = await rig.own();
      await tester.pumpWidget(
        MaterialApp(
          theme: termulTheme(),
          locale: const Locale('id'),
          supportedLocales: const [Locale('id')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: Text('akar')),
        ),
      );
      unawaited(link.start());
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push<void>(MaterialPageRoute(builder: (_) => SftpBrowserScreen(link: link)));
      await tester.pumpAndSettle();
      expect(find.text('proyek'), findsOneWidget);

      // Pindah ke folder "/" lalu putus.
      await tester.tap(find.bySemanticsLabel('/'));
      await tester.pumpAndSettle();
      expect(find.text('etc'), findsOneWidget);

      rig.links.single.socket.dropServer();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(find.text('app-01 · terputus'), findsOneWidget);
      expect(find.text('Menunggu server terjangkau…'), findsOneWidget);
      expect(find.text('Mencoba lagi dalam 2 detik.'), findsOneWidget);
      expect(find.text('Sambung sekarang'), findsOneWidget);
      expect(find.text('etc'), findsOneWidget, reason: 'daftar lama tetap terlihat');

      rig.reachable = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Menunggu server terjangkau…'), findsNothing);
      expect(find.text('app-01 · terhubung'), findsOneWidget);
      expect(find.text('etc'), findsOneWidget, reason: 'kembali ke folder yang sama');
      expect(rig.opened.last.listed, contains('/'));

      // Tutup layar agar tidak ada timer tersisa.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      rig.dispose();
    },
  );
}
