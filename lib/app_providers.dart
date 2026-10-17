import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:flutter_riverpod/misc.dart' show Override;

import 'bootstrap.dart';
import 'core/keys/key_file_picker.dart';
import 'core/models/app_settings.dart';
import 'core/platform/downloads_saver.dart';
import 'core/platform/keepalive_platform.dart';
import 'core/platform/screen_monitor.dart';
import 'core/models/profile_snapshot.dart';
import 'core/ssh/reconnect_backoff.dart';
import 'core/ssh/ssh_connector.dart';
import 'core/storage/host_repository.dart';
import 'core/storage/known_hosts_repository.dart';
import 'core/vault/auth_gate.dart';
import 'core/vault/credential_vault.dart';
import 'core/vault/device_auth.dart';
import 'core/vault/vault_lock.dart';
import 'features/connect/keepalive_sync.dart';
import 'features/connect/connect_flow.dart' show ConnectFunction;
import 'features/hosts/host_list_model.dart';
import 'features/terminal/shell_channel.dart';
import 'features/hosts/host_service.dart';
import 'features/sftp/upload_picker.dart';

/// Penyimpanan dan vault dibuat sekali di `bootstrap()` lalu disuntikkan lewat `overrides`.
final hostRepositoryProvider = Provider<HostRepository>((ref) => throw UnimplementedError('Suntikkan lewat bootstrap'));
final knownHostsRepositoryProvider = Provider<KnownHostsRepository>(
  (ref) => throw UnimplementedError('Suntikkan lewat bootstrap'),
);
final credentialVaultProvider = Provider<CredentialVault>(
  (ref) => throw UnimplementedError('Suntikkan lewat bootstrap'),
);
final hostServiceProvider = Provider<HostService>((ref) => throw UnimplementedError('Suntikkan lewat bootstrap'));

/// Pengaturan yang dimuat dari `settings.json` saat mulai; nilai awal [appSettingsProvider].
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

/// Menyimpan pengaturan ke `settings.json`. Bawaan: tidak menyimpan apa pun (tes).
final settingsSaverProvider = Provider<Future<void> Function(AppSettings)>((ref) => (_) async {});

/// Pengaturan yang berlaku. Perubahan dari layar pengaturan ([AppSettingsNotifier.update]) langsung berlaku di
/// sesi terminal yang sedang terbuka.
class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  /// Memakai [next] dan menyimpannya. Bila penyimpanan gagal, nilai tetap berlaku sampai aplikasi ditutup dan
  /// galatnya dilempar supaya layar bisa memberi tahu pengguna.
  Future<void> update(AppSettings next) async {
    state = next;
    await ref.read(settingsSaverProvider)(next);
  }

  /// Memakai [next] tanpa menyimpan (hasil membaca ulang berkas).
  void replace(AppSettings next) => state = next;
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

/// Memuat ulang `settings.json`; dipanggil tiap sesi baru dibuka supaya perubahan berkas langsung terpakai
/// tanpa menutup aplikasi. Bawaan: nilai yang dimuat saat mulai.
final settingsLoaderProvider = Provider<Future<AppSettings> Function()>((ref) {
  return () async => ref.read(appSettingsProvider);
});

/// Jembatan ke foreground service Android; diganti `NoopKeepAlive` di tes (bootstrap memasang yang nyata).
final keepAlivePlatformProvider = Provider<KeepAlivePlatform>((ref) => const NoopKeepAlive());

/// Gerbang prompt biometrik bersama semua sesi (satu prompt pada satu waktu, jeda setelah dibatalkan).
final authGateProvider = Provider<AuthGate>((ref) => AuthGate());

/// Status vault terbuka (chip di daftar host dan saklar di Pengaturan). Bootstrap memasang yang nyata; bawaan
/// (tes) memakai autentikasi yang selalu gagal sehingga vault tetap terkunci.
final vaultLockProvider = Provider<VaultLock>((ref) {
  final lock = VaultLock(auth: const _DeniedAuth());
  ref.onDispose(lock.dispose);
  return lock;
});

class _DeniedAuth implements DeviceAuth {
  const _DeniedAuth();

  @override
  Future<AuthLevel> level() async => AuthLevel.biometric;

  @override
  Future<bool> authenticate(String reason) async => false;
}

/// Pemantau layar mati; diganti `NoopScreenMonitor` di tes (bootstrap memasang yang nyata).
final screenMonitorProvider = Provider<ScreenMonitor>((ref) => const NoopScreenMonitor());

