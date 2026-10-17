import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/platform/update_platform.dart';
import 'package:termul_mobile/core/update/release.dart';
import 'package:termul_mobile/core/update/update_service.dart';
import 'package:termul_mobile/features/settings/settings_screen.dart';
import 'package:termul_mobile/features/update/update_controller.dart';

import 'hosts_ui_harness.dart';

ReleaseInfo _release({String tag = 'v0.2.0', String notes = 'Perbaikan sambung ulang di HyperOS.'}) => ReleaseInfo(
  tag: tag,
  version: ReleaseVersion.tryParse(tag)!,
  notes: notes,
  page: null,
  apk: ReleaseAsset(name: 'termul.apk', url: Uri.parse('https://example.invalid/termul.apk'), size: 25 * 1024 * 1024),
  checksum: ReleaseAsset(name: 'termul.apk.sha256', url: Uri.parse('https://example.invalid/termul.apk.sha256'), size: 80),
);

/// Sumber rilis yang dikendalikan tes; unduhan menunggu sampai [finish] atau [fail].
class _FakeService implements UpdateService {
  _FakeService({this.release});

  ReleaseInfo? release;
  Object? latestError;
  int latestCalls = 0;
  Completer<String>? _pending;
  void Function(int, int)? progress;
  UpdateCancelToken? token;

  @override
  Future<ReleaseInfo?> latest() async {
    latestCalls++;
    if (latestError != null) throw latestError!;
    return release;
  }

  @override
  Future<String> download(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    UpdateCancelToken? cancel,
  }) {
    progress = onProgress;
    token = cancel;
    _pending = Completer<String>();
    return _pending!.future;
  }

  void finish([String path = '/cache/update/termul-update.apk']) => _pending!.complete(path);

  void fail(UpdateFailure failure) => _pending!.completeError(UpdateException(failure));
}

class _Setup {
  _Setup({ReleaseInfo? release}) : service = _FakeService(release: release);

  final _FakeService service;
  final platform = FakeUpdatePlatform();

  Future<void> launch(WidgetTester tester) async {
    await Harness().pump(
      tester,
      overrides: [
        updateServiceProvider.overrideWithValue(service),
        updatePlatformProvider.overrideWithValue(platform),
      ],
    );
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('version-footer')), 300);
    await tester.pumpAndSettle();
  }
}

Finder get _dot => find.byKey(const ValueKey('nav-dot-settings'));

