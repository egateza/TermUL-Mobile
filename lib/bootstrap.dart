import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'core/models/app_settings.dart';
import 'core/storage/host_repository.dart';
import 'core/storage/json/json_host_repository.dart';
import 'core/storage/json/json_known_hosts_repository.dart';
import 'core/storage/json/json_settings_repository.dart';
import 'core/storage/known_hosts_repository.dart';
import 'core/storage/load_result.dart';
import 'core/vault/credential_vault.dart';
import 'core/vault/device_auth.dart';
import 'core/vault/keystore_credential_vault.dart';
import 'core/vault/secret_store.dart';
import 'core/vault/vault_index.dart';
import 'features/hosts/host_service.dart';

/// Ringkasan keadaan penyimpanan saat aplikasi mulai, untuk ditampilkan ke pengguna.
class BootReport {
  const BootReport({
    this.hosts = const LoadResult(),
    this.knownHosts = const LoadResult(),
    this.vaultIndex = const LoadResult(),
    this.settings = const LoadResult(),
    this.sweptSecrets = 0,
  });

  final LoadResult hosts;
  final LoadResult knownHosts;
  final LoadResult vaultIndex;

  /// `settings.json` rusak diganti nilai bawaan tanpa banner (pengaturan hilang tidak berbahaya).
  final LoadResult settings;

  /// Jumlah rahasia yatim yang dibuang saat mulai.
  final int sweptSecrets;
}

class AppDependencies {
  const AppDependencies({
    required this.hosts,
    required this.knownHosts,
    required this.vault,
    required this.service,
    required this.report,
    this.settings = const AppSettings(),
    this.reloadSettings,
  });

  final HostRepository hosts;
  final KnownHostsRepository knownHosts;
  final CredentialVault vault;
  final HostService service;
  final BootReport report;
  final AppSettings settings;

  /// Membaca ulang `settings.json` (dipanggil tiap sesi baru). `null` di tes yang tidak memerlukannya.
  final Future<AppSettings> Function()? reloadSettings;
}

/// Membuka semua penyimpanan di folder pribadi aplikasi, memuatnya, dan menjalankan perawatan awal. Melempar
/// `StorageException` bila berkas rusak tidak bisa disisihkan atau tidak bisa dibaca; saat itu tidak ada data yang
/// ditimpa dan aplikasi menampilkan layar galat.
Future<AppDependencies> bootstrap({Directory? directory, DeviceAuth? auth, SecretStore? store}) async {
  final dir = directory ?? await getApplicationSupportDirectory();
  File file(String name) => File('${dir.path}${Platform.pathSeparator}$name');

  final hosts = JsonHostRepository(file('profiles.json'));
  final known = JsonKnownHostsRepository(file('known_hosts.json'));
  final index = JsonVaultIndex(file('vault_index.json'));
  final hostsLoad = await hosts.load();
  final knownLoad = await known.load();
  final indexLoad = await index.load();
  final settingsRepo = JsonSettingsRepository(file('settings.json'));
  final settingsLoad = await settingsRepo.load();

  final vault = KeystoreCredentialVault(
    auth: auth ?? LocalAuthDeviceAuth(),
    store: store ?? FlutterSecureSecretStore(),
    index: index,
  );
  final service = HostService(hosts: hosts, knownHosts: known, vault: vault);
  final swept = await service.runStartupMaintenance(profilesWereQuarantined: hostsLoad.hadCorruptFile);

  return AppDependencies(
    hosts: hosts,
    knownHosts: known,
    vault: vault,
    service: service,
    settings: settingsRepo.settings,
    reloadSettings: () async {
      await settingsRepo.load();
      return settingsRepo.settings;
    },
    report: BootReport(
      hosts: hostsLoad,
      knownHosts: knownLoad,
      vaultIndex: indexLoad,
      settings: settingsLoad,
      sweptSecrets: swept,
    ),
  );
}
