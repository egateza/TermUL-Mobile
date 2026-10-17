import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/platform/screen_monitor.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/core/vault/vault_exceptions.dart';
import 'package:termul_mobile/core/vault/vault_lock.dart';

import 'fakes.dart';

const _id = '11111111-1111-4111-8111-111111111111';

class _Screen implements ScreenMonitor {
  int count = 0;
  bool failCount = false;
  final _events = StreamController<void>.broadcast(sync: true);

  void screenOff() {
    count++;
    _events.add(null);
  }

  @override
  Future<int> screenOffCount() async {
    if (failCount) throw StateError('kanal mati');
    return count;
  }

  @override
  Stream<void> get onScreenOff => _events.stream;
}

void main() {
  late FakeDeviceAuth auth;
  late _Screen screen;
  late VaultLock lock;
  late MemorySecretStore store;
  late KeystoreCredentialVault vault;

  setUp(() async {
    auth = FakeDeviceAuth();
    screen = _Screen();
    lock = VaultLock(auth: auth, screen: screen);
    store = MemorySecretStore();
    vault = KeystoreCredentialVault(auth: auth, store: store, index: MemoryVaultIndex(), lock: lock);
    await vault.put(_id, SecretType.loginPassword, 'rahasia-1');
  });

  tearDown(() => lock.dispose());

  test('terkunci: baca meminta autentikasi', () async {
    expect(lock.openNow, isFalse);
    await vault.get(_id, SecretType.loginPassword, reason: 'sambung');
    expect(auth.reasons, ['sambung']);
  });

  test('buka sementara: satu prompt untuk membuka, lalu baca tanpa prompt', () async {
    expect(await lock.unlock('buka'), isTrue);
    expect(auth.reasons, ['buka']);
    expect(lock.openNow, isTrue);
    expect(await vault.get(_id, SecretType.loginPassword, reason: 'sambung'), 'rahasia-1');
    expect(await vault.getMany(_id, {SecretType.loginPassword}, reason: 'sambung'), {
      SecretType.loginPassword: 'rahasia-1',
    });
    expect(auth.reasons, ['buka']);
  });

  test('autentikasi dibatalkan atau melempar: tetap terkunci', () async {
    auth.result = false;
    expect(await lock.unlock('buka'), isFalse);
    expect(lock.openNow, isFalse);
    auth.result = true;
    auth.throwOnAuthenticate = StateError('sensor');
    expect(await lock.unlock('buka'), isFalse);
    expect(lock.openNow, isFalse);
  });

  test('layar mati (peristiwa langsung) mengunci lagi', () async {
    await lock.unlock('buka');
    var notified = 0;
    lock.addListener(() => notified++);
    screen.screenOff();
    expect(lock.openNow, isFalse);
    expect(notified, 1);
    await expectLater(vault.get(_id, SecretType.loginPassword, reason: 'sambung'), completion('rahasia-1'));
    expect(auth.reasons, ['buka', 'sambung']);
  });

  test('layar mati tanpa peristiwa (Dart dibekukan): penghitung tetap mengunci', () async {
    await lock.unlock('buka');
    screen.count++; // peristiwa tidak sampai
    expect(await lock.isOpen(), isFalse);
    expect(lock.openNow, isFalse);
    await vault.get(_id, SecretType.loginPassword, reason: 'sambung');
    expect(auth.reasons, ['buka', 'sambung']);
  });

  test('refresh setelah resume mengunci bila layar sempat mati', () async {
    await lock.unlock('buka');
    screen.count++;
    await lock.refresh();
    expect(lock.openNow, isFalse);
  });

  test('penghitung layar tidak terbaca: gagal tertutup', () async {
    await lock.unlock('buka');
    screen.failCount = true;
    expect(await lock.isOpen(), isFalse);
    expect(lock.openNow, isFalse);
  });

  test('lock() mengunci buka sementara tetapi tidak mode selalu terbuka', () async {
    await lock.unlock('buka');
    lock.lock();
    expect(lock.openNow, isFalse);
    lock.alwaysOpen = true;
    lock.lock();
    expect(lock.openNow, isTrue);
  });

  test('selalu terbuka: baca tanpa prompt, layar mati tidak mengunci; dimatikan kembali meminta prompt', () async {
    lock.alwaysOpen = true;
    screen.screenOff();
    expect(await vault.get(_id, SecretType.loginPassword, reason: 'sambung'), 'rahasia-1');
    expect(auth.reasons, isEmpty);
    lock.alwaysOpen = false;
    expect(lock.openNow, isFalse);
    await vault.get(_id, SecretType.loginPassword, reason: 'sambung');
    expect(auth.reasons, ['sambung']);
  });

  test('mematikan selalu terbuka juga membuang buka sementara', () async {
    await lock.unlock('buka');
    lock.alwaysOpen = true;
    lock.alwaysOpen = false;
    expect(lock.openNow, isFalse);
  });

  test('HP tanpa penguncian layar: tanpa prompt, membuka tidak meminta autentikasi', () async {
    auth.currentLevel = AuthLevel.none;
    expect(await lock.unlock('buka'), isTrue);
    expect(auth.reasons, isEmpty);
  });

  test('gerbang yang gagal tetap melempar VaultAuthException saat terkunci', () async {
    auth.result = false;
    await expectLater(
      vault.get(_id, SecretType.loginPassword, reason: 'sambung'),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('SecuritySettings: bawaan mati, baca dan tulis JSON, bagian hilang memakai bawaan', () {
    expect(const AppSettings().security.vaultAlwaysOpen, isFalse);
    final on = AppSettings(security: const SecuritySettings(vaultAlwaysOpen: true));
    final back = AppSettings.fromJson(on.toJson());
    expect(back.security.vaultAlwaysOpen, isTrue);
    expect(AppSettings.fromJson({'version': 1}).security.vaultAlwaysOpen, isFalse);
  });
}
