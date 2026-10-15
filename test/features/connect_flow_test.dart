import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/known_host.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/ssh/ssh_failure.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/core/vault/vault_exceptions.dart';
import 'package:termul_mobile/features/connect/connect_flow.dart';

import '../core/vault/fakes.dart';
import 'hosts_ui_harness.dart';
import 'silent_socket.dart';

SshConnection _fakeConnection(HostProfile p) => fakeConnection(p);

class _Rig {
  _Rig({AuthMethod method = AuthMethod.password, AuthLevel level = AuthLevel.biometric}) {
    auth = FakeDeviceAuth(currentLevel: level);
    store = MemorySecretStore();
    vault = KeystoreCredentialVault(auth: auth, store: store, index: MemoryVaultIndex());
    hosts = JsonHostRepository(File('tidak-dipakai.json'), writer: noWrite);
    profile = host(id1, auth: method);
  }

  late final FakeDeviceAuth auth;
  late final MemorySecretStore store;
  late final KeystoreCredentialVault vault;
  late final JsonHostRepository hosts;
  late final HostProfile profile;

  final calls = <SshCredentials>[];
  Future<SshConnection> Function(HostKeyDecider decide)? behavior;

  ConnectFlow flow() => ConnectFlow(
    profile: profile,
    vault: vault,
    hosts: hosts,
    unlockReason: 'buka',
    connect: ({required profile, required credentials, required decideHostKey}) {
      calls.add(credentials);
      return behavior!(decideHostKey);
    },
  );
}

HostKeyChallenge _challenge(HostKeyVerdict v) => HostKeyChallenge(
  host: '192.0.2.11',
  port: 22,
  type: 'ssh-ed25519',
  fingerprint: 'SHA256:abc',
  verdict: v,
  storedFingerprints: v == HostKeyVerdict.changed ? const ['SHA256:lama'] : const [],
);

