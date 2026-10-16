import 'dart:ui' show VoidCallback;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/features/connect/keepalive_sync.dart';

import 'fake_keepalive.dart';

ActiveSession session(int id, String name, [VoidCallback? onDisconnect]) =>
    ActiveSession(id: id, name: name, disconnect: onDisconnect ?? () {});

ProviderContainer make(FakeKeepAlive platform, {bool keepAlive = true}) {
  final container = ProviderContainer(
    overrides: [
      keepAlivePlatformProvider.overrideWithValue(platform),
      initialSettingsProvider.overrideWithValue(AppSettings(connection: ConnectionSettings(keepAlive: keepAlive))),
    ],
  );
  addTearDown(container.dispose);
  container.listen(keepAliveSyncProvider, (_, _) {});
  return container;
}

void main() {
  test('pengaturan mati: service tidak pernah dinyalakan', () async {
    final platform = FakeKeepAlive();
    final c = make(platform, keepAlive: false);
    c.read(activeSessionsProvider.notifier).register(session(1, 'app-01'));
    await Future<void>.delayed(Duration.zero);
    expect(platform.updates, isEmpty);
    expect(platform.stops, 0);
  });

  test(
    'pengaturan menyala: sesi pertama menyalakan, tambahan memperbarui judul dan nama, semua tertutup mematikan',
    () async {
      final platform = FakeKeepAlive();
      final c = make(platform);
      final sessions = c.read(activeSessionsProvider.notifier);
      expect(platform.updates, isEmpty, reason: 'tanpa sesi tidak ada service');

      sessions.register(session(1, 'app-01'));
      await Future<void>.delayed(Duration.zero);
      expect(platform.updates.last, (title: '1 sesi tersambung', text: 'app-01'));

      sessions.register(session(2, 'db-01'));
      await Future<void>.delayed(Duration.zero);
      expect(platform.updates.last, (title: '2 sesi tersambung', text: 'app-01, db-01'));

      sessions.unregister(1);
      await Future<void>.delayed(Duration.zero);
      expect(platform.updates.last, (title: '1 sesi tersambung', text: 'db-01'));
      expect(platform.stops, 0);

      sessions.unregister(2);
      await Future<void>.delayed(Duration.zero);
      expect(platform.stops, 1);
    },
  );

  test('mematikan pengaturan saat ada sesi menghentikan service; menyalakan lagi menyalakannya', () async {
    final platform = FakeKeepAlive();
    final c = make(platform);
    c.read(activeSessionsProvider.notifier).register(session(1, 'app-01'));
    await Future<void>.delayed(Duration.zero);
    final before = platform.updates.length;

    await c.read(appSettingsProvider.notifier).update(const AppSettings());
    await Future<void>.delayed(Duration.zero);
    expect(platform.stops, 1);

    await c
        .read(appSettingsProvider.notifier)
        .update(const AppSettings(connection: ConnectionSettings(keepAlive: true)));
    await Future<void>.delayed(Duration.zero);
    expect(platform.updates.length, before + 1);
  });

  test('perubahan yang tidak mengubah isi notifikasi tidak memanggil platform lagi', () async {
    final platform = FakeKeepAlive();
    final c = make(platform);
    c.read(activeSessionsProvider.notifier).register(session(1, 'app-01'));
    await Future<void>.delayed(Duration.zero);
    await c
        .read(appSettingsProvider.notifier)
        .update(c.read(appSettingsProvider).copyWith(terminal: const TerminalSettings(fontSize: 15)));
    await Future<void>.delayed(Duration.zero);
    expect(platform.updates, hasLength(1));
  });

  test('Android menolak memulai service: tidak melempar, dan dicoba lagi pada perubahan berikutnya', () async {
    final platform = FakeKeepAlive()..updateError = StateError('ditolak');
    final c = make(platform);
    final sessions = c.read(activeSessionsProvider.notifier);
    sessions.register(session(1, 'app-01'));
    await Future<void>.delayed(Duration.zero);
    expect(platform.updates, isEmpty);

    platform.updateError = null;
    sessions.register(session(2, 'db-01'));
    await Future<void>.delayed(Duration.zero);
    expect(platform.updates.last.title, '2 sesi tersambung');
  });

  test('Putuskan semua dari notifikasi menutup setiap sesi', () async {
    final platform = FakeKeepAlive();
    final c = make(platform);
    final closed = <int>[];
    final sessions = c.read(activeSessionsProvider.notifier);
    sessions.register(session(1, 'a', () => closed.add(1)));
    sessions.register(session(2, 'b', () => closed.add(2)));
    platform.disconnectAll!();
    expect(closed, [1, 2]);
  });

  test('ConnectionSettings: bawaan mati, dibaca dan ditulis, tipe salah dianggap rusak', () {
    expect(const AppSettings().connection.keepAlive, isFalse);
    expect(AppSettings.fromJson({}).connection.keepAlive, isFalse);
    final s = AppSettings.fromJson({
      'connection': {'keepAlive': true, 'lain': 1},
    });
    expect(s.connection.keepAlive, isTrue);
    expect(AppSettings.fromJson(s.toJson()).connection.keepAlive, isTrue);
    expect(
      () => AppSettings.fromJson({
        'connection': {'keepAlive': 'ya'},
      }),
      throwsFormatException,
    );
    // Mengubah terminal tidak menghilangkan pengaturan koneksi.
    final c = s.copyWith(terminal: const TerminalSettings(fontSize: 10));
    expect(c.connection.keepAlive, isTrue);
  });
}
