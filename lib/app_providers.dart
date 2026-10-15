import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'bootstrap.dart';
import 'core/keys/key_file_picker.dart';
import 'core/models/profile_snapshot.dart';
import 'core/ssh/ssh_connector.dart';
import 'core/storage/host_repository.dart';
import 'core/storage/known_hosts_repository.dart';
import 'core/vault/credential_vault.dart';
import 'features/connect/connect_flow.dart' show ConnectFunction;
import 'features/hosts/host_list_model.dart';
import 'features/hosts/host_service.dart';

/// Penyimpanan dan vault dibuat sekali di `bootstrap()` lalu disuntikkan lewat `overrides`.
final hostRepositoryProvider = Provider<HostRepository>((ref) => throw UnimplementedError('Suntikkan lewat bootstrap'));
final knownHostsRepositoryProvider = Provider<KnownHostsRepository>(
  (ref) => throw UnimplementedError('Suntikkan lewat bootstrap'),
);
final credentialVaultProvider = Provider<CredentialVault>(
  (ref) => throw UnimplementedError('Suntikkan lewat bootstrap'),
);
final hostServiceProvider = Provider<HostService>((ref) => throw UnimplementedError('Suntikkan lewat bootstrap'));
final bootReportProvider = Provider<BootReport>((ref) => const BootReport());

/// Pemilih berkas kunci; diganti di test.
final keyFilePickerProvider = Provider<KeyFilePicker>((ref) => const FileSelectorKeyPicker());

/// Konektor SSH; memakai penyimpanan sidik jari yang sama dengan seluruh aplikasi.
final sshConnectorProvider = Provider<SshConnector>(
  (ref) => SshConnector(knownHosts: ref.watch(knownHostsRepositoryProvider)),
);

/// Fungsi sambung yang dipakai alur sambung; diganti di tes.
final connectFunctionProvider = Provider<ConnectFunction>((ref) => ref.watch(sshConnectorProvider).connect);

extension AppDependenciesOverrides on AppDependencies {
  /// Override provider untuk `ProviderScope`.
  List<Override> get overrides => [
    hostRepositoryProvider.overrideWithValue(hosts),
    knownHostsRepositoryProvider.overrideWithValue(knownHosts),
    credentialVaultProvider.overrideWithValue(vault),
    hostServiceProvider.overrideWithValue(service),
    bootReportProvider.overrideWithValue(report),
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