void main() {
  late _Rig rig;

  setUp(() async {
    rig = _Rig();
    await rig.hosts.save(rig.profile);
  });

  test('password tersimpan dibuka dengan satu prompt, lalu tersambung dan markUsed dicatat', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final conn = _fakeConnection(rig.profile);
    rig.behavior = (_) async => conn;
    final flow = rig.flow();
    final seen = <Type>[];
    flow.addListener(() => seen.add(flow.state.runtimeType));
    await flow.start();
    expect(flow.state, isA<ConnectDone>());
    expect((flow.state as ConnectDone).connection, same(conn));
    expect(seen, containsAllInOrder([ConnectConnecting, ConnectDone]));
    expect((rig.calls.single as PasswordCredentials).password, 'rahasia');
    expect(rig.auth.reasons, ['buka']);
    expect(rig.hosts.snapshot.recent, contains(id1));
    conn.close();
    flow.dispose();
  });

  test('tanpa rahasia di vault: minta rahasia, tidak menyambung', () async {
    rig.behavior = (_) async => throw StateError('tidak boleh dipanggil');
    final flow = rig.flow();
    await flow.start();
    final s = flow.state as ConnectNeedsSecret;
    expect(s.method, AuthMethod.password);
    expect(s.wrongPassphrase, isFalse);
    expect(rig.calls, isEmpty);
    flow.dispose();
  });

  test('Keystore tidak terbaca: diperlakukan sebagai rahasia hilang', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    rig.store.failReads = true;
    final flow = rig.flow();
    await flow.start();
    expect(flow.state, isA<ConnectNeedsSecret>());
    flow.dispose();
  });

  test('autentikasi perangkat dibatalkan: ConnectAuthDenied(cancelled) dan tidak menyambung', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    rig.auth.result = false;
    final flow = rig.flow();
    await flow.start();
    expect(flow.state, isA<ConnectAuthDenied>());
    expect((flow.state as ConnectAuthDenied).cancelled, isTrue);
    expect(rig.calls, isEmpty);
    flow.dispose();
  });

  test('autentikasi perangkat tidak tersedia: ConnectAuthDenied bukan cancelled', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    rig.auth.throwOnAuthenticate = const VaultAuthException('tidak ada', cancelled: false);
    final flow = rig.flow();
    await flow.start();
    expect((flow.state as ConnectAuthDenied).cancelled, isFalse);
    flow.dispose();
  });

  test('host baru: berhenti di ConnectNeedsHostKey, jawaban diteruskan ke konektor', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final conn = _fakeConnection(rig.profile);
    HostKeyChoice? choice;
    rig.behavior = (decide) async {
      choice = await decide(_challenge(HostKeyVerdict.newHost));
      return conn;
    };
    final flow = rig.flow();
    final started = flow.start();
    await pumpEventQueue();
    expect(flow.state, isA<ConnectNeedsHostKey>());
    expect((flow.state as ConnectNeedsHostKey).challenge.fingerprint, 'SHA256:abc');
    flow.answerHostKey(HostKeyChoice.trustAndSave);
    expect(flow.state, isA<ConnectConnecting>());
    await started;
    expect(choice, HostKeyChoice.trustAndSave);
    expect(flow.state, isA<ConnectDone>());
    conn.close();
    flow.dispose();
  });

  test('menolak host key: keadaan gagal dengan SshHostKeyRejected', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    rig.behavior = (decide) async {
      final c = await decide(_challenge(HostKeyVerdict.changed));
      expect(c, HostKeyChoice.reject);
      throw const SshHostKeyRejected(changed: true);
    };
    final flow = rig.flow();
    final started = flow.start();
    await pumpEventQueue();
    flow.answerHostKey(HostKeyChoice.reject);
    await started;
    final f = (flow.state as ConnectFailed).failure;
    expect(f, isA<SshHostKeyRejected>());
    expect((f as SshHostKeyRejected).changed, isTrue);
    flow.dispose();
  });

  test('jawaban host key ganda atau tanpa pertanyaan diabaikan', () async {
    final flow = rig.flow();
    flow.answerHostKey(HostKeyChoice.trustAndSave);
    expect(flow.state, isA<ConnectPreparing>());
    flow.dispose();
  });

  test('setiap SshFailure menjadi ConnectFailed; galat lain menjadi SshUnknownFailure', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    for (final e in <Object>[
      const SshNetworkFailure('n'),
      const SshHandshakeFailure('h'),
      const SshAuthFailure(),
      const SshHostKeyStoreFailure(),
    ]) {
      rig.behavior = (_) async => throw e;
      final flow = rig.flow();
      await flow.start();
      expect((flow.state as ConnectFailed).failure, same(e));
      flow.dispose();
    }
    rig.behavior = (_) async => throw StateError('aneh');
    final flow = rig.flow();
    await flow.start();
    expect((flow.state as ConnectFailed).failure, isA<SshUnknownFailure>());
    flow.dispose();
  });

  test('kunci tak bisa dipakai: minta rahasia lagi, dengan penanda passphrase salah', () async {
    final r = _Rig(method: AuthMethod.key);
    await r.hosts.save(r.profile);
    await r.vault.put(id1, SecretType.privateKeyPem, 'PEM');
    r.behavior = (_) async => throw const SshKeyUnusable(wrongPassphrase: true);
    final flow = r.flow();
    await flow.start();
    final s = flow.state as ConnectNeedsSecret;
    expect(s.method, AuthMethod.key);
    expect(s.wrongPassphrase, isTrue);
    expect(r.calls.single, isA<KeyCredentials>());
    flow.dispose();
  });

  test('submitSecret menyimpan password ke vault lalu mengulang sambungan', () async {
    final conn = _fakeConnection(rig.profile);
    rig.behavior = (_) async => conn;
    final flow = rig.flow();
    await flow.start();
    expect(flow.state, isA<ConnectNeedsSecret>());
    await flow.submitSecret(password: 'baru');
    expect(flow.state, isA<ConnectDone>());
    expect((rig.calls.single as PasswordCredentials).password, 'baru');
    conn.close();
    flow.dispose();
  });

  test('submitSecret dengan password kosong tidak melakukan apa pun', () async {
    final flow = rig.flow();
    await flow.start();
    await flow.submitSecret(password: '');
    expect(flow.state, isA<ConnectNeedsSecret>());
    flow.dispose();
  });

  test('submitSecret kunci: PEM dan passphrase masuk vault; tanpa passphrase menghapus yang lama', () async {
    final r = _Rig(method: AuthMethod.key);
    await r.hosts.save(r.profile);
    await r.vault.put(id1, SecretType.keyPassphrase, 'lama');
    final conn = _fakeConnection(r.profile);
    r.behavior = (_) async => conn;
    final flow = r.flow();
    await flow.submitSecret(privateKeyPem: 'PEM-BARU');
    expect(flow.state, isA<ConnectDone>());
    final creds = r.calls.single as KeyCredentials;
    expect(creds.pem, 'PEM-BARU');
    expect(creds.passphrase, isNull);
    expect(await r.vault.has(id1, SecretType.keyPassphrase), isFalse);
    conn.close();
    flow.dispose();
  });

  test('submitSecret gagal menulis vault: ConnectFailed', () async {
    rig.store.failWrites = true;
    final flow = rig.flow();
    await flow.submitSecret(password: 'x');
    expect(flow.state, isA<ConnectFailed>());
    flow.dispose();
  });

  test('batal saat menunggu host key menolak keputusan; sambungan yang selesai sesudahnya ditutup', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final conn = _fakeConnection(rig.profile);
    final gate = Completer<void>();
    HostKeyChoice? choice;
    rig.behavior = (decide) async {
      choice = await decide(_challenge(HostKeyVerdict.newHost));
      await gate.future;
      return conn;
    };
    final flow = rig.flow();
    final started = flow.start();
    await pumpEventQueue();
    flow.cancel();
    gate.complete();
    await started;
    expect(choice, HostKeyChoice.reject);
    expect(flow.state, isNot(isA<ConnectDone>()));
    expect(conn.isClosed, isTrue);
    flow.dispose();
  });

  test('galat setelah batal tidak mengubah keadaan', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final gate = Completer<void>();
    rig.behavior = (_) async {
      await gate.future;
      throw const SshNetworkFailure('putus');
    };
    final flow = rig.flow();
    final started = flow.start();
    await pumpEventQueue();
    flow.cancel();
    gate.complete();
    await started;
    expect(flow.state, isA<ConnectConnecting>());
    flow.dispose();
  });

  test('profil agen tidak disambung', () async {
    final r = _Rig(method: AuthMethod.agent);
    r.behavior = (_) async => throw StateError('tidak boleh dipanggil');
    final flow = r.flow();
    await flow.start();
    expect(flow.state, isA<ConnectFailed>());
    expect(r.calls, isEmpty);
    flow.dispose();
  });

  test('start dari keadaan gagal mengulang dari awal', () async {
    await rig.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final conn = _fakeConnection(rig.profile);
    var n = 0;
    rig.behavior = (_) async {
      if (n++ == 0) throw const SshNetworkFailure('putus');
      return conn;
    };
    final flow = rig.flow();
    await flow.start();
    expect(flow.state, isA<ConnectFailed>());
    await flow.start();
    expect(flow.state, isA<ConnectDone>());
    conn.close();
    flow.dispose();
  });
}
