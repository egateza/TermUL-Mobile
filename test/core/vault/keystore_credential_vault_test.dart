import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/vault/credential_vault.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/core/vault/vault_exceptions.dart';

import 'fakes.dart';

const id1 = '11111111-1111-4111-8111-111111111111';
const id2 = '22222222-2222-4222-8222-222222222222';

void main() {
  late FakeDeviceAuth auth;
  late MemorySecretStore store;
  late MemoryVaultIndex index;
  late List<String> log;
  late KeystoreCredentialVault vault;

  setUp(() {
    log = [];
    auth = FakeDeviceAuth();
    store = MemorySecretStore();
    index = MemoryVaultIndex(log);
    vault = KeystoreCredentialVault(auth: auth, store: store, index: index);
  });

  group('nama kunci', () {
    test('ber-hash, stabil, tidak memuat id profil, dan beda per tipe dan profil', () {
      final a = KeystoreCredentialVault.keyName(id1, SecretType.loginPassword);
      expect(a, matches(RegExp(r'^termul\.secret\.[0-9a-f]{32}$')));
      expect(a, isNot(contains('11111111')));
      expect(KeystoreCredentialVault.keyName(id1, SecretType.loginPassword), a);
      expect(KeystoreCredentialVault.keyName(id1.toUpperCase(), SecretType.loginPassword), a);
      expect(KeystoreCredentialVault.keyName(id1, SecretType.keyPassphrase), isNot(a));
      expect(KeystoreCredentialVault.keyName(id2, SecretType.loginPassword), isNot(a));
    });

    test('kode SecretType 1 sampai 4 sama dengan desktop, 5 khusus mobile', () {
      expect(
        {for (final t in SecretType.values) t.wire: t.code},
        {'LOGIN_PASSWORD': 1, 'KEY_PASSPHRASE': 2, 'SUDO_PASSWORD': 3, 'ROOT_PASSWORD': 4, 'PRIVATE_KEY_PEM': 5},
      );
    });
  });

  group('gerbang pembacaan per tingkat', () {
    for (final level in [AuthLevel.biometric, AuthLevel.deviceCredential]) {
      test('${level.name}: baca meminta autentikasi sekali dengan alasan', () async {
        auth.currentLevel = level;
        await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
        expect(await vault.get(id1, SecretType.loginPassword, reason: 'Buka kredensial app-01'), 'rahasia-1');
        expect(auth.reasons, ['Buka kredensial app-01']);
      });

      test('${level.name}: dibatalkan -> VaultAuthException dan rahasia tidak dibaca', () async {
        auth.currentLevel = level;
        await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
        auth.result = false;
        await expectLater(
          vault.get(id1, SecretType.loginPassword, reason: 'x'),
          throwsA(isA<VaultAuthException>().having((e) => e.cancelled, 'cancelled', isTrue)),
        );
        expect(store.reads, 0);
      });

      test('${level.name}: perangkat tidak bisa autentikasi -> VaultAuthException(cancelled: false)', () async {
        auth.currentLevel = level;
        await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
        auth.throwOnAuthenticate = StateError('hardware');
        await expectLater(
          vault.get(id1, SecretType.loginPassword, reason: 'x'),
          throwsA(isA<VaultAuthException>().having((e) => e.cancelled, 'cancelled', isFalse)),
        );
        expect(store.reads, 0);
      });
    }

    test('none: tanpa prompt, rahasia tetap terbaca dan tersimpan di penyimpanan', () async {
      auth.currentLevel = AuthLevel.none;
      await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
      expect(await vault.get(id1, SecretType.loginPassword, reason: 'x'), 'rahasia-1');
      expect(auth.reasons, isEmpty);
    });

    test('tingkat dibaca ulang tiap kali: berubah setelah penyimpanan mengikuti keadaan terbaru', () async {
      auth.currentLevel = AuthLevel.none;
      await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
      auth.currentLevel = AuthLevel.deviceCredential;
      await vault.get(id1, SecretType.loginPassword, reason: 'x');
      expect(auth.reasons, hasLength(1));
      expect(await vault.authLevel(), AuthLevel.deviceCredential);
    });

    test('rahasia yang tidak ada: null (setelah autentikasi)', () async {
      expect(await vault.get(id1, SecretType.loginPassword, reason: 'x'), isNull);
    });

    test('kegagalan Keystore saat baca menjadi VaultStorageException', () async {
      await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
      store.failReads = true;
      await expectLater(vault.get(id1, SecretType.loginPassword, reason: 'x'), throwsA(isA<VaultStorageException>()));
    });
  });

  group('getMany', () {
    test('satu prompt untuk beberapa rahasia; hanya yang ada yang dikembalikan', () async {
      await vault.put(id1, SecretType.privateKeyPem, 'pem');
      await vault.put(id1, SecretType.keyPassphrase, 'frasa');
      final got = await vault.getMany(id1, {
        SecretType.privateKeyPem,
        SecretType.keyPassphrase,
        SecretType.loginPassword,
      }, reason: 'Buka kunci');
      expect(got, {SecretType.privateKeyPem: 'pem', SecretType.keyPassphrase: 'frasa'});
      expect(auth.reasons, ['Buka kunci']);
    });
  });

  group('has', () {
    test('tanpa prompt dan tanpa membaca nilai', () async {
      await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
      expect(await vault.has(id1, SecretType.loginPassword), isTrue);
      expect(await vault.has(id1, SecretType.keyPassphrase), isFalse);
      expect(auth.reasons, isEmpty);
      expect(store.reads, 0);
    });
  });

  group('urutan tulis dan hapus', () {
    test('put: nama masuk indeks dulu, lalu rahasia ditulis', () async {
      await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
      expect(log, ['index+']);
      expect(index.names, hasLength(1));
      expect(store.values.values, ['rahasia-1']);
    });

    test('put gagal menulis rahasia: nama tertinggal di indeks tanpa rahasia (tidak berbahaya)', () async {
      store.failWrites = true;
      await expectLater(vault.put(id1, SecretType.loginPassword, 'rahasia-1'), throwsA(isA<VaultStorageException>()));
      expect(store.values, isEmpty);
      expect(index.names, hasLength(1));
      // Pembersihan menyingkirkan nama itu bila profilnya tidak ada.
      store.failWrites = false;
      expect(await vault.sweepOrphans(liveProfileIds: {}), 1);
      expect(index.names, isEmpty);
    });

    test('remove: rahasia dihapus dulu, lalu nama keluar dari indeks', () async {
      await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
      log.clear();
      await vault.remove(id1, SecretType.loginPassword);
      expect(store.values, isEmpty);
      expect(index.names, isEmpty);
    });

    test('remove gagal menghapus rahasia: nama tetap di indeks supaya bisa dibersihkan nanti', () async {
      await vault.put(id1, SecretType.loginPassword, 'rahasia-1');
      store.failDeletes = true;
      await expectLater(vault.remove(id1, SecretType.loginPassword), throwsA(isA<VaultStorageException>()));
      expect(index.names, hasLength(1));
      expect(store.values, hasLength(1));
    });

    test('removeProfile menghapus semua jenis rahasia profil itu saja', () async {
      for (final t in SecretType.values) {
        await vault.put(id1, t, 'a-${t.code}');
      }
      await vault.put(id2, SecretType.loginPassword, 'milik-id2');
      await vault.removeProfile(id1);
      for (final t in SecretType.values) {
        expect(await vault.has(id1, t), isFalse, reason: t.wire);
      }
      expect(await vault.has(id2, SecretType.loginPassword), isTrue);
      expect(index.names, hasLength(1));
    });
  });

  group('sweepOrphans', () {
    test('menghapus hanya yang bukan milik profil hidup', () async {
      await vault.put(id1, SecretType.loginPassword, 'hidup');
      await vault.put(id1, SecretType.privateKeyPem, 'hidup-juga');
      await vault.put(id2, SecretType.loginPassword, 'yatim');
      expect(await vault.sweepOrphans(liveProfileIds: {id1}), 1);
      expect(await vault.has(id1, SecretType.loginPassword), isTrue);
      expect(await vault.has(id1, SecretType.privateKeyPem), isTrue);
      expect(await vault.has(id2, SecretType.loginPassword), isFalse);
      expect(index.names, hasLength(2));
    });

    test('tidak ada yatim: tidak menghapus apa pun', () async {
      await vault.put(id1, SecretType.loginPassword, 'hidup');
      expect(await vault.sweepOrphans(liveProfileIds: {id1}), 0);
      expect(store.values, hasLength(1));
    });

    test('rahasia di Keystore yang tidak tercatat di indeks tidak disentuh', () async {
      store.values['termul.secret.tidakdikenal'] = 'x';
      await vault.put(id1, SecretType.loginPassword, 'hidup');
      await vault.sweepOrphans(liveProfileIds: {id1});
      expect(store.values.containsKey('termul.secret.tidakdikenal'), isTrue);
    });
  });
}
