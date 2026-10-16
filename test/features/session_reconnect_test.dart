import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart' show activeSessionsProvider;
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/platform/screen_monitor.dart';
import 'package:termul_mobile/core/ssh/reconnect_backoff.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/ssh/ssh_failure.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';
import 'package:termul_mobile/core/vault/auth_gate.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/features/connect/connect_flow.dart';
import 'package:termul_mobile/features/connect/session_controller.dart';
import 'package:termul_mobile/features/terminal/shell_channel.dart';

import '../core/vault/fakes.dart';
import 'hosts_ui_harness.dart';
import 'silent_socket.dart';

class _FakeScreen implements ScreenMonitor {
  int count = 0;
  final events = StreamController<void>.broadcast();

  @override
  Future<int> screenOffCount() async => count;

  @override
  Stream<void> get onScreenOff => events.stream;

  /// Layar mati dan Dart sempat menerima peristiwanya.
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
  final probed = <String>[];
  var connectCalls = 0;
  var reachable = false;
  var autoReconnect = true;

  /// Percobaan sambung ke-[failOn] gagal dengan [failure] (bawaan: jaringan); lainnya berhasil.
  int? failOn;
  SshFailure failure = const SshNetworkFailure('putus');

  Future<SessionController> controller(ProviderContainer container) async {
    await vault.put(id1, SecretType.loginPassword, 'rahasia');
    await hosts.save(profile);
    return SessionController(
      id: 0,
      ordinal: 1,
      profile: profile,
      flow: ConnectFlow(
        profile: profile,
        vault: vault,
        hosts: hosts,
        unlockReason: 'buka',
        gate: gate,
        connect: ({required profile, required credentials, required decideHostKey}) async {
          connectCalls++;
          if (connectCalls == failOn) throw failure;
          final link = fakeLink(profile);
          links.add(link);
          return link.connection;
        },
      ),
      registry: container.read(activeSessionsProvider.notifier),
      shellOpener: (connection, {required columns, required rows}) => Completer<ShellChannel>().future,
      reconnectedMarker: '— tersambung ulang —',
      probe: (h, p) async {
        probed.add('$h:$p');
        return reachable;
      },
      backoff: const ReconnectBackoff([Duration(seconds: 2), Duration(seconds: 5)]),
      screenMonitor: screen,
      autoReconnect: () => autoReconnect,
    );
  }

  void dispose() {
    for (final l in links) {
      l.connection.close();
    }
  }
}

