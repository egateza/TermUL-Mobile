import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/host_profile.dart';
import 'connect_flow.dart';
import 'session_controller.dart';

/// Sesi yang dibiarkan hidup di latar belakang (layar terminalnya sudah ditutup lewat "Tetap terhubung") dan bisa
/// dibuka lagi dari "Sesi aktif". Sesi yang sedang tampil di layar tidak ada di daftar ini.
class SessionManager extends Notifier<List<SessionController>> {
  int _nextId = 0;
  final _all = <SessionController>[];

  @override
  List<SessionController> build() => const [];

  /// Membuat sesi baru ke [profile]. Alur sambung belum dimulai; pemanggil memanggil `start()`.
  SessionController create(HostProfile profile, {required String unlockReason, required String reconnectedMarker}) {
    final ordinal = _all.where((c) => c.profile.id == profile.id).length + 1;
    late final SessionController controller;
    controller = SessionController(
      id: _nextId++,
      ordinal: ordinal,
      profile: profile,
      flow: ConnectFlow(
        profile: profile,
        vault: ref.read(credentialVaultProvider),
        hosts: ref.read(hostRepositoryProvider),
        connect: ref.read(connectFunctionProvider),
        unlockReason: unlockReason,
      ),
      registry: ref.read(activeSessionsProvider.notifier),
      shellOpener: ref.read(shellOpenerProvider),
      reconnectedMarker: reconnectedMarker,
      onEndedWhileDetached: () => release(controller),
    );
    _all.add(controller);
    return controller;
  }

  /// Sesi dibuka lagi di layar: keluar dari daftar latar belakang (tetap hidup).
  void take(SessionController controller) => _setState([
    for (final c in state)
      if (c != controller) c,
  ]);

  /// Sesi ditinggalkan layar tetapi dibiarkan hidup.
  void keep(SessionController controller) {
    if (!_all.contains(controller) || state.contains(controller)) return;
    _setState([...state, controller]);
  }

  /// Menutup sesi sepenuhnya: sambungan, terminal, dan alur ditutup.
  void release(SessionController controller) {
    if (!_all.remove(controller)) return;
    _setState([
      for (final c in state)
        if (c != controller) c,
    ]);
    controller.dispose();
  }

  /// Menutup semua sesi di latar belakang.
  void disconnectAllKept() {
    for (final c in List.of(state)) {
      c.disconnectFromNotification();
    }
  }

  /// Mengubah state; bila pembaruan terjadi di tengah pembongkaran widget, Riverpod menolaknya (nilai baru sudah
  /// tersimpan tetapi pendengar tidak diberi tahu), jadi diulang di microtask dengan salinan daftar supaya
  /// perubahannya dianggap baru dan pendengar diberi tahu.
  void _setState(List<SessionController> next) {
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

final sessionManagerProvider = NotifierProvider<SessionManager, List<SessionController>>(SessionManager.new);
