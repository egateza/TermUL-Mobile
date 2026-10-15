import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/secret_store.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/core/vault/vault_index.dart';

/// Vault pada Keystore dan `local_auth` sungguhan. Jalankan:
/// `flutter test integration_test/vault_test.dart -d <perangkat> --dart-define=EXPECT_LEVEL=none|deviceCredential|biometric`
/// (ubah kunci layar perangkat lebih dulu; tanpa EXPECT_LEVEL, deteksi hanya dicetak). Prompt nyata diuji di
/// `PROMPT=true` dan membutuhkan seseorang (atau adb) menjawab dialog sistem.
const expectLevel = String.fromEnvironment('EXPECT_LEVEL');
const promptTest = bool.fromEnvironment('PROMPT');

const id = '11111111-1111-4111-8111-111111111111';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late KeystoreCredentialVault vault;
  late LocalAuthDeviceAuth auth;

  setUp(() async {
    final base = await getApplicationSupportDirectory();
    dir = await Directory('${base.path}${Platform.pathSeparator}vault_${DateTime.now().microsecondsSinceEpoch}')
        .create(recursive: true);
    auth = LocalAuthDeviceAuth();
    vault = KeystoreCredentialVault(
      auth: auth,
      store: FlutterSecureSecretStore(),
      index: JsonVaultIndex(File('${dir.path}${Platform.pathSeparator}vault_index.json')),
    );
  });

  tearDown(() async {
    await vault.removeProfile(id);
    await dir.delete(recursive: true);
  });

  testWidgets('deteksi tingkat penguncian perangkat', (tester) async {
    final level = await vault.authLevel();
    // ignore: avoid_print
    print('TINGKAT_PENGUNCIAN=${level.name}');
    if (expectLevel.isNotEmpty) {
      expect(level.name, expectLevel);
    }
  });

  testWidgets('Keystore sungguhan: simpan, ada, hapus (tanpa membaca nilai)', (tester) async {
    await vault.put(id, SecretType.loginPassword, 'nilai-uji-bukan-kredensial');
    expect(await vault.has(id, SecretType.loginPassword), isTrue);
    expect(await vault.has(id, SecretType.keyPassphrase), isFalse);
    await vault.remove(id, SecretType.loginPassword);
    expect(await vault.has(id, SecretType.loginPassword), isFalse);
  });

  testWidgets('pembersihan yatim pada Keystore sungguhan', (tester) async {
    const other = '22222222-2222-4222-8222-222222222222';
    await vault.put(id, SecretType.loginPassword, 'a');
    await vault.put(other, SecretType.loginPassword, 'b');
    expect(await vault.sweepOrphans(liveProfileIds: {id}), 1);
    expect(await vault.has(id, SecretType.loginPassword), isTrue);
    expect(await vault.has(other, SecretType.loginPassword), isFalse);
  });

  testWidgets('baca rahasia dengan gerbang sesuai tingkat', (tester) async {
    await vault.put(id, SecretType.loginPassword, 'nilai-uji-bukan-kredensial');
    final level = await vault.authLevel();
    if (level != AuthLevel.none && !promptTest) {
      markTestSkipped('butuh jawaban dialog sistem; jalankan dengan --dart-define=PROMPT=true');
      return;
    }
    final value = await vault.get(id, SecretType.loginPassword, reason: 'Uji buka kredensial');
    expect(value, 'nilai-uji-bukan-kredensial');
  });
}