/// Sesi terminal yang sedang aktif; dipakai untuk isi notifikasi dan "Putuskan semua".
final activeSessionsProvider = NotifierProvider<ActiveSessionsNotifier, List<ActiveSession>>(
  ActiveSessionsNotifier.new,
);

final bootReportProvider = Provider<BootReport>((ref) => const BootReport());

/// Pemilih berkas kunci; diganti di test.
final keyFilePickerProvider = Provider<KeyFilePicker>((ref) => const FileSelectorKeyPicker());

/// Konektor SSH; memakai penyimpanan sidik jari yang sama dengan seluruh aplikasi.
final sshConnectorProvider = Provider<SshConnector>(
  (ref) => SshConnector(knownHosts: ref.watch(knownHostsRepositoryProvider)),
);

/// Fungsi sambung yang dipakai alur sambung; diganti di tes.
final connectFunctionProvider = Provider<ConnectFunction>((ref) => ref.watch(sshConnectorProvider).connect);

/// Menyimpan hasil unduhan SFTP ke Unduhan/TermUL; diganti di tes.
final downloadsSaverProvider = Provider<DownloadsSaver>((ref) => MethodChannelDownloadsSaver());

/// Pemilih berkas untuk unggahan SFTP; diganti di tes.
final uploadPickerProvider = Provider<UploadPicker>((ref) => const FileSelectorUploadPicker());

/// Folder berkas sementara unduhan (cache aplikasi); diganti di tes.
final tempDirProvider = Provider<Future<Directory> Function()>((ref) => getTemporaryDirectory);

/// Pemeriksa keterjangkauan host sebelum sambung ulang; diganti di tes.
final hostProbeProvider = Provider<HostProbe>((ref) => tcpProbe);

/// Membuka shell pada sambungan; diganti di tes.
typedef ShellOpenerFor = Future<ShellChannel> Function(
  SshConnection connection, {
  required int columns,
  required int rows,
});

final shellOpenerProvider = Provider<ShellOpenerFor>((ref) => SshShellChannel.open);

extension AppDependenciesOverrides on AppDependencies {
  /// Override provider untuk `ProviderScope`.
  List<Override> get overrides => [
    hostRepositoryProvider.overrideWithValue(hosts),
    knownHostsRepositoryProvider.overrideWithValue(knownHosts),
    credentialVaultProvider.overrideWithValue(vault),
    hostServiceProvider.overrideWithValue(service),
    bootReportProvider.overrideWithValue(report),
    initialSettingsProvider.overrideWithValue(settings),
    if (saveSettings != null) settingsSaverProvider.overrideWithValue(saveSettings!),
    if (keepAlive != null) keepAlivePlatformProvider.overrideWithValue(keepAlive!),
    if (screenMonitor != null) screenMonitorProvider.overrideWithValue(screenMonitor!),
    if (vaultLock != null) vaultLockProvider.overrideWithValue(vaultLock!),
    if (reloadSettings != null) settingsLoaderProvider.overrideWithValue(reloadSettings!),
  ];
}

/// Snapshot daftar host terbaru; berubah setiap repository mengumumkan perubahan.
class HostSnapshotNotifier extends Notifier<ProfileSnapshot> {
  @override
  ProfileSnapshot build() {
    final repo = ref.watch(hostRepositoryProvider);
    final sub = repo.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return repo.snapshot;
  }
}

final hostSnapshotProvider = NotifierProvider<HostSnapshotNotifier, ProfileSnapshot>(HostSnapshotNotifier.new);

class HostListState {
  const HostListState({this.query = '', this.filter = HostFilter.all, this.collapsed = const {}});

  final String query;
  final HostFilter filter;

  /// Path grup yang sedang diciutkan (hanya di memori).
  final Set<String> collapsed;

  HostListState copyWith({String? query, HostFilter? filter, Set<String>? collapsed}) =>
      HostListState(query: query ?? this.query, filter: filter ?? this.filter, collapsed: collapsed ?? this.collapsed);
}

class HostListNotifier extends Notifier<HostListState> {
  @override
  HostListState build() => const HostListState();

  void setQuery(String q) => state = state.copyWith(query: q);

  void setFilter(HostFilter f) => state = state.copyWith(filter: f);

  void toggleGroup(String path) {
    final next = {...state.collapsed};
    if (!next.remove(path)) next.add(path);
    state = state.copyWith(collapsed: next);
  }
}

final hostListProvider = NotifierProvider<HostListNotifier, HostListState>(HostListNotifier.new);

/// Tingkat penguncian HP; dibaca ulang tiap layar form dibuka.
final authLevelProvider = FutureProvider.autoDispose<AuthLevel>(
  (ref) => ref.watch(credentialVaultProvider).authLevel(),
);
