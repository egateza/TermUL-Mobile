import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:termul_mobile/shared/widgets/termul_text_field.dart';

/// Alur host dari layar sampai penyimpanan nyata: berkas di folder pribadi aplikasi dan Keystore Android.
/// "Restart" disimulasikan dengan membuka ulang `bootstrap()` pada folder yang sama.
/// Jalankan: `flutter test integration_test/host_flow_test.dart -d <perangkat>`.
Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is TermulTextField && w.label == label),
  matching: find.byType(TextField),
);

/// Menunggu [finder] muncul (penyimpanan nyata butuh waktu); bila habis, cetak teks di layar untuk diagnosis.
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().join(' | ');
  fail('tidak muncul dalam ${timeout.inSeconds} detik: $finder; layar: $texts');
}

Future<void> launch(WidgetTester tester, AppDependencies deps) async {
  await tester.pumpWidget(const SizedBox()); // buang pohon lama
  await tester.pumpWidget(ProviderScope(overrides: deps.overrides, child: const TermulApp()));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    final base = await getApplicationSupportDirectory();
    dir = await Directory('${base.path}${Platform.pathSeparator}alur_${DateTime.now().microsecondsSinceEpoch}')
        .create(recursive: true);
  });

  tearDown(() async => dir.delete(recursive: true));

  testWidgets('tambah host, bertahan setelah restart, lalu hapus', (tester) async {
    var deps = await bootstrap(directory: dir);
    await launch(tester, deps);
    expect(find.text('Belum ada host'), findsOneWidget);

    await tester.tap(find.text('Tambah host'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Nama'), 'server-uji');
    await tester.enterText(input('Host'), '192.0.2.50');
    await tester.enterText(input('User'), 'pengguna');
    await tester.enterText(input('Password'), 'nilai-uji-bukan-kredensial');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await waitFor(tester, find.widgetWithText(HostRow, 'server-uji'));
    await tester.pumpAndSettle();

    final id = deps.hosts.snapshot.profiles.single.id;
    expect(await deps.vault.has(id, SecretType.loginPassword), isTrue);
    expect(
      await File('${dir.path}${Platform.pathSeparator}profiles.json').readAsString(),
      isNot(contains('nilai-uji-bukan-kredensial')),
    );

    // Restart: penyimpanan dibuka ulang dari berkas dan Keystore.
    deps = await bootstrap(directory: dir);
    expect(deps.report.hosts.hadCorruptFile, isFalse);
    await launch(tester, deps);
    expect(find.widgetWithText(HostRow, 'server-uji'), findsOneWidget);
    expect(await deps.vault.has(id, SecretType.loginPassword), isTrue);

    // Hapus lewat layar.
    await tester.longPress(find.widgetWithText(HostRow, 'server-uji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Hapus')));
    await waitFor(tester, find.text('Belum ada host'));
    await tester.pumpAndSettle();
    expect(await deps.vault.has(id, SecretType.loginPassword), isFalse);
    expect(deps.vault, isNotNull);
  });

  testWidgets('berkas daftar host rusak saat mulai: dikarantina, banner tampil, aplikasi tetap jalan', (tester) async {
    await File('${dir.path}${Platform.pathSeparator}profiles.json').writeAsString('{rusak');
    final deps = await bootstrap(directory: dir);
    expect(deps.report.hosts.hadCorruptFile, isTrue);
    await launch(tester, deps);
    expect(find.text('Daftar host rusak'), findsOneWidget);
    final corrupt = dir.listSync().whereType<File>().where((f) => f.path.contains('profiles.json.corrupt-'));
    expect(corrupt, hasLength(1));
    expect(await corrupt.single.readAsString(), '{rusak');
  });
}
