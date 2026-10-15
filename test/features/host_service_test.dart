import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/known_host.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';
import 'package:termul_mobile/core/storage/json/json_known_hosts_repository.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/core/vault/vault_exceptions.dart';
import 'package:termul_mobile/features/hosts/host_service.dart';

import '../core/vault/fakes.dart';

const id1 = '11111111-1111-4111-8111-111111111111';
const id2 = '22222222-2222-4222-8222-222222222222';
const fp = 'SHA256:c2FtcGxlLWZpbmdlcnByaW50LW5vdC1yZWFs';

HostProfile profile({
  String id = id1,
  String host = 'h1.contoh',
  int port = 22,
  AuthMethod auth = AuthMethod.password,
}) => HostProfile(id: id, name: 'app', host: host, port: port, username: 'u', authMethod: auth);

void main() {
  late Directory dir;
  late JsonHostRepository hosts;
  late JsonKnownHostsRepository known;
  late MemorySecretStore store;
  late MemoryVaultIndex index;
  late FakeDeviceAuth auth;
  late KeystoreCredentialVault vault;
  late HostService service;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_service_');
    hosts = JsonHostRepository(File('${dir.path}${Platform.pathSeparator}profiles.json'));
    known = JsonKnownHostsRepository(File('${dir.path}${Platform.pathSeparator}known_hosts.json'));
    store = MemorySecretStore();
    index = MemoryVaultIndex();
    auth = FakeDeviceAuth();
    vault = KeystoreCredentialVault(auth: auth, store: store, index: index);
    service = HostService(hosts: hosts, knownHosts: known, vault: vault);
    await hosts.load();
    await known.load();
  });
  tearDown(() async => dir.delete(recursive: true));

  Future<String?> secret(String id, SecretType t) => vault.get(id, t, reason: 'uji');

  group('saveHost', () {
    test('host baru dengan password: baris dan rahasia tersimpan; rahasia tidak ada di profiles.json', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw-uji'));
      expect(hosts.snapshot.profiles, hasLength(1));
      expect(await secret(id1, SecretType.loginPassword), 'pw-uji');
      final onDisk = await File('${dir.path}${Platform.pathSeparator}profiles.json').readAsString();
      expect(onDisk, isNot(contains('pw-uji')));
    });

    test('kunci dengan passphrase: kunci dan passphrase tersimpan; password lama dibuang', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw-lama'));
      await service.saveHost(
        profile(auth: AuthMethod.key),
        secrets: const HostSecretsInput(privateKeyPem: 'PEM-uji', passphrase: 'frasa'),
      );
      expect(await secret(id1, SecretType.privateKeyPem), 'PEM-uji');
      expect(await secret(id1, SecretType.keyPassphrase), 'frasa');
      expect(await vault.has(id1, SecretType.loginPassword), isFalse);
    });

    test('ganti ke password: kunci dan passphrase dibuang', () async {
      await service.saveHost(
        profile(auth: AuthMethod.key),
        secrets: const HostSecretsInput(privateKeyPem: 'PEM', passphrase: 'frasa'),
      );
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      expect(await vault.has(id1, SecretType.privateKeyPem), isFalse);
      expect(await vault.has(id1, SecretType.keyPassphrase), isFalse);
      expect(await vault.has(id1, SecretType.loginPassword), isTrue);
    });

    test('kunci baru tanpa passphrase membuang passphrase lama', () async {
      await service.saveHost(
        profile(auth: AuthMethod.key),
        secrets: const HostSecretsInput(privateKeyPem: 'PEM1', passphrase: 'frasa'),
      );
      await service.saveHost(
        profile(auth: AuthMethod.key),
        secrets: const HostSecretsInput(privateKeyPem: 'PEM2'),
      );
      expect(await secret(id1, SecretType.privateKeyPem), 'PEM2');
      expect(await vault.has(id1, SecretType.keyPassphrase), isFalse);
    });

    test('ubah tanpa mengisi rahasia: rahasia lama tetap', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      await service.saveHost(profile(host: 'baru.contoh'));
      expect(await secret(id1, SecretType.loginPassword), 'pw');
      expect(hosts.snapshot.find(id1)!.host, 'baru.contoh');
    });

    test('baris host gagal ditulis pada host baru: rahasia yang baru ditulis dibuang kembali', () async {
      final failing = JsonHostRepository(
        File('${dir.path}${Platform.pathSeparator}x.json'),
        writer: (f, b) async => throw const VaultStorageException('disk penuh'),
      );
      final svc = HostService(hosts: failing, knownHosts: known, vault: vault);
      await expectLater(
        svc.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw')),
        throwsA(isA<VaultStorageException>()),
      );
      expect(await vault.has(id1, SecretType.loginPassword), isFalse);
      expect(failing.snapshot.profiles, isEmpty);
    });

    test('rahasia gagal ditulis: baris host tidak dibuat', () async {
      store.failWrites = true;
      await expectLater(
        service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw')),
        throwsA(isA<VaultStorageException>()),
      );
      expect(hosts.snapshot.profiles, isEmpty);
    });

    test('alamat berubah: sidik jari alamat lama dibuang bila tidak ada profil lain yang memakainya', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      await known.add(KnownHost(host: 'h1.contoh', port: 22, type: 'ssh-ed25519', fingerprint: fp));
      await service.saveHost(profile(host: 'h2.contoh'));
      expect(known.entriesFor('h1.contoh', 22), isEmpty);
    });

    test('alamat berubah tetapi profil lain masih memakai alamat lama: sidik jari dipertahankan', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      await service.saveHost(
        profile(id: id2),
        secrets: const HostSecretsInput(password: 'pw2'),
      );
      await known.add(KnownHost(host: 'h1.contoh', port: 22, type: 'ssh-ed25519', fingerprint: fp));
      await service.saveHost(profile(host: 'h2.contoh'));
      expect(known.entriesFor('h1.contoh', 22), hasLength(1));
    });
  });

  group('deleteHost', () {
    test('menghapus rahasia, baris, dan sidik jari (bila tidak dipakai profil lain)', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      await known.add(KnownHost(host: 'h1.contoh', port: 22, type: 'ssh-ed25519', fingerprint: fp));
      await service.deleteHost(id1);
      expect(hosts.snapshot.profiles, isEmpty);
      expect(await vault.has(id1, SecretType.loginPassword), isFalse);
      expect(known.all, isEmpty);
    });

    test('sidik jari tetap bila profil lain memakai host:port yang sama', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      await service.saveHost(
        profile(id: id2),
        secrets: const HostSecretsInput(password: 'pw2'),
      );
      await known.add(KnownHost(host: 'h1.contoh', port: 22, type: 'ssh-ed25519', fingerprint: fp));
      await service.deleteHost(id1);
      expect(known.all, hasLength(1));
      expect(hosts.snapshot.profiles.map((p) => p.id), [id2]);
    });

    test('gagal menghapus rahasia: host tetap ada dan bisa dicoba lagi', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      store.failDeletes = true;
      await expectLater(service.deleteHost(id1), throwsA(isA<VaultStorageException>()));
      expect(hosts.snapshot.profiles, hasLength(1));
      store.failDeletes = false;
      await service.deleteHost(id1);
      expect(hosts.snapshot.profiles, isEmpty);
    });

    test('host yang tidak ada: tidak berbuat apa-apa', () async {
      await service.deleteHost(id1);
      expect(hosts.snapshot.profiles, isEmpty);
    });

    test('baris gagal dihapus setelah rahasia terhapus: keadaan aman (baris tanpa rahasia)', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      final failing = JsonHostRepository(
        File('${dir.path}${Platform.pathSeparator}profiles.json'),
        writer: (f, b) async => throw const VaultStorageException('disk penuh'),
      );
      await failing.load();
      final svc = HostService(hosts: failing, knownHosts: known, vault: vault);
      await expectLater(svc.deleteHost(id1), throwsA(isA<VaultStorageException>()));
      expect(failing.snapshot.profiles, hasLength(1));
      expect(await vault.has(id1, SecretType.loginPassword), isFalse);
    });
  });

  group('runStartupMaintenance', () {
    test('membuang rahasia yatim', () async {
      await service.saveHost(profile(), secrets: const HostSecretsInput(password: 'pw'));
      await vault.put(id2, SecretType.loginPassword, 'yatim');
      expect(await service.runStartupMaintenance(profilesWereQuarantined: false), 1);
      expect(await vault.has(id2, SecretType.loginPassword), isFalse);
      expect(await vault.has(id1, SecretType.loginPassword), isTrue);
    });

    test('dilewati bila profiles.json dikarantina pada start ini', () async {
      await vault.put(id2, SecretType.loginPassword, 'mungkin-masih-dibutuhkan');
      expect(await service.runStartupMaintenance(profilesWereQuarantined: true), 0);
      expect(await vault.has(id2, SecretType.loginPassword), isTrue);
    });

    test('kegagalan vault tidak menghentikan aplikasi', () async {
      await vault.put(id2, SecretType.loginPassword, 'yatim');
      store.failDeletes = true;
      expect(await service.runStartupMaintenance(profilesWereQuarantined: false), 0);
    });
  });
}
