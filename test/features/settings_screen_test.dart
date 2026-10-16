import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';

import 'fake_keepalive.dart';
import 'hosts_ui_harness.dart';

/// Membuka layar Pengaturan dari daftar host, dengan penyimpanan palsu yang mencatat setiap simpanan.
class _Setup {
  final saved = <AppSettings>[];
  Object? saveError;

  Future<void> save(AppSettings s) async {
    if (saveError != null) throw saveError!;
    saved.add(s);
  }

  final keepAlive = FakeKeepAlive();

  Future<Harness> open(WidgetTester tester, {AppSettings initial = const AppSettings()}) async {
    final h = Harness(settings: initial, saveSettings: save);
    await h.pump(tester, overrides: [keepAlivePlatformProvider.overrideWithValue(keepAlive)]);
    await tester.tap(find.bySemanticsLabel('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    return h;
  }
}

AppSettings _current(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SettingsScreen))).read(appSettingsProvider);

double _previewFontSize(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(of: find.byKey(const ValueKey('settings-preview')), matching: find.byType(Text)),
  );
  return text.textSpan!.style!.fontSize!;
}

void main() {
  testWidgets('menampilkan bagian Terminal dengan nilai bawaan dan pratinjau', (tester) async {
    await _Setup().open(tester);
    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('TERMINAL'), findsOneWidget);
    expect(find.text('Ukuran font'), findsOneWidget);
    expect(find.text('13 px'), findsOneWidget);
    expect(find.text('Tinggi baris'), findsOneWidget);
    expect(find.text('1,3×'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-preview')), findsOneWidget);
    expect(_previewFontSize(tester), 13);
  });

  testWidgets('tombol font mengubah nilai, pratinjau, dan menyimpan', (tester) async {
    final setup = _Setup();
    await setup.open(tester);
    await tester.tap(find.bySemanticsLabel('Besarkan font'));
    await tester.pumpAndSettle();
    expect(find.text('14 px'), findsOneWidget);
    expect(_previewFontSize(tester), 14);
    expect(_current(tester).terminal.fontSize, 14);
    expect(setup.saved.last.terminal.fontSize, 14);

    await tester.tap(find.bySemanticsLabel('Kecilkan font'));
    await tester.tap(find.bySemanticsLabel('Kecilkan font'));
    await tester.pumpAndSettle();
    expect(find.text('12 px'), findsOneWidget);
    expect(setup.saved.last.terminal.fontSize, 12);
  });

  testWidgets(
    'bentuk gagang seleksi: bawaan tetesan; memilih Segitiga dan Bulatan menyimpan; ukuran huruf tidak mengubahnya',
    (tester) async {
      final setup = _Setup();
      await setup.open(tester);
      expect(find.text('Bentuk gagang seleksi'), findsOneWidget);
      expect(_current(tester).terminal.handleStyle, SelectionHandleStyle.drop);
      await tester.ensureVisible(find.text('Segitiga'));
      await tester.tap(find.text('Segitiga'));
      await tester.pumpAndSettle();
      expect(setup.saved.last.terminal.handleStyle, SelectionHandleStyle.triangle);
      await tester.scrollUntilVisible(find.bySemanticsLabel('Besarkan font'), -100);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Besarkan font'));
      await tester.pumpAndSettle();
      expect(setup.saved.last.terminal.handleStyle, SelectionHandleStyle.triangle);
      expect(setup.saved.last.terminal.fontSize, 14);
      await tester.ensureVisible(find.text('Bulatan'));
      await tester.tap(find.text('Bulatan'));
      await tester.pumpAndSettle();
      expect(setup.saved.last.terminal.handleStyle, SelectionHandleStyle.dot);
    },
  );

  testWidgets('tinggi baris bergerak 0,1 tanpa sisa desimal', (tester) async {
    final setup = _Setup();
    await setup.open(tester);
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.pumpAndSettle();
    expect(find.text('1,6×'), findsOneWidget);
    expect(setup.saved.last.terminal.lineHeight, 1.6);
    await tester.tap(find.bySemanticsLabel('Rapatkan baris'));
    await tester.pumpAndSettle();
    expect(setup.saved.last.terminal.lineHeight, 1.5);
  });

  testWidgets('di batas rentang tombol nonaktif', (tester) async {
    final setup = _Setup();
    await setup.open(tester, initial: const AppSettings(terminal: TerminalSettings(fontSize: 8, lineHeight: 2.0)));
    expect(find.text('8 px'), findsOneWidget);
    expect(find.text('2,0×'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Kecilkan font'));
    await tester.tap(find.bySemanticsLabel('Renggangkan baris'));
    await tester.pumpAndSettle();
    expect(setup.saved, isEmpty);
    expect(_current(tester).terminal.fontSize, 8);
  });

  testWidgets('Kembalikan bawaan menulis nilai bawaan dan nonaktif bila sudah bawaan', (tester) async {
    final setup = _Setup();
    await setup.open(tester, initial: const AppSettings(terminal: TerminalSettings(fontSize: 18, lineHeight: 1.8)));
    await tester.tap(find.text('Kembalikan bawaan'));
    await tester.pumpAndSettle();
    expect(setup.saved.single.terminal, const TerminalSettings());
    expect(find.text('13 px'), findsOneWidget);
    await tester.tap(find.text('Kembalikan bawaan'));
    await tester.pumpAndSettle();
    expect(setup.saved, hasLength(1));
  });

  testWidgets('gagal menyimpan: banner tampil, nilai tetap berlaku, hilang setelah berhasil', (tester) async {
    final setup = _Setup()..saveError = const FormatException('disk penuh');
    await setup.open(tester);
    await tester.tap(find.bySemanticsLabel('Besarkan font'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan tidak tersimpan'), findsOneWidget);
    expect(_current(tester).terminal.fontSize, 14);
    setup.saveError = null;
    await tester.tap(find.bySemanticsLabel('Besarkan font'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan tidak tersimpan'), findsNothing);
    expect(setup.saved.single.terminal.fontSize, 15);
  });

  testWidgets('target sentuh tombol langkah minimal 44 px; sebagai tab tanpa tombol Kembali', (tester) async {
    await _Setup().open(tester);
    for (final label in ['Kecilkan font', 'Besarkan font', 'Rapatkan baris', 'Renggangkan baris']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(TermulSize.tapMin), reason: label);
      expect(size.height, greaterThanOrEqualTo(TermulSize.tapMin), reason: label);
    }
    expect(find.bySemanticsLabel('Kembali'), findsNothing);
  });

  group('bagian Koneksi', () {
    Future<void> scrollToKoneksi(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.text('Pertahankan koneksi di latar belakang'), 200);
      await tester.pumpAndSettle();
    }

    testWidgets('bawaan mati; menyalakan dengan izin tersimpan dan menampilkan catatan, izin, dan baterai', (
      tester,
    ) async {
      final setup = _Setup();
      await setup.open(tester);
      await scrollToKoneksi(tester);
      expect(find.text('KONEKSI'), findsOneWidget);
      expect(find.text('Pembatasan baterai HP'), findsNothing);

      await tester.tap(find.text('Pertahankan koneksi di latar belakang'));
      await tester.pumpAndSettle();
      expect(setup.saved.last.connection.keepAlive, isTrue);
      expect(_current(tester).connection.keepAlive, isTrue);
      await tester.scrollUntilVisible(find.text('Pembatasan baterai HP'), 200);
      expect(find.text('Izin notifikasi'), findsOneWidget);
      expect(find.text('Diizinkan'), findsOneWidget);
      expect(find.textContaining('tidak menjaminnya'), findsOneWidget);
    });

    testWidgets('sambung ulang otomatis: bawaan nyala, mematikan tersimpan tanpa mengubah Tetap terhubung', (
      tester,
    ) async {
      final setup = _Setup();
      await setup.open(tester, initial: const AppSettings(connection: ConnectionSettings(keepAlive: true)));
      await scrollToKoneksi(tester);
      expect(_current(tester).connection.autoReconnect, isTrue);

      await tester.scrollUntilVisible(find.text('Sambung ulang otomatis'), -200);
      await tester.tap(find.text('Sambung ulang otomatis'));
      await tester.pumpAndSettle();
      expect(setup.saved.last.connection.autoReconnect, isFalse);
      expect(setup.saved.last.connection.keepAlive, isTrue);
    });

    testWidgets('izin ditolak: saklar tetap mati, pesan tampil, tidak menyimpan', (tester) async {
      final setup = _Setup();
      setup.keepAlive
        ..enabled = false
        ..grantOnRequest = false;
      await setup.open(tester);
      await scrollToKoneksi(tester);
      await tester.tap(find.text('Pertahankan koneksi di latar belakang'));
      await tester.pumpAndSettle();
      expect(find.text('Izin notifikasi diperlukan untuk menjaga koneksi'), findsOneWidget);
      expect(_current(tester).connection.keepAlive, isFalse);
      expect(setup.saved, isEmpty);
    });

    testWidgets('izin dicabut setelah menyala: status Belum diizinkan dengan tombol Izinkan', (tester) async {
      final setup = _Setup();
      setup.keepAlive.enabled = false;
      await setup.open(tester, initial: const AppSettings(connection: ConnectionSettings(keepAlive: true)));
      await tester.scrollUntilVisible(find.text('Izin notifikasi'), 200);
      expect(find.text('Belum diizinkan'), findsOneWidget);
      setup.keepAlive.grantOnRequest = true;
      await tester.ensureVisible(find.text('Izinkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Izinkan'));
      await tester.pumpAndSettle();
      expect(find.text('Diizinkan'), findsOneWidget);
      expect(find.text('Izinkan'), findsNothing);
    });

    testWidgets('Buka pengaturan memanggil platform; mematikan saklar menyimpan mati', (tester) async {
      final setup = _Setup();
      await setup.open(tester, initial: const AppSettings(connection: ConnectionSettings(keepAlive: true)));
      await tester.scrollUntilVisible(find.text('Buka pengaturan'), 200);
      await tester.ensureVisible(find.text('Buka pengaturan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka pengaturan'));
      expect(setup.keepAlive.settingsOpened, 1);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pertahankan koneksi di latar belakang'));
      await tester.pumpAndSettle();
      expect(setup.saved.last.connection.keepAlive, isFalse);
      expect(find.text('Pembatasan baterai HP'), findsNothing);
    });

    testWidgets('mengubah ukuran font tidak mengubah pengaturan koneksi', (tester) async {
      final setup = _Setup();
      await setup.open(tester, initial: const AppSettings(connection: ConnectionSettings(keepAlive: true)));
      await tester.tap(find.bySemanticsLabel('Besarkan font'));
      await tester.pumpAndSettle();
      expect(setup.saved.last.terminal.fontSize, 14);
      expect(setup.saved.last.connection.keepAlive, isTrue);
    });
  });
}
