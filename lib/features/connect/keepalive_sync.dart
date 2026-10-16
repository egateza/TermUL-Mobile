import 'dart:ui' show Locale, VoidCallback;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/ssh/connection_log.dart';
import '../../l10n/app_localizations.dart';

/// Satu sesi terminal yang sedang tersambung (atau sedang menyambung ulang). Didaftarkan oleh `ConnectScreen`.
class ActiveSession {
  const ActiveSession({required this.id, required this.name, required this.disconnect});

  final int id;

  /// Nama profil, untuk isi notifikasi.
  final String name;

  /// Menutup sesi ini (dipanggil dari "Putuskan semua" di notifikasi, juga saat aplikasi di latar belakang).
  final VoidCallback disconnect;
}

class ActiveSessionsNotifier extends Notifier<List<ActiveSession>> {
  @override
  List<ActiveSession> build() => const [];

  void register(ActiveSession session) => state = [...state, session];

  void unregister(int id) {
    if (!state.any((s) => s.id == id)) {
      return;
    }
    state = [
      for (final s in state)
        if (s.id != id) s,
    ];
  }

  void disconnectAll() {
    for (final s in List.of(state)) {
      s.disconnect();
    }
  }
}

/// Menyelaraskan foreground service dengan pengaturan "Pertahankan koneksi di latar belakang" dan daftar sesi
/// aktif: nyala selama pengaturan menyala dan ada sesi; mati selain itu. Dipasang sekali di akar aplikasi.
final keepAliveSyncProvider = Provider<void>((ref) {
  final platform = ref.watch(keepAlivePlatformProvider);
  platform.setDisconnectAllHandler(() => ref.read(activeSessionsProvider.notifier).disconnectAll());
  ref.onDispose(() => platform.setDisconnectAllHandler(null));

  String? last; // isi notifikasi yang sedang tampil; null = service tidak berjalan
  Future<void> sync() async {
    final enabled = ref.read(appSettingsProvider).connection.keepAlive;
    final sessions = ref.read(activeSessionsProvider);
    try {
      if (enabled && sessions.isNotEmpty) {
        final names = sessions.map((s) => s.name).join(', ');
        final key = '${sessions.length}|$names';
        if (key == last) return;
        last = key;
        final l = lookupAppLocalizations(const Locale('id'));
        await platform.update(
          title: l.keepAliveNotifTitle(sessions.length),
          text: names,
          actionLabel: l.keepAliveDisconnectAll,
          channelName: l.keepAliveChannelName,
        );
        connLog('foreground service nyala, ${sessions.length} sesi');
      } else if (last != null) {
        last = null;
        await platform.stop();
        connLog('foreground service dimatikan');
      }
    } on Object catch (e) {
      last = null;
      connLog('foreground service gagal: ${e.runtimeType}');
    }
  }

  ref.listen(appSettingsProvider, (_, _) => sync());
  ref.listen(activeSessionsProvider, (_, _) => sync());
  sync();
});