void main() {
  testWidgets('versi dan build tampil di paling bawah Pengaturan; belum ada rilis', (tester) async {
    final setup = _Setup();
    await setup.launch(tester);
    expect(setup.service.latestCalls, 1, reason: 'diperiksa sekali saat aplikasi dibuka');
    expect(_dot, findsNothing);
    await setup.openSettings(tester);
    expect(find.text('TermUL Mobile 0.1.0 · build 1'), findsOneWidget);
    expect(find.text('PEMBARUAN'), findsOneWidget);
    expect(find.text('Belum ada rilis di GitHub'), findsOneWidget);
    expect(find.text('Periksa'), findsOneWidget);

    // Teks kaki adalah baris terakhir di daftar.
    final footer = tester.getRect(find.byKey(const ValueKey('version-footer')));
    final card = tester.getRect(find.byKey(const ValueKey('update-card')));
    expect(footer.top, greaterThan(card.bottom));
  });

  testWidgets('versi terbaru: tanpa lencana, status Sudah versi terbaru; Periksa memeriksa lagi', (tester) async {
    final setup = _Setup(release: _release(tag: 'v0.1.0'));
    await setup.launch(tester);
    expect(_dot, findsNothing);
    await setup.openSettings(tester);
    expect(find.text('Sudah versi terbaru'), findsOneWidget);
    await tester.tap(find.text('Periksa'));
    await tester.pumpAndSettle();
    expect(setup.service.latestCalls, 2);
  });

  testWidgets('ada versi baru: lencana titik di tab Pengaturan dengan nama aksesibilitas, rincian rilis di layar', (
    tester,
  ) async {
    final setup = _Setup(release: _release());
    await setup.launch(tester);
    expect(_dot, findsOneWidget);
    expect(find.bySemanticsLabel('Pengaturan, pembaruan tersedia'), findsOneWidget);
    await setup.openSettings(tester);
    expect(find.text('Versi 0.2.0 tersedia'), findsOneWidget);
    expect(find.text('Ukuran 25 MB'), findsOneWidget);
    expect(find.text('Perbaikan sambung ulang di HyperOS.'), findsOneWidget);
    expect(find.text('Unduh dan pasang'), findsOneWidget);
    expect(find.text('Periksa'), findsNothing);
  });

  testWidgets('gagal memeriksa: status dan alasan dengan kata, Coba lagi berhasil', (tester) async {
    final setup = _Setup(release: _release());
    setup.service.latestError = const UpdateException(UpdateFailure.network);
    await setup.launch(tester);
    expect(_dot, findsNothing);
    await setup.openSettings(tester);
    expect(find.text('Gagal memeriksa'), findsOneWidget);
    expect(find.text('Tidak bisa menghubungi GitHub. Periksa koneksi lalu coba lagi.'), findsOneWidget);
    setup.service.latestError = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Versi 0.2.0 tersedia'), findsOneWidget);
    expect(_dot, findsOneWidget);
  });

  testWidgets('unduh dengan kemajuan, siap dipasang, lalu Pasang membuka penginstal', (tester) async {
    final setup = _Setup(release: _release());
    await setup.launch(tester);
    await setup.openSettings(tester);
    await tester.tap(find.text('Unduh dan pasang'));
    await tester.pump();
    expect(find.text('Mengunduh versi 0.2.0'), findsOneWidget);
    setup.service.progress!(10 * 1024 * 1024, 25 * 1024 * 1024);
    await tester.pump();
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('10 MB dari 25 MB'), findsOneWidget);
    expect(find.text('Batalkan unduhan'), findsOneWidget);

    setup.service.finish();
    await tester.pumpAndSettle();
    expect(find.text('Versi 0.2.0 siap dipasang'), findsOneWidget);
    expect(_dot, findsOneWidget);
    await tester.ensureVisible(find.text('Pasang'));
    await tester.tap(find.text('Pasang'));
    await tester.pumpAndSettle();
    expect(setup.platform.installed, ['/cache/update/termul-update.apk']);
  });

  testWidgets('izin pasang belum diberikan: banner dengan Buka pengaturan, penginstal tidak dibuka', (tester) async {
    final setup = _Setup(release: _release());
    setup.platform.allowed = false;
    await setup.launch(tester);
    await setup.openSettings(tester);
    await tester.tap(find.text('Unduh dan pasang'));
    await tester.pump();
    setup.service.finish();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pasang'));
    await tester.tap(find.text('Pasang'));
    await tester.pumpAndSettle();
    expect(find.text('Izinkan pemasangan dari TermUL'), findsOneWidget);
    expect(setup.platform.installed, isEmpty);
    await tester.tap(find.text('Buka pengaturan'));
    expect(setup.platform.settingsOpened, 1);

    // Kembali dari halaman izin dengan izin diberikan: banner hilang, Pasang membuka penginstal.
    setup.platform.allowed = true;
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
    expect(find.text('Izinkan pemasangan dari TermUL'), findsNothing);
    await tester.ensureVisible(find.text('Pasang'));
    await tester.tap(find.text('Pasang'));
    await tester.pumpAndSettle();
    expect(setup.platform.installed, hasLength(1));
  });

  testWidgets('batalkan unduhan kembali ke Versi tersedia', (tester) async {
    final setup = _Setup(release: _release());
    await setup.launch(tester);
    await setup.openSettings(tester);
    await tester.tap(find.text('Unduh dan pasang'));
    await tester.pump();
    await tester.ensureVisible(find.text('Batalkan unduhan'));
    await tester.tap(find.text('Batalkan unduhan'));
    await tester.pumpAndSettle();
    expect(setup.service.token!.isCancelled, isTrue);
    expect(find.text('Versi 0.2.0 tersedia'), findsOneWidget);
    // Unduhan lama yang baru berhenti tidak mengubah keadaan.
    setup.service.finish();
    await tester.pumpAndSettle();
    expect(find.text('Versi 0.2.0 tersedia'), findsOneWidget);
  });

  testWidgets('checksum tidak cocok: gagal mengunduh dengan alasan, Coba lagi mengunduh ulang', (tester) async {
    final setup = _Setup(release: _release());
    await setup.launch(tester);
    await setup.openSettings(tester);
    await tester.tap(find.text('Unduh dan pasang'));
    await tester.pump();
    setup.service.fail(UpdateFailure.checksum);
    await tester.pumpAndSettle();
    expect(find.text('Gagal mengunduh versi 0.2.0'), findsOneWidget);
    expect(find.text('Berkas yang diunduh tidak sama dengan checksum rilis, jadi tidak dipasang.'), findsOneWidget);
    await tester.ensureVisible(find.text('Coba lagi'));
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    expect(find.text('Mengunduh versi 0.2.0'), findsOneWidget);
  });

  testWidgets('penginstal gagal dibuka: status gagal, Coba lagi memasang berkas yang sama', (tester) async {
    final setup = _Setup(release: _release());
    setup.platform.installError = PlatformException(code: 'update_failed');
    await setup.launch(tester);
    await setup.openSettings(tester);
    await tester.tap(find.text('Unduh dan pasang'));
    await tester.pump();
    setup.service.finish();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pasang'));
    await tester.tap(find.text('Pasang'));
    await tester.pumpAndSettle();
    expect(find.text('Gagal membuka penginstal'), findsOneWidget);
    setup.platform.installError = null;
    await tester.ensureVisible(find.text('Coba lagi'));
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(setup.platform.installed, ['/cache/update/termul-update.apk']);
  });
}