void main() {
  testWidgets('layar tetap menyala: sambung ulang tanpa prompt lagi, termasuk setelah gagal jaringan', (tester) async {
    final rig = _Rig()..failOn = 2;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await rig.controller(container);
    addTearDown(controller.dispose);

    controller.attach();
    unawaited(controller.start());
    await tester.pump();
    expect(controller.flow.state, isA<ConnectDone>());
    expect(rig.auth.reasons, hasLength(1)); // satu-satunya prompt: sambungan pertama

    // Sambungan putus; host belum terjangkau: hitungan mundur berjalan, tanpa prompt.
    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(controller.lost, isTrue);
    expect(controller.secondsUntilRetry, 2);

    await tester.pump(const Duration(seconds: 2)); // percobaan 2: masih tak terjangkau, jeda 5 detik
    await tester.pump();
    expect(rig.probed, hasLength(2));
    expect(controller.secondsUntilRetry, 5);

    // Host terjangkau: sambung gagal di jaringan, lalu berhasil. Tetap tanpa prompt kedua.
    rig.reachable = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(rig.connectCalls, 2);
    expect(controller.secondsUntilRetry, isNotNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(rig.connectCalls, 3);
    expect(rig.auth.reasons, hasLength(1), reason: 'rahasia dipegang selama layar tidak mati');
    expect(controller.lost, isFalse);
    expect(controller.secondsUntilRetry, isNull);
    rig.dispose();
  });

  testWidgets('sambung ulang otomatis mati: putus tidak menyambung sendiri, tombol Sambung sekarang tetap jalan', (
    tester,
  ) async {
    final rig = _Rig()
      ..reachable = true
      ..autoReconnect = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await rig.controller(container);
    addTearDown(controller.dispose);

    controller.attach();
    unawaited(controller.start());
    await tester.pump();
    expect(rig.connectCalls, 1);

    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(controller.lost, isTrue);
    expect(rig.probed, isEmpty, reason: 'tidak ada probe otomatis');
    expect(rig.connectCalls, 1);
    expect(controller.secondsUntilRetry, isNull);

    controller.reconnect(); // pemicu otomatis (mis. aplikasi terlihat lagi) tetap diabaikan
    await tester.pump();
    expect(rig.connectCalls, 1);

    controller.reconnect(manual: true);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(rig.connectCalls, 2);
    expect(controller.lost, isFalse);
    rig.dispose();
  });

  testWidgets('sambung ulang otomatis dimatikan saat menunggu: rangkaian berhenti', (tester) async {
    final rig = _Rig(); // host belum terjangkau
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await rig.controller(container);
    addTearDown(controller.dispose);

    controller.attach();
    unawaited(controller.start());
    await tester.pump();
    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(controller.secondsUntilRetry, 2);

    rig.autoReconnect = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(controller.secondsUntilRetry, isNull);
    expect(rig.probed, hasLength(1), reason: 'hanya probe pertama sebelum dimatikan');
    await tester.pump(const Duration(seconds: 30));
    expect(rig.probed, hasLength(1));
    rig.dispose();
  });

  testWidgets('layar mati: rahasia dilepas, sambung ulang berikutnya minta biometrik lagi', (tester) async {
    final rig = _Rig()..reachable = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await rig.controller(container);
    addTearDown(controller.dispose);

    controller.attach();
    unawaited(controller.start());
    await tester.pump();
    expect(controller.flow.holdsCredentials, isTrue);

    rig.screen.off();
    await tester.pump();
    expect(controller.flow.holdsCredentials, isFalse);

    rig.links.last.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(rig.auth.reasons, hasLength(2));
    expect(controller.lost, isFalse);
    expect(controller.flow.holdsCredentials, isTrue);
    rig.dispose();
  });

  testWidgets('layar mati saat Dart dibekukan (peristiwa tidak sampai): penghitung tetap membuang rahasia', (
    tester,
  ) async {
    final rig = _Rig()..reachable = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await rig.controller(container);
    addTearDown(controller.dispose);

    controller.attach();
    unawaited(controller.start());
    await tester.pump();

    rig.screen.count++; // hanya penghitung Kotlin yang naik
    rig.links.last.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(rig.auth.reasons, hasLength(2));
    rig.dispose();
  });

  testWidgets('login ditolak saat sambung ulang: rahasia dilepas dan tidak diulang otomatis', (tester) async {
    final rig = _Rig()
      ..reachable = true
      ..failOn = 2
      ..failure = const SshAuthFailure();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await rig.controller(container);
    addTearDown(controller.dispose);

    controller.attach();
    unawaited(controller.start());
    await tester.pump();
    expect(controller.flow.holdsCredentials, isTrue);

    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(controller.flow.state, isA<ConnectFailed>());
    expect(controller.flow.holdsCredentials, isFalse);
    expect(controller.secondsUntilRetry, isNull);
    await tester.pump(const Duration(minutes: 1));
    expect(rig.connectCalls, 2, reason: 'tanpa percobaan otomatis berikutnya');
    rig.dispose();
  });

  testWidgets('prompt dibatalkan saat sambung ulang: pemicu otomatis tidak mengulang, tombol menampilkannya lagi', (
    tester,
  ) async {
    final rig = _Rig()..reachable = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await rig.controller(container);
    addTearDown(controller.dispose);

    controller.attach();
    unawaited(controller.start());
    await tester.pump();
    expect(rig.auth.reasons, hasLength(1));

    rig.screen.off(); // layar mati: rahasia dilepas, sambung ulang butuh prompt
    await tester.pump();
    rig.auth.result = false; // pengguna mengetuk di luar prompt
    rig.links.single.socket.dropServer();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(rig.auth.reasons, hasLength(2));
    expect(controller.flow.state, isA<ConnectAuthDenied>());
    expect(controller.needsAuth, isTrue);

    // Aplikasi terlihat lagi, sambungan putus lagi, dan seterusnya: tidak ada prompt baru.
    controller.reconnect();
    controller.reconnect();
    await tester.pump(const Duration(minutes: 1));
    expect(rig.auth.reasons, hasLength(2));
    expect(controller.needsAuth, isTrue);

    // Pengguna menekan "Tampilkan prompt".
    rig.auth.result = true;
    controller.reconnect(manual: true);
    await tester.pump();
    await tester.pump();
    expect(rig.auth.reasons, hasLength(3));
    expect(controller.needsAuth, isFalse);
    expect(controller.lost, isFalse);
    rig.dispose();
  });

  testWidgets('dua sesi: prompt dibatalkan di satu sesi, sesi lain tidak memunculkan prompt sendiri', (tester) async {
    final rig = _Rig()..reachable = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final a = await rig.controller(container);
    addTearDown(a.dispose);
    final b = await rig.controller(container);
    addTearDown(b.dispose);

    for (final c in [a, b]) {
      c.attach();
      unawaited(c.start());
      await tester.pump();
    }
    expect(rig.auth.reasons, hasLength(2));

    rig.screen.off();
    await tester.pump();
    rig.auth.result = false;
    for (final link in List.of(rig.links)) {
      link.socket.dropServer();
    }
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    await tester.pump();
    expect(rig.auth.reasons, hasLength(3), reason: 'hanya satu prompt tambahan; sesi kedua mengikuti pembatalan');
    expect(a.needsAuth, isTrue);
    expect(b.needsAuth, isTrue);
    rig.dispose();
  });
}
