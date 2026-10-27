import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'core/models/app_settings.dart';
import 'core/platform/keepalive_platform.dart';
import 'core/platform/reminder_platform.dart';
import 'core/platform/update_downloader.dart';
import 'core/platform/update_platform.dart';
import 'core/platform/screen_monitor.dart';
import 'core/storage/host_repository.dart';
import 'core/storage/json/json_host_repository.dart';
import 'core/storage/json/json_known_hosts_repository.dart';
import 'core/storage/json/json_settings_repository.dart';
import 'core/storage/json/json_snippet_repository.dart';
import 'core/storage/json/json_streak_repository.dart';
import 'core/storage/json/json_ui_state_repository.dart';
import 'core/storage/snippet_repository.dart';
import 'core/storage/streak_repository.dart';
import 'core/storage/ui_state_repository.dart';
import 'core/storage/known_hosts_repository.dart';
import 'core/storage/load_result.dart';
import 'core/update/update_service.dart';
import 'core/vault/credential_vault.dart';
import 'core/vault/device_auth.dart';
import 'core/vault/keystore_credential_vault.dart';
import 'core/vault/secret_store.dart';
import 'core/vault/vault_index.dart';
import 'core/vault/vault_lock.dart';
import 'features/hosts/host_service.dart';
import 'features/update/update_controller.dart' show updateRepo;

/// Ringkasan keadaan penyimpanan saat aplikasi mulai, untuk ditampilkan ke pengguna.
class BootReport {
  const BootReport({
    this.hosts = const LoadResult(),
    this.knownHosts = const LoadResult(),
    this.vaultIndex = const LoadResult(),
    this.settings = const LoadResult(),
    this.snippets = const LoadResult(),
    this.streak = const LoadResult(),
    this.sweptSecrets = 0,
  });

  final LoadResult hosts;
  final LoadResult knownHosts;
  final LoadResult vaultIndex;

  /// `settings.json` rusak diganti nilai bawaan tanpa banner (pengaturan hilang tidak berbahaya).
  final LoadResult settings;

  /// `snippets.json` rusak disisihkan dan daftar dimulai kosong; layar Snippet memberi tahu lewat banner.
  final LoadResult snippets;

  /// `streak.json` rusak disisihkan dan streak mulai dari awal; layar Streak memberi tahu lewat banner.
  final LoadResult streak;

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
    this.saveSettings,
    this.keepAlive,
    this.screenMonitor,
    this.vaultLock,
    this.snippets,
    this.uiState,
    this.streak,
    this.reminder,
    this.updatePlatform,
    this.updateDownloader,
    this.updateService,
  });

  final HostRepository hosts;
  final KnownHostsRepository knownHosts;
  final CredentialVault vault;
  final HostService service;
  final BootReport report;
  final AppSettings settings;

  /// Membaca ulang `settings.json` (dipanggil tiap sesi baru). `null` di tes yang tidak memerlukannya.
  final Future<AppSettings> Function()? reloadSettings;

  /// Menyimpan `settings.json`. `null` di tes yang tidak memerlukannya.
  final Future<void> Function(AppSettings)? saveSettings;

  /// Foreground service Android. `null` di tes (memakai `NoopKeepAlive`).
  final KeepAlivePlatform? keepAlive;

  /// Pemantau layar mati. `null` di tes (memakai `NoopScreenMonitor`).
  final ScreenMonitor? screenMonitor;

  /// Status vault terbuka. `null` di tes (provider memakai kunci yang selalu terkunci).
  final VaultLock? vaultLock;

  /// Penyimpanan snippet. `null` di tes (memakai salinan di memori).
  final SnippetRepository? snippets;

  /// Keadaan tampilan yang diingat. `null` di tes (memakai salinan di memori).
  final UiStateRepository? uiState;

  /// Penyimpanan streak. `null` di tes (memakai salinan di memori).
  final StreakRepository? streak;

  /// Pengingat streak harian Android. `null` di tes (memakai `NoopReminder`).
  final ReminderPlatform? reminder;

  /// Versi terpasang dan penginstal Android. `null` di tes (memakai `FakeUpdatePlatform`).
  final UpdatePlatform? updatePlatform;

  /// Unduhan pembaruan lewat DownloadManager; null (tes) = unduh di dalam aplikasi.
  final UpdateDownloader? updateDownloader;

  /// Rilis dari GitHub. `null` di tes (tanpa jaringan, tanpa rilis).
  final UpdateService? updateService;
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
  final snippetRepo = JsonSnippetRepository(file('snippets.json'));
  final snippetsLoad = await snippetRepo.load();
  final streakRepo = JsonStreakRepository(file('streak.json'));
  final streakLoad = await streakRepo.load();
  // Rusak: disisihkan dan semua grup terbuka, tanpa banner (keadaan tampilan hilang tidak berbahaya).
  final uiState = JsonUiStateRepository(file('ui_state.json'));
  await uiState.load();

  final deviceAuth = auth ?? LocalAuthDeviceAuth();
  final screenMonitor = MethodChannelScreenMonitor();
  final vaultLock = VaultLock(
    auth: deviceAuth,
    screen: screenMonitor,
    alwaysOpen: settingsRepo.settings.security.vaultAlwaysOpen,
  );
  final vault = KeystoreCredentialVault(
    auth: deviceAuth,
    store: store ?? FlutterSecureSecretStore(),
    index: index,
    lock: vaultLock,
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
    saveSettings: settingsRepo.save,
    keepAlive: MethodChannelKeepAlive(),
    screenMonitor: screenMonitor,
    vaultLock: vaultLock,
    snippets: snippetRepo,
    uiState: uiState,
    streak: streakRepo,
    reminder: MethodChannelReminder(),
    updatePlatform: MethodChannelUpdatePlatform(),
    updateDownloader: MethodChannelUpdateDownloader(),
    updateService: GitHubUpdateService(repo: updateRepo, tempDir: getTemporaryDirectory),
    report: BootReport(
      hosts: hostsLoad,
      knownHosts: knownLoad,
      vaultIndex: indexLoad,
      settings: settingsLoad,
      snippets: snippetsLoad,
      streak: streakLoad,
      sweptSecrets: swept,
    ),
  );
}
