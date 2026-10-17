import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/core/import/profile_file_picker.dart';
import 'package:termul_mobile/core/keys/key_file_picker.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/storage/json/json_host_repository.dart';
import 'package:termul_mobile/core/storage/json/json_known_hosts_repository.dart';
import 'package:termul_mobile/core/storage/streak_repository.dart';
import 'package:termul_mobile/core/streak/streak.dart';
import 'package:termul_mobile/core/streak/streak_record.dart';
import 'package:termul_mobile/core/storage/ui_state_repository.dart';
import 'package:termul_mobile/core/vault/device_auth.dart';
import 'package:termul_mobile/core/vault/keystore_credential_vault.dart';
import 'package:termul_mobile/core/vault/vault_lock.dart';
import 'package:termul_mobile/features/hosts/host_service.dart';
import 'package:termul_mobile/shared/widgets/termul_text_field.dart';

import '../core/vault/fakes.dart';

const id1 = '11111111-1111-4111-8111-111111111111';
const id2 = '22222222-2222-4222-8222-222222222222';
const id3 = '33333333-3333-4333-8333-333333333333';

Future<void> noWrite(File f, List<int> b) async {}

class FakeKeyPicker implements KeyFilePicker {
  Uint8List? next;
  Object? error;
  int calls = 0;

  @override
  Future<Uint8List?> pick() async {
    calls++;
    if (error != null) throw error!;
    return next;
  }
}

class FakeProfilePicker implements ProfileFilePicker {
  String? next;
  Object? error;

  @override
  Future<String?> pick() async {
    if (error != null) throw error!;
    return next;
  }
}

/// Seluruh ketergantungan aplikasi di memori: tanpa I/O berkas sungguhan (yang tidak selesai di dalam
/// `testWidgets`), tanpa Keystore dan autentikasi sungguhan.
class Harness {
  Harness({
    AuthLevel level = AuthLevel.biometric,
    BootReport report = const BootReport(),
    AppSettings settings = const AppSettings(),
    Future<void> Function(AppSettings)? saveSettings,
    MemoryUiStateRepository? uiState,
    MemoryStreakRepository? streak,
  }) : uiState = uiState ?? MemoryUiStateRepository(),
       // Bawaan: hari ini sudah dihitung, jadi splash streak tidak muncul di tes yang tidak membahasnya.
       streak = streak ?? MemoryStreakRepository(StreakRecord(streak: Streak(5, DateTime.now()))) {
    auth = FakeDeviceAuth(currentLevel: level);
    hosts = JsonHostRepository(File('tidak-dipakai-profiles.json'), writer: noWrite);
    known = JsonKnownHostsRepository(File('tidak-dipakai-known.json'), writer: noWrite);
    store = MemorySecretStore();
    index = MemoryVaultIndex();
    lock = VaultLock(auth: auth, alwaysOpen: settings.security.vaultAlwaysOpen);
    vault = KeystoreCredentialVault(auth: auth, store: store, index: index, lock: lock);
    service = HostService(hosts: hosts, knownHosts: known, vault: vault);
    deps = AppDependencies(
      hosts: hosts,
      knownHosts: known,
      vault: vault,
      service: service,
      report: report,
      settings: settings,
      saveSettings: saveSettings,
      vaultLock: lock,
      uiState: this.uiState,
      streak: this.streak,
    );
  }

  final MemoryUiStateRepository uiState;
  final MemoryStreakRepository streak;

  late final FakeDeviceAuth auth;
  late final VaultLock lock;
  late final JsonHostRepository hosts;
  late final JsonKnownHostsRepository known;
  late final MemorySecretStore store;
  late final MemoryVaultIndex index;
  late final KeystoreCredentialVault vault;
  late final HostService service;
  late final AppDependencies deps;
  final picker = FakeKeyPicker();
  final profilePicker = FakeProfilePicker();
  final connected = <HostProfile>[];

  Future<void> seed(List<HostProfile> profiles, {List<String> favorites = const []}) async {
    for (final p in profiles) {
      await hosts.save(p);
    }
    for (final f in favorites) {
      await hosts.setFavorite(f, favorite: true);
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    List<Override> overrides = const [],
    bool realConnect = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...deps.overrides,
          keyFilePickerProvider.overrideWithValue(picker),
          profileFilePickerProvider.overrideWithValue(profilePicker),
          ...overrides,
        ],
        child: TermulApp(onConnect: realConnect ? null : (context, profile) => connected.add(profile)),
      ),
    );
    await tester.pumpAndSettle();
  }
}

HostProfile host(
  String id, {
  String name = 'app-01',
  String? group,
  String hostName = '192.0.2.11',
  int port = 22,
  String user = 'deploy',
  AuthMethod auth = AuthMethod.password,
}) => HostProfile(id: id, name: name, group: group, host: hostName, port: port, username: user, authMethod: auth);

/// Kolom input (TextField) milik TermulTextField dengan label tertentu.
Finder inputByLabel(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is TermulTextField && w.label == label),
  matching: find.byType(TextField),
);
