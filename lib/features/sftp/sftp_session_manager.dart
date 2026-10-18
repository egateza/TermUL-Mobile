import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/host_profile.dart';
import '../connect/connect_flow.dart';
import '../connect/keepalive_sync.dart';
import 'sftp_link.dart';

/// Satu sesi SFTP mandiri (koneksi SFTP sendiri ke satu host, bukan pinjaman dari sesi terminal).
class SftpSession {
  SftpSession({required this.id, required this.ordinal, required this.profile, required this.link, this.groupId})
    : startedAt = DateTime.now();

  final int id;

  /// Urutan di antara sesi SFTP ke profil yang sama (1, 2, ...), untuk membedakannya di daftar Sesi.
  final int ordinal;
  final HostProfile profile;
  final SftpLink link;
  final String? groupId;
  final DateTime startedAt;
}

/// Sesi SFTP mandiri yang dibiarkan hidup di latar belakang ("Tetap terhubung" di sheet keluar SFTP) dan bisa dibuka
/// lagi dari "Sesi". Seperti `SessionManager` untuk terminal: sesi yang sedang tampil di layar tidak ada di [state].
/// Setiap sesi didaftarkan ke foreground service selama hidup, jadi "Pertahankan koneksi" dan "Putuskan semua" di
/// notifikasi berlaku juga untuk SFTP.
class SftpSessionManager extends Notifier<List<SftpSession>> {
  int _nextId = 0;
  final _all = <SftpSession>[];

  @override
  List<SftpSession> build() => const [];

  List<SftpSession> forGroup(String groupId) => [
    for (final s in _all)
      if (s.groupId == groupId) s,
  ];

  void notifyGroupChanged() => _setState(List.of(state));

  /// Membuat sesi SFTP baru ke [profile] dan memulai sambungannya. Layar penjelajah yang membukanya.
  SftpSession create(HostProfile profile, {required String unlockReason, String? groupId}) {
    final link = SftpLink.own(
      profile: profile,
      flow: ConnectFlow(
        profile: profile,
        vault: ref.read(credentialVaultProvider),
        hosts: ref.read(hostRepositoryProvider),
        connect: ref.read(connectFunctionProvider),
        unlockReason: unlockReason,
        gate: ref.read(authGateProvider),
      ),
      probe: ref.read(hostProbeProvider),
      screenMonitor: ref.read(screenMonitorProvider),
      autoReconnect: () => ref.read(appSettingsProvider).connection.autoReconnect,
    );
    final session = adopt(profile, link, groupId: groupId);
    unawaited(link.start());
    return session;
  }

  /// Mendaftarkan [link] sebagai sesi (ke daftar dan ke foreground service). Dipakai [create]; terbuka untuk tes.
  @visibleForTesting
  SftpSession adopt(HostProfile profile, SftpLink link, {String? groupId}) {
    final ordinal = _all.where((s) => s.profile.id == profile.id).length + 1;
    final session = SftpSession(id: _nextId++, ordinal: ordinal, profile: profile, link: link, groupId: groupId);
    _all.add(session);
    notifyGroupChanged();
    // Id foreground service dibedakan dari sesi terminal (yang memakai id non-negatif) dengan nilai negatif.
    ref
        .read(activeSessionsProvider.notifier)
        .register(
          ActiveSession(id: _registryId(session), name: '${profile.name} · SFTP', disconnect: () => release(session)),
        );
    return session;
  }

  static int _registryId(SftpSession s) => -1 - s.id;

  /// Sesi dibuka lagi di layar: keluar dari daftar latar belakang (tetap hidup).
  void take(SftpSession session) => _setState([
    for (final s in state)
      if (s != session) s,
  ]);

  /// Sesi ditinggalkan layar tetapi dibiarkan hidup.
  void keep(SftpSession session) {
    if (!_all.contains(session) || state.contains(session)) return;
    _setState([...state, session]);
  }

  /// Menutup sesi sepenuhnya: sambungan SFTP dan alurnya ditutup, transfer yang berjalan dibatalkan.
  void release(SftpSession session) {
    if (!_all.remove(session)) return;
    _setState([
      for (final s in state)
        if (s != session) s,
    ]);
    try {
      ref.read(activeSessionsProvider.notifier).unregister(_registryId(session));
    } on Object {
      // Kontainer provider sudah dibuang.
    }
    session.link.transfers.cancelAll();
    session.link.dispose();
  }

  /// Menutup semua sesi SFTP di latar belakang.
  void disconnectAllKept() {
    for (final s in List.of(state)) {
      release(s);
    }
  }

  /// Lihat `SessionManager._setState`: pembaruan di tengah pembongkaran widget diulang di microtask.
  void _setState(List<SftpSession> next) {
    try {
      state = next;
    } on Object {
      scheduleMicrotask(() {
        try {
          state = List.of(next);
        } on Object {
          // Kontainer provider sudah dibuang.
        }
      });
    }
  }
}

final sftpSessionManagerProvider = NotifierProvider<SftpSessionManager, List<SftpSession>>(SftpSessionManager.new);
